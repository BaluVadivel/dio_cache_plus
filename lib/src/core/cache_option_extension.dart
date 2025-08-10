import 'package:dio/dio.dart';
import 'constants/sanitizer_constants.dart';

extension CacheOptionsExtension on Options {
  /// Configures caching behavior for individual Dio requests with fine-grained control.
  ///
  /// This extension provides per-request cache management that overrides both global
  /// and conditional caching settings when specified.
  ///
  /// Parameters:
  /// - [enableCache] : Explicitly enables/disables caching for this request.
  ///   Takes precedence over both global `cacheAll` setting and conditional caching rules.
  /// - [duration]    : Custom cache duration for this request (overrides global default).
  /// - [overrideConditionalCache] : When true with [enableCache]=false, unconditionally
  ///   disables caching even if conditional rules would enable it.
  /// - [invalidateCache] : When true, forces a fresh network request and updates
  ///   the cache with new response (default: false).
  ///
  /// Priority Hierarchy (highest to lowest):
  /// 1. [invalidateCache] = true → Always fetches fresh data
  /// 2. [enableCache] = false → Disables caching (unless overridden)
  /// 3. Request-specific conditional caching rules
  /// 4. Global `cacheAll` setting
  ///
  /// Example:
  /// ```dart
  /// // Force fresh data and cache for 2 hours
  /// Options()
  ///   .setCaching(true,
  ///     duration: Duration(hours: 2),
  ///     invalidateCacheKey: true
  ///   );
  ///
  /// // Disable caching unconditionally
  /// Options().setCaching(false, overrideConditionalCache: true);
  /// ```
  Options setCaching(
    bool enableCache, {
    Duration? duration,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra = {
      ...?extra,
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.cacheValidityDurationKey: duration,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    };
    return this;
  }
}
