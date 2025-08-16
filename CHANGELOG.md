## 1.0.1
* Updated the documentations to match 1.0.0 release changes

## 1.0.0

### Breaking Changes
* Changed constructor parameters from positional to named arguments in `DioCachePlusInterceptor`:
  * Added required `isErrorResponse` function parameter to verify and skip caching of failed responses
  * Changed `cacheAll` to named parameter
  * Changed `commonCacheDuration` to named parameter
* Changed `enableCache` from positional to named optional argument in the `setCaching` method
* Updated Dio dependency support to `^5.8.0` while maintaining 4.x compatibility

### Major Features
* **`isErrorResponse` Predicate** - Core functionality that enables intelligent caching by:
  * Preventing storage of failed API responses
  * Allowing custom failure detection logic (e.g., status codes, error payloads)
  * Essential for maintaining cache integrity
* Improved API with named parameters for better readability and explicit configuration

### Why These Changes?
* The `isErrorResponse` parameter is now mandatory as it's critical for:
  * Preventing cache pollution with error states
  * Ensuring only valid responses are stored
  * Supporting custom API failure detection
* Named parameters provide:
  * Self-documenting API usage
  * Safer refactoring
  * Better IDE support

## 0.0.1

* Initial release of Dio Cache Plus.
