// lib/src/core/cache_option_extension.dart

import 'package:dio/dio.dart';
import 'constants/sanitizer_constants.dart';

/// Extension on [Options] to easily apply caching options.
extension CacheOptionsExtension on Options {
  /// Configures caching with a static duration
  Options setCachingWithDuration({
    required bool enableCache,
    required Duration duration,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra ??= {};
    extra!.addAll({
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.cacheValidityDurationKey: duration,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    });
    return this;
  }

  /// Configures caching with a dynamic duration function
  Options setCachingWithDurationFn({
    required bool enableCache,
    required Duration Function() durationFn,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra ??= {};
    extra!.addAll({
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.durationFnKey: durationFn,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    });
    return this;
  }

  /// Configures caching with a static expiry DateTime
  Options setCachingWithExpiry({
    required bool enableCache,
    required DateTime expiry,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra ??= {};
    extra!.addAll({
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.expiryKey: expiry,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    });
    return this;
  }

  /// Configures caching with a dynamic expiry function
  Options setCachingWithExpiryFn({
    required bool enableCache,
    required DateTime Function() expiryFn,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra ??= {};
    extra!.addAll({
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.expiryFnKey: expiryFn,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    });
    return this;
  }

  /// Simple caching without specific timing (uses global default)
  Options setCaching({
    required bool enableCache,
    bool overrideConditionalCache = false,
    bool invalidateCache = false,
  }) {
    extra ??= {};
    extra!.addAll({
      SanitizerConstants.enableCache: enableCache,
      SanitizerConstants.invalidateCacheKey: invalidateCache,
      SanitizerConstants.overrideConditionalCache: overrideConditionalCache,
    });
    return this;
  }
}
