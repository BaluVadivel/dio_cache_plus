// lib/src/core/constants/sanitizer_constants.dart

class SanitizerConstants {
  /// Duration stored for cached entry validity (Duration)
  static const String cacheValidityDurationKey = "cache_validity_duration";

  /// Function that returns Duration dynamically
  static const String durationFnKey = "duration_function_key";

  /// Absolute expiry time
  static const String expiryKey = 'dio_cache_plus_expiry_key';

  /// Function that returns expiry DateTime dynamically
  static const String expiryFnKey = 'expiry_function_key';

  /// Timestamp when the entry was cached (ISO string).
  static const String cacheTimeStampKey = "cache_timestamp";

  static const String invalidateCacheKey = "invalidateCache";
  static const String enableCache = "enableCache";
  static const String saveResponse = "saveResponse";
  static const String overrideConditionalCache = "overrideConditionalCache";
  static const String hiveBoxName = "sanitizer_hive_box";
}
