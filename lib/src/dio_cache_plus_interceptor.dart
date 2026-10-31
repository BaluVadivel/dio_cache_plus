// lib/src/dio_cache_plus_interceptor.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_plus/src/core/models/typedef.dart';
import 'package:dio_cache_plus/src/core/request_key_generator_extension.dart';
import 'package:flutter/foundation.dart';

import 'core/cache_manager/cache_manager.dart';
import 'core/cache_manager/hive_cache_manager.dart';
import 'core/constants/sanitizer_constants.dart';
import 'core/models/conditional_cache_rule.dart';

/// A Dio interceptor that provides HTTP response caching and request deduplication.
///
/// See README for usage.
class DioCachePlusInterceptor extends Interceptor {
  final Duration _cacheDuration;
  final bool _cacheAll;

  /// function to determine whether the response represents an error (if true, skip caching)
  final bool Function(Response response) _isErrorResponse;
  late final SanitizerCacheManager _cacheManager;

  final _incomingRequests = <String, List<Completer<Response>>>{};

  // Backing conditional rules:
  // key -> (RequestMatcher, ConditionalCacheRule)
  final Map<String, ConditionalCacheRule> _conditionalCaching = {};

  static DioCachePlusInterceptor? _instance;
  static Completer<void> _instanceCompleter = Completer();

  /// Creates a DioCachePlusInterceptor with the specified cache duration.
  ///
  /// Use [conditionalRules] to supply constructor-level caching rules.
  ///
  /// Use [cacheManager] to supply a custom storage implementation. Defaults to
  /// [HiveCacheManager]. Like the other settings, it only applies to the first
  /// construction, since the interceptor is a singleton.
  ///
  /// Note: keeping signature backward compatible. Pass `conditionalRules` to
  /// define rules permanently when creating interceptor.
  factory DioCachePlusInterceptor({
    required bool cacheAll,
    required Duration commonCacheDuration,
    required bool Function(Response response) isErrorResponse,
    List<ConditionalCacheRule>? conditionalRules,
    SanitizerCacheManager? cacheManager,
  }) {
    _instance ??= DioCachePlusInterceptor._(
      cacheAll,
      commonCacheDuration,
      isErrorResponse,
      cacheManager,
    );

    // populate any constructor-provided conditional rules into the internal map
    if (conditionalRules != null) {
      for (var i = 0; i < conditionalRules.length; i++) {
        final rule = conditionalRules[i];
        _instance!._conditionalCaching['ctor_rule_$i'] ??= rule;
      }
    }

    if (!_instanceCompleter.isCompleted) {
      _instanceCompleter.complete();
    }
    return _instance!;
  }

