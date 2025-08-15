import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_plus/src/core/request_key_generator_extension.dart';

import 'core/cache_manager/cache_manager.dart';
import 'core/cache_manager/hive_cache_manager.dart';
import 'core/constants/sanitizer_constants.dart';
import 'core/models/typedef.dart';

/// A Dio interceptor that provides HTTP response caching and request deduplication.
///
/// This interceptor caches HTTP responses automatically to improve network efficiency
/// and prevents duplicate simultaneous requests to the same endpoint.
///
/// It supports:
/// - Global or per-request cache duration configuration
/// - Enabling/disabling caching globally or per-request via [setCaching] extension
/// - Conditional caching rules based on URL/query parameters
/// - Cache invalidation and forced refreshes
/// - Custom cache storage implementation (defaults to Hive)
///
/// ## Cache Control Hierarchy (highest to lowest priority):
/// 1. `invalidateCache: true` → Always fetches fresh data
/// 2. `enableCache: false` → Disables caching (unless overridden)
/// 3. Request-specific conditional caching rules
/// 4. Global `cacheAll` setting
///
/// ## Conditional Caching
///
/// Add dynamic caching rules that evaluate URLs and query parameters:
/// ```dart
/// DioCachePlusInterceptor.addConditionalCaching(
///   'userCache',
///   (url, query) => url.contains('/users') && query['active'] == true,
///   duration: Duration(hours: 1),
/// );
/// ```
///
/// ## Usage Examples
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(
///   DioCachePlusInterceptor(
///     const Duration(minutes: 5), // Global default duration
///     false, // Cache only when explicitly enabled
///   ),
/// );
///
/// // Force fresh data with custom cache duration
/// dio.get('/data', options: Options().setCaching(
///   enableCache: true,
///   duration: Duration(hours: 2),
///   invalidateCache: true,
/// ));
///
/// // Unconditionally disable caching
/// dio.get('/data', options: Options().setCaching(
///   enableCache: false,
///   overrideConditionalCache: true,
/// ));
/// ```
class DioCachePlusInterceptor extends Interceptor {
  final Duration _cacheDuration;
  final bool _cacheAll;
  late final SanitizerCacheManager _cacheManager;

  final _incomingRequests = <String, List<Completer<Response>>>{};

  static DioCachePlusInterceptor? _instance;
  static final Completer<void> _instanceCompleter = Completer();

  /// Creates a DioCachePlusInterceptor with the specified cache duration.
  ///
  /// Uses the default [HiveCacheManager] for storage.
  ///
  /// [_cacheDuration] - How long responses should be cached before expiring
  DioCachePlusInterceptor._(
    this._cacheDuration,
    this._cacheAll, [
    SanitizerCacheManager? cacheManager,
  ]) {
    _cacheManager = cacheManager ?? HiveCacheManager();
  }

  /// Creates a singleton instance of [DioCachePlusInterceptor] with the specified
  /// global cache duration and caching behavior.
  ///
  /// This interceptor enables automatic response caching and request deduplication
  /// for Dio HTTP requests.
  ///
  /// - [commonCacheDuration]: The default duration for caching responses.
  /// - [cacheAll]: If `true`, all requests will be cached by default unless explicitly
  ///   disabled via [Options.extra]. If `false`, only requests explicitly marked
  ///   with `.setCaching(enableCache: true)` will be cached.
  ///
  /// You can override this default behavior per request using the `.setCaching()`
  /// extension method on `Options`, which allows enabling or disabling caching
  /// and setting a custom cache duration for individual requests.
  ///
  /// Example usage:
  /// ```dart
  /// final dio = Dio();
  /// dio.interceptors.add(
  ///   DioCachePlusInterceptor(
  ///     const Duration(minutes: 5), // default duration
  ///     false, // cache only when explicitly enabled
  ///   ),
  /// );
  ///
  /// // Enable caching for a specific request with custom duration
  /// final response = await dio.get(
  ///   '/api/data',
  ///   options: Options().setCaching(
  ///     enableCache: true,
  ///     duration: Duration(hours: 2),
  ///   ),
  /// );
  ///
  /// // Disable caching for a specific request (even if cacheAll is true)
  /// final noCacheResponse = await dio.get(
  ///   '/api/data',
  ///   options: Options().setCaching(enableCache: false),
  /// );
  /// ```

  factory DioCachePlusInterceptor(Duration commonCacheDuration, bool cacheAll) {
    _instance ??= DioCachePlusInterceptor._(commonCacheDuration, cacheAll);
    _instanceCompleter.complete();
    return _instance!;
  }

  /// Handles incoming requests by checking cache and deduplicating requests.
  ///
  /// This method:
  /// 1. Checks for force refresh requests
  /// 2. Deduplicates simultaneous identical requests
  /// 3. Returns cached responses if valid
  /// 4. Removes expired cache entries
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final key = options.generateRequestKey;
    _checkForceRefresh(options, key);
    final (isCaching, conditionalKey) = _cachingEnabled(options);
    if (isCaching) {
      // Check for duplicate requests first (deduplication)
      if (_incomingRequests.containsKey(key)) {
        final completer = Completer<Response>();
        _incomingRequests[key]!.add(completer);
        completer.future.then((response) {
          handler.resolve(response);
        }, onError: (e) => handler.reject(e as DioError));
        return;
      }

      // Check cache validity
      try {
        final cached = await _cacheManager.getData(key, options);
        if (cached != null &&
            !_isCacheExpired(cached, options, conditionalKey)) {
          handler.resolve(cached);
          return;
        } else {
          _incomingRequests[key] = [Completer<Response>()];
          await _cacheManager.remove(key);
        }
      } catch (_) {}
    }

    // Initialize the incoming requests list for this key
    handler.next(options);
  }

  /// Handles successful responses by caching them and resolving duplicate requests.
  ///
  /// This method:
  /// 1. Stores the response in cache
  /// 2. Resolves all waiting duplicate requests with the same response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final key = response.requestOptions.generateRequestKey;
    final (isCaching, _) = _cachingEnabled(response.requestOptions);
    if (isCaching) {
      try {
        await _cacheManager.setData(key, response);
      } catch (_) {}

      final completers = _incomingRequests.remove(key);
      completers?.forEach((completer) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      });
    }

    handler.next(response);
  }

  /// Handles request errors by notifying all waiting duplicate requests.
  ///
  /// This method ensures that all duplicate requests receive the same error
  /// when a network request fails.
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.generateRequestKey;

    final completers = _incomingRequests.remove(key);
    for (final completer in (completers ?? [])) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    }

    handler.next(err);
  }

  /// Checks if a cached response has expired based on the configured cache duration.
  ///
  /// [response] - The cached response to check
  /// Returns true if the cache has expired, false otherwise
  bool _isCacheExpired(
    Response response,
    RequestOptions requestOptions,
    String conditionalKey,
  ) {
    final timestampStr =
        response.extra[SanitizerConstants.cacheTimeStampKey] as String?;
    if (timestampStr == null) return true;

    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) return true;
    Duration? duration =
        conditionalKey.isEmpty ? null : _conditionalCaching[conditionalKey]?.$2;
    duration ??=
        response.extra[SanitizerConstants.cacheValidityDurationKey] is Duration
            ? response.extra[SanitizerConstants.cacheValidityDurationKey]
            : null;
    duration ??= _cacheDuration;

    return DateTime.now().difference(timestamp) > (duration);
  }

  /// Checks if a request should invalidate the cache and removes it if needed.
  ///
  /// [options] - The request options to check
  /// [key] - The cache key for the request
  void _checkForceRefresh(RequestOptions options, String key) {
    try {
      final invalidate =
          options.extra[SanitizerConstants.invalidateCacheKey] == true;
      if (invalidate) {
        _cacheManager.remove(key);
      }
    } catch (_) {}
  }

  (bool, String) _cachingEnabled(RequestOptions options) {
    final enableCache = options.extra[SanitizerConstants.enableCache];
    final overrideConditional =
        options.extra[SanitizerConstants.overrideConditionalCache] == true;
    final (conditional, key) = _isConditionalCaching(options);
    if (enableCache == false) {
      if (overrideConditional || !conditional) {
        return (false, "");
      }
    }
    final isCaching = _cacheAll || enableCache == true || conditional;
    return (isCaching, key);
  }

  (bool, String) _isConditionalCaching(RequestOptions options) {
    if (_conditionalCaching.isEmpty) return (false, "");
    final key = _conditionalCaching.entries.firstWhere(
      (a) => a.value.$1(
        options.uri.toString().split("?").first,
        options.queryParameters,
      ),
      orElse: () {
        return MapEntry("", ((_, __) => false, null));
      },
    );
    return (key.key.isNotEmpty, key.key);
  }

  final _conditionalCaching =
      <String, (RequestMatcher matcher, Duration? duration)>{};

  /// Adds a conditional caching rule associated with the given [key].
  ///
  /// The [condition] is a function that takes a request URL and its query parameters,
  /// and returns `true` if the request should be cached.
  ///
  /// This method allows you to enable caching for only specific requests based on
  /// custom matching logic.
  ///
  /// Example:
  /// ```dart
  /// DioCachePlusInterceptor.addConditionalCaching(
  ///   'userCache',
  ///   (url, query) => url.contains('/users') && query['active'] == true,
  /// );
  /// ```
  static void addConditionalCaching(
    String key,
    RequestMatcher condition, [
    Duration? duration,
  ]) async {
    try {
      await _instanceCompleter.future;
      _instance!._conditionalCaching[key] ??= (condition, duration);
    } catch (_) {}
  }

  /// Removes a conditional caching rule associated with the given [key].
  ///
  /// If a rule exists for the provided [key], it will be removed from the internal
  /// conditional caching map, and any cached data matching the associated condition
  /// will also be cleared from the cache.
  ///
  /// This method allows you to disable previously added conditional caching logic.
  ///
  /// Example:
  /// ```dart
  /// DioCachePlusInterceptor.removeConditionalCaching('userCache');
  /// ```
  static void removeConditionalCaching(String key) async {
    try {
      await _instanceCompleter.future;
      final condition = _instance!._conditionalCaching.remove(key);
      if (condition != null) {
        _instance!._cacheManager.removeConditional(condition.$1);
      }
    } catch (_) {}
  }

  /// Clears all cached data.
  ///
  /// This method should remove all stored cache entries.
  static Future<void> clearAll() async {
    try {
      await _instanceCompleter.future;
      await _instance!._cacheManager.clearAll();
    } catch (_) {}
  }
}
