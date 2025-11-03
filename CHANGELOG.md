# Changelog

All notable changes to Dio Cache Plus will be documented in this file.

## [2.0.2] - 2025-Nov-03

### Added
- **Conditional cache data removal** - New `removeConditionalCachingData()` method to remove cached data based on request patterns

## [2.0.1] - 2025-Oct-28

### Optimizations
- **Skip caching** when validity duration is zero or null
- **Prevent duplicate cache overwriting** from cached responses
- **Preserve extra map reference** in request options

## [2.0.0] - 2025-Oct-27

### 🚀 Major Enhancements
- **Dynamic function support** for duration and expiry calculations
  - `durationFn` parameter for dynamic duration calculation at cache time
  - `expiryFn` parameter for dynamic expiry calculation at cache time
- **Factory constructors** for `ConditionalCacheRule` for better type safety
- **Enhanced CacheOptionsExtension** with type-safe methods
- **RequestDetails class** for better type safety in condition matching
- **Comprehensive test suite** with 100% test coverage for all major features

### ⚠️ Breaking Changes
- **`RequestMatcher` signature** now uses `RequestDetails` object instead of separate parameters
  - Old: `(String requestUrl, Map<String, dynamic> queryParameters) => ...`
  - New: `(RequestDetails request) => request.url.contains(...)`
- **Conditional caching API** now requires `ConditionalCacheRule` objects
  - Old: `addConditionalCaching(key, condition, duration)`
  - New: `addConditionalCaching(key, ConditionalCacheRule.duration(...))`
- **Per-request caching methods** are now type-specific
  - Old: `setCaching(enableCache: true, duration: ...)`
  - New: `setCachingWithDuration(enableCache: true, duration: ...)`

**For detailed migration instructions, see [Migration Guide](MIGRATION.md#migrating-from-1x-to-200)**

### 🔧 Improvements
- **Enhanced cache expiry calculation** to happen at storage time for precise timing
- **Improved caching logic precedence** with more intuitive rule evaluation
- **Better error handling** throughout the interceptor
- **Comprehensive test coverage** ensuring reliability and stability

## [1.0.2] - 2025-Aug-16

### Fixed
- **Cache invalidation** issues with force refresh
- **Request deduplication** edge cases
- **Hive storage** initialization race conditions

## [1.0.1] - 2025-Aug-15

### Fixed
- **Package publishing** issues
- **Documentation** formatting and examples

## [1.0.0] - 2025-Aug-15

### Added
- **Initial stable release** with all core features
- **Conditional caching** rules system
- **Request deduplication** for identical concurrent requests
- **Hive-based persistent storage**
- **Per-request cache control** via Options extension
- **Force refresh** capability

## [0.0.1] - 2025-Aug-14

### Added
- **Initial development release**
- **Basic caching interceptor** functionality
- **Foundation for conditional caching**