  /// Discards the singleton instance so the next factory call creates a fresh one.
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
    _instanceCompleter = Completer();
  }

  DioCachePlusInterceptor._(
    this._cacheAll,
    this._cacheDuration,
    this._isErrorResponse, [
    SanitizerCacheManager? cacheManager,
  ]) {
    _cacheManager = cacheManager ?? HiveCacheManager();
  }

  /// Returns cached response if available.
  /// Does NOT trigger network call.
  ///
  /// [url] must be the full URL, including the Dio `baseUrl`. [method],
  /// [queryParameters] and [body] must match the original request, or the
  /// cache key won't match and `null` is returned.
  ///
  /// [ignoreExpiry] = true → return even expired cache
  /// [ignoreExpiry] = false → respect expiry & auto-remove
  ///
  /// Like the other static methods, waits until the interceptor is created.
  static Future<Response?> getCacheData({
    required String url,
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    dynamic body,
    bool ignoreExpiry = true,
  }) async {
    try {
      // Ensure interceptor instance is initialized
      await _instanceCompleter.future;

      final options = RequestOptions(
        path: url,
        method: method,
        queryParameters: queryParameters ?? const {},
        data: body,
      );

      // Generates EXACT same key as onRequest
      final key = options.generateRequestKey;

      final cached = await _instance!._cacheManager.getData(key, options);
      if (cached == null) return null;

      if (!ignoreExpiry && _instance!._isCacheExpired(cached, options, key)) {
        await _instance!._cacheManager.remove(key);
        return null;
      }

      return _instance!._markCacheHit(cached);
    } catch (_) {
      return null;
    }
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
    if (options.extra[SanitizerConstants.invalidateCacheKey] == true) {
      // Await removal so the cache lookup below can't return the stale entry.
      await _checkForceRefresh(key);
    }
    final (isCaching, conditionalKey) = _cachingEnabled(options);
    // Why this request may go to the network, reported in Cache-Status.
    options.extra[SanitizerConstants.cacheStatusFwdKey] =
        !isCaching
            ? 'bypass'
            : options.extra[SanitizerConstants.invalidateCacheKey] == true
            ? 'request'
            : 'uri-miss';

    if (isCaching) {
      // Use synchronized access to prevent race conditions
      final isFirstRequest = !_incomingRequests.containsKey(key);

      if (!isFirstRequest) {
        final completer = Completer<Response>();
        _incomingRequests[key]!.add(completer);
        completer.future.then(
          (response) => handler.resolve(response),
          onError: (e) => handler.reject(e),
        );
        return;
      } else {
        // The first request is answered by its own handler; registering a
        // completer for it would leave an unhandled error on failure.
        _incomingRequests[key] = [];
      }

      // Check cache validity for first request only
      try {
        final cached = await _cacheManager.getData(key, options);
        if (kDebugMode) {
          debugPrint("DioCachePlus : ==> KEY: $key");
        }
        if (cached != null &&
            !_isCacheExpired(cached, options, conditionalKey)) {
          // Mark this response as served from cache to prevent redundant storage
          options.extra['_servedFromCache'] = true;
          final hit = _markCacheHit(cached);

          // Resolve all waiting completers
          final completers = _incomingRequests.remove(key);
          completers?.forEach((c) => c.complete(hit));
          handler.resolve(hit);
          _logCache("HIT", "Served From Cache", key);
          return;
        } else {
          if (cached != null &&
              options.extra[SanitizerConstants.cacheStatusFwdKey] ==
                  'uri-miss') {
            options.extra[SanitizerConstants.cacheStatusFwdKey] = 'stale';
          }
          await _cacheManager.remove(key);
          _logCache("MISS", "No Cached data available", key);
        }
      } catch (_) {
        // On cache error, continue with network request
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final key = response.requestOptions.generateRequestKey;
    final (isCaching, _) = _cachingEnabled(response.requestOptions);

    // Skip cache storage if this response was served from cache
    if (response.requestOptions.extra['_servedFromCache'] == true) {
      // Clean up the flag
      response.requestOptions.extra.remove('_servedFromCache');

      // Always notify all waiting requests, whether successful or failed
      final completers = _incomingRequests.remove(key);
      completers?.forEach((completer) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      });

      handler.next(response);
      return;
    }
    final extra = response.requestOptions.extra;
    // Requests whose body can't be keyed are never stored (see _cachingEnabled).
    final saveResponse =
        extra[SanitizerConstants.saveResponse] == true &&
        extra[SanitizerConstants.nonCacheableRequestKey] != true;
    var stored = false;
    bool isError;
    try {
      isError = _isErrorResponse(response);
    } catch (_) {
      // A throwing callback must not hang the request; don't cache.
      isError = true;
    }
    // Cache only successful responses (based on isErrorResponse check)
    if (!isError && (isCaching || saveResponse)) {
      try {
        // Ensure a Duration is present in requestOptions.extra for storage.
        _injectComputedDurationIfNeeded(response.requestOptions);
        // Skip caching if duration is zero or null (immediate expiry)
        final duration =
            response.requestOptions.extra[SanitizerConstants
                .cacheValidityDurationKey];
        if (duration is Duration && duration != Duration.zero) {
          await _cacheManager.setData(key, response);
          stored = true;
          _logCache("SAVE", "Saved to Cache", key);
        } else {
          _logCache("SKIP", "Skipped saving the Cache for now", key);
        }
      } catch (_) {}
    }

    // Marked after storage so the added headers are never persisted.
    _markNetworkResponse(response, stored: stored);

    // Always notify all waiting requests, whether successful or failed
    final completers = _incomingRequests.remove(key);
    completers?.forEach((completer) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    handler.next(response);
  }

  /// Marks a response served from the cache, per RFC 9111 / RFC 9211:
  /// `Age` (server age + time in this cache) and `Cache-Status: ...; hit; ttl=N`
  /// (seconds of freshness left, negative when stale). Returns a new
  /// [Response], so the stored one is never modified even if a cache manager
  /// hands out its stored object.
  Response _markCacheHit(Response cached) {
    try {
      final cachedAt = DateTime.tryParse(
        cached.extra[SanitizerConstants.cacheTimeStampKey] as String? ?? '',
      );
      var age =
          cachedAt == null
              ? Duration.zero
              : DateTime.now().difference(cachedAt);
      // The device clock may have moved backwards since storing.
      if (age.isNegative) age = Duration.zero;
      final validity =
          cached.extra[SanitizerConstants.cacheValidityDurationKey] is Duration
              ? cached.extra[SanitizerConstants.cacheValidityDurationKey]
                  as Duration
              : _cacheDuration;
      final ttl =
          ((validity - age).inMicroseconds / Duration.microsecondsPerSecond)
              .floor();

      final headers = _copyHeaders(cached.headers);
      headers.set('age', '${_parseAge(headers['age']) + age.inSeconds}');
      _addCacheStatus(headers, 'hit; ttl=$ttl');
      return Response(
        requestOptions: cached.requestOptions,
        data: cached.data,
        statusCode: cached.statusCode,
        statusMessage: cached.statusMessage,
        isRedirect: cached.isRedirect,
        redirects: cached.redirects,
        extra: Map.of(cached.extra),
        headers: headers,
      );
    } catch (_) {
      return cached;
    }
  }

  /// Marks a response that came from the network with
  /// `Cache-Status: ...; fwd=<reason>[; stored]` (RFC 9211).
  void _markNetworkResponse(Response response, {required bool stored}) {
    try {
      final fwd =
          response.requestOptions.extra[SanitizerConstants.cacheStatusFwdKey]
              as String? ??
          'bypass';
      final headers = _copyHeaders(response.headers);
      _addCacheStatus(headers, 'fwd=$fwd${stored ? '; stored' : ''}');
      response.headers = headers;
    } catch (_) {}
  }

  static Headers _copyHeaders(Headers headers) => Headers.fromMap({
    for (final entry in headers.map.entries)
      entry.key: List<String>.of(entry.value),
  });

  /// Appends this cache's member to `Cache-Status`, keeping entries from
  /// upstream caches (e.g. a CDN) and dropping any earlier entry of ours.
  static void _addCacheStatus(Headers headers, String params) {
    const name = SanitizerConstants.cacheStatusName;
    final values = headers['cache-status'];
    values?.removeWhere((v) {
      final member = v.trim();
      return member == name || member.startsWith('$name;');
    });
    if (values != null && values.isEmpty) headers.removeAll('cache-status');
    headers.add('cache-status', '$name; $params');
  }

  /// Seconds from an upstream `Age` header; 0 if missing or invalid.
  static int _parseAge(List<String>? values) {
    if (values == null || values.isEmpty) return 0;
    final age = int.tryParse(values.first.trim());
    return age == null || age < 0 ? 0 : age;
  }

  /// Handles request errors by notifying all waiting duplicate requests.
  ///
  /// This method ensures that all duplicate requests receive the same error
  /// when a network request fails.
  @override
  void onError(err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.generateRequestKey;

    final completers = _incomingRequests.remove(key);
    completers?.forEach((completer) {
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    });

    handler.next(err);
  }

  String _pad(String msg, {int width = 35}) {
    if (msg.length >= width) return msg;
    return msg + ' ' * (width - msg.length);
  }

  void _logCache(String tag, String message, String key) {
    if (kDebugMode) {
      debugPrint("DioCachePlus : [$tag] ${_pad(message)} || KEY: $key");
    }
  }

  /// Ensure a Duration is present in [options.extra] for caching.
  ///
  /// Precedence:
  /// 1) If already present in options.extra[cacheValidityDurationKey] -> keep it.
  /// 2) Else if expiryFn is present, call it and calculate remaining duration just before storage.
  /// 3) Else if expiry is present, calculate remaining duration just before storage.
  /// 4) Else if durationFn is present, call it just before storage.
  /// 5) Else find first matching constructor-level rule and calculate duration just before storage.
  /// 6) Else fallback to interceptor level _cacheDuration.
  void _injectComputedDurationIfNeeded(RequestOptions options) {
    try {
      final extra = options.extra;

      // Check if duration is already set
      if (extra[SanitizerConstants.cacheValidityDurationKey] is Duration) {
        return;
      }

      if (extra[SanitizerConstants.saveResponse] == true) {
        options.extra[SanitizerConstants
            .cacheValidityDurationKey] ??= const Duration(days: 7);
        return;
      }

      // Check for per-request expiryFn and calculate duration just before storage
      final expiryFn =
          extra[SanitizerConstants.expiryFnKey] as DateTime Function()?;
      if (expiryFn != null) {
        try {
          final expiry = expiryFn();
          final remaining = expiry.difference(DateTime.now());
          final durationToStore =
              remaining.isNegative ? Duration.zero : remaining;
          options.extra[SanitizerConstants.cacheValidityDurationKey] =
              durationToStore;
          return;
        } catch (_) {
          // If function fails, fall through to next option
        }
      }

      // Check for per-request expiry and calculate duration just before storage
      final expiry = extra[SanitizerConstants.expiryKey] as DateTime?;
      if (expiry != null) {
        final remaining = expiry.difference(DateTime.now());
        final durationToStore =
            remaining.isNegative ? Duration.zero : remaining;
        options.extra[SanitizerConstants.cacheValidityDurationKey] =
            durationToStore;
        return;
      }

      // Check for per-request durationFn and call it just before storage
      final durationFn =
          extra[SanitizerConstants.durationFnKey] as Duration Function()?;
      if (durationFn != null) {
        try {
          final duration = durationFn();
          options.extra[SanitizerConstants.cacheValidityDurationKey] = duration;
          return;
        } catch (_) {
          // If function fails, fall through to next option
        }
      }

      // check constructor-level conditional rules (first match)
      for (final entry in _conditionalCaching.entries) {
        final rule = entry.value;
        try {
          if (rule.condition(
            RequestDetails(
              options.method,
              options.uri.toString(),
              _extractQueryParameters(options),
            ),
          )) {
            // Calculate duration JUST BEFORE storage based on the rule
            final duration = _calculateDurationFromRule(rule);
            if (duration != null) {
              options.extra[SanitizerConstants.cacheValidityDurationKey] =
                  duration;
              return;
            }
            break;
          }
        } catch (_) {
          // ignore matcher errors and keep searching
        }
      }

      // fallback to interceptor default
      options.extra[SanitizerConstants.cacheValidityDurationKey] =
          _cacheDuration;
    } catch (_) {}
  }

  Map<String, dynamic> _extractQueryParameters(RequestOptions options) {
    final uri = options.uri.toString();
    if (uri.contains("?")) {
      final parsedUri = Uri.parse(uri);

      return {...parsedUri.queryParameters, ...options.queryParameters};
    }
    return options.queryParameters;
  }

  /// Calculate duration from rule just before storage to ensure accurate expiry times
  Duration? _calculateDurationFromRule(ConditionalCacheRule rule) {
    // Precedence: expiryFn > expiry > durationFn > duration

    if (rule.expiryFn != null) {
      try {
        final expiry = rule.expiryFn!();
        final remaining = expiry.difference(DateTime.now());
        return remaining.isNegative ? Duration.zero : remaining;
      } catch (_) {
        // If function fails, fall through to next option
      }
    }

    if (rule.expiry != null) {
      final remaining = rule.expiry!.difference(DateTime.now());
      return remaining.isNegative ? Duration.zero : remaining;
    }

    if (rule.durationFn != null) {
      try {
        return rule.durationFn!();
      } catch (_) {
        // If function fails, fall through to next option
      }
    }

    return rule.duration;
  }

  (bool, String) _cachingEnabled(RequestOptions options) {
    // Generating the key flags requests whose body can't be keyed.
    options.generateRequestKey;
    if (options.extra[SanitizerConstants.nonCacheableRequestKey] == true) {
      return (false, "");
    }

    final enableCache = options.extra[SanitizerConstants.enableCache];
    final overrideConditional =
        options.extra[SanitizerConstants.overrideConditionalCache] == true;

    // Explicit enable/disable takes highest precedence
    if (enableCache == true) {
      return (true, options.generateRequestKey);
    }
    if (enableCache == false) {
      if (overrideConditional) {
        return (false, "");
      }
      // If not overriding conditional, still check conditional rules
      final (conditional, key) = _isConditionalCaching(options);
      return (conditional && !overrideConditional, key);
    }

    // No explicit enableCache setting
    if (_cacheAll) {
      return (true, options.generateRequestKey);
    }

    // Check conditional rules
    return _isConditionalCaching(options);
  }

  (bool, String) _isConditionalCaching(RequestOptions options) {
    if (_conditionalCaching.isEmpty) return (false, "");
    try {
      for (final kv in _conditionalCaching.entries) {
        try {
          final rule = kv.value;
          if (rule.condition(
            RequestDetails(
              options.method,
              options.uri.toString(),
              _extractQueryParameters(options),
            ),
          )) {
            return (true, options.generateRequestKey);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return (false, "");
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
        response.extra[SanitizerConstants.cacheValidityDurationKey] is Duration
            ? response.extra[SanitizerConstants.cacheValidityDurationKey]
                as Duration
            : _cacheDuration;

    return DateTime.now().difference(timestamp) > duration;
  }

  /// Removes the cached entry for a force-refresh request.
  ///
  /// [key] - The cache key for the request
  Future<void> _checkForceRefresh(String key) async {
    try {
      await _cacheManager.remove(key);
    } catch (_) {}
  }

  /// Adds a conditional caching rule associated with the given [key].
  ///
  /// The [condition] is a function that takes a request URL and its query parameters,
  /// and returns `true` if the request should be cached.
  static void addConditionalCaching(
    String key,
    ConditionalCacheRule rule,
  ) async {
    try {
      await _instanceCompleter.future;
      _instance!._conditionalCaching[key] ??= rule;
    } catch (_) {}
  }

  /// Removes a conditional caching rule associated with the given [key].
  static void removeConditionalCaching(String key) async {
    try {
      await _instanceCompleter.future;
      _instance!._conditionalCaching.remove(key);
    } catch (_) {}
  }

  /// Removes a conditional caching Data which all matched with the given [condition].
  static Future<void> removeConditionalCachingData(
    RequestMatcher condition,
  ) async {
    try {
      await _instanceCompleter.future;
      await _instance!._cacheManager.removeConditional(condition);
    } catch (_) {}
  }

  /// Clears all cached data.
  static Future<void> clearAll() async {
    try {
      await _instanceCompleter.future;
      await _instance!._cacheManager.clearAll();
    } catch (_) {}
  }
}
