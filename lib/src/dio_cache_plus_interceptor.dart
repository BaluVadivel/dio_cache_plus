// lib/src/dio_cache_plus_interceptor.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_plus/src/core/models/typedef.dart';
import 'package:dio_cache_plus/src/core/request_key_generator_extension.dart';

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
  static final Completer<void> _instanceCompleter = Completer();

  /// Creates a DioCachePlusInterceptor with the specified cache duration.
  ///
  /// Use [conditionalRules] to supply constructor-level caching rules.
  ///
  /// Note: keeping signature backward compatible. Pass `conditionalRules` to
  /// define rules permanently when creating interceptor.
  factory DioCachePlusInterceptor({
    required bool cacheAll,
    required Duration commonCacheDuration,
    required bool Function(Response response) isErrorResponse,
    List<ConditionalCacheRule>? conditionalRules,
  }) {
    _instance ??= DioCachePlusInterceptor._(
      cacheAll,
      commonCacheDuration,
      isErrorResponse,
    );

    // populate any constructor-provided conditional rules into the internal map
    if (conditionalRules != null) {
      for (var i = 0; i < conditionalRules.length; i++) {
        final rule = conditionalRules[i];
        _instance!._conditionalCaching['ctor_rule_$i'] ??= rule;
      }
    }

    _instanceCompleter.complete();
    return _instance!;
  }

  DioCachePlusInterceptor._(
    this._cacheAll,
    this._cacheDuration,
    this._isErrorResponse, [
    SanitizerCacheManager? cacheManager,
  ]) {
    _cacheManager = cacheManager ?? HiveCacheManager();
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
      // Use synchronized access to prevent race conditions
      final completer = Completer<Response>();
      final isFirstRequest = !_incomingRequests.containsKey(key);

      if (!isFirstRequest) {
        _incomingRequests[key]!.add(completer);
        completer.future.then(
          (response) => handler.resolve(response),
          onError: (e) => handler.reject(e),
        );
        return;
      } else {
        _incomingRequests[key] = [completer];
      }

      // Check cache validity for first request only
      try {
        final cached = await _cacheManager.getData(key, options);
        if (cached != null &&
            !_isCacheExpired(cached, options, conditionalKey)) {
          // Resolve all waiting completers
          final completers = _incomingRequests.remove(key);
          completers?.forEach((c) => c.complete(cached));
          handler.resolve(cached);
          return;
        } else {
          await _cacheManager.remove(key);
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

    // Cache only successful responses (based on isErrorResponse check)
    if (!_isErrorResponse(response) && isCaching) {
      try {
        // Ensure a Duration is present in requestOptions.extra for storage.
        _injectComputedDurationIfNeeded(response.requestOptions);
        await _cacheManager.setData(key, response);
      } catch (_) {}
    }

    // Always notify all waiting requests, whether successful or failed
    final completers = _incomingRequests.remove(key);
    completers?.forEach((completer) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    handler.next(response);
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

      // Check for per-request expiryFn and calculate duration just before storage
      final expiryFn =
          extra[SanitizerConstants.expiryFnKey] as DateTime Function()?;
      if (expiryFn != null) {
        try {
          final expiry = expiryFn();
          final remaining = expiry.difference(DateTime.now());
          final durationToStore =
              remaining.isNegative ? Duration.zero : remaining;
          options.extra = {
            ...options.extra,
            SanitizerConstants.cacheValidityDurationKey: durationToStore,
          };
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
        options.extra = {
          ...options.extra,
          SanitizerConstants.cacheValidityDurationKey: durationToStore,
        };
        return;
      }

      // Check for per-request durationFn and call it just before storage
      final durationFn =
          extra[SanitizerConstants.durationFnKey] as Duration Function()?;
      if (durationFn != null) {
        try {
          final duration = durationFn();
          options.extra = {
            ...options.extra,
            SanitizerConstants.cacheValidityDurationKey: duration,
          };
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
              options.queryParameters,
            ),
          )) {
            // Calculate duration JUST BEFORE storage based on the rule
            final duration = _calculateDurationFromRule(rule);
            if (duration != null) {
              options.extra = {
                ...options.extra,
                SanitizerConstants.cacheValidityDurationKey: duration,
              };
              return;
            }
            break;
          }
        } catch (_) {
          // ignore matcher errors and keep searching
        }
      }

      // fallback to interceptor default
      options.extra = {
        ...options.extra,
        SanitizerConstants.cacheValidityDurationKey: _cacheDuration,
      };
    } catch (_) {}
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
              options.queryParameters,
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

  /// Clears all cached data.
  static Future<void> clearAll() async {
    try {
      await _instanceCompleter.future;
      await _instance!._cacheManager.clearAll();
    } catch (_) {}
  }
}
