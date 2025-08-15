# Dio Cache Plus

Dio Cache Plus is an enhanced caching interceptor for Dio with fine-grained per-request control, smart conditional caching, and customizable expiration. Speed up your apps and save bandwidth effortlessly.

## Acknowledgments

This package builds upon the foundation of [flutter-network-sanitizer](https://github.com/aelkholy9/flutter-network-sanitizer) by [Ahmed Elkholy](https://github.com/aelkholy9). Key improvements include:

- 🔐 **Fixed Hive key length limitation** - Resolved the 255-character constraint for cache keys
- � **Simplified API** - Streamlined individual request caching configuration
- 🏷️ **Enhanced conditional caching** - Added flexible request-based caching rules

## ✨ Features

✅ **Advanced Conditional Caching** - Define custom rules to cache specific requests based on URL patterns and query parameters.  
✅ **Type-Safe Per-Request Control** - Use modern extension methods to enable, disable, or configure caching for any individual call.  
✅ **Smart Request Deduplication** - Automatically prevents duplicate simultaneous requests, saving network bandwidth and server load.  
✅ **Flexible Global Configuration** - Choose to cache all requests by default or opt-in on a per-call basis.  
✅ **Force Refresh** - Easily invalidate the cache on demand to fetch fresh data.  
✅ **Persistent Cross-Platform Storage** - Uses Hive for reliable and fast storage across mobile, desktop, and web.  
✅ **Seamless Dio Integration** - Integrates perfectly and easily as a standard Dio interceptor.

## 📦 Installation

Add `dio_cache_plus` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  dio_cache_plus: ^1.0.0
```

Then, install it by running:

```bash
flutter pub get
```

## 🚀 Quick Start

Simply add `DioCachePlusInterceptor` to your Dio instance.

```dart
import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';

void main() async {
  final dio = Dio();

  // Add the interceptor with a 5-minute default cache duration.
  // The `false` flag means you must opt-in to cache each request.
  dio.interceptors.add(
    DioCachePlusInterceptor(
      const Duration(minutes: 5), // Default cache duration
      false, // `false`: cache only when explicitly enabled per request
             // `true`: cache all GET requests by default
    ),
  );

  // This request will NOT be cached because we haven't opted in.
  await dio.get('/api/news');

  // Use the setCaching extension to enable caching for this specific request.
  final response = await dio.get(
    '/api/users',
    options: Options().setCaching(enableCache: true),
  );

  // `response` is now cached for 5 minutes!
}
```

## 🛠️ Usage Examples

### Per-Request Control

Override the global settings for any request with clean, type-safe extension methods.

```dart
// Enable caching with a custom 2-hour duration for this request only
final longCacheResponse = await dio.get(
  '/api/big_data',
  options: Options().setCaching(
    enableCache: true,
    duration: const Duration(hours: 2),
  ),
);

// Disable caching for this request, even if global caching is enabled
final noCacheResponse = await dio.get(
  '/api/realtime_updates',
  options: Options().setCaching(enableCache: false),
);
```

### Conditional Caching

Define powerful rules to cache requests only when they meet specific criteria. This is perfect for caching user profiles but not search results.

```dart
// Add a rule to cache requests to '/users' for 15 minutes
DioCachePlusInterceptor.addConditionalCaching(
  'user_cache_rule', // A unique key for your rule
  (url, query) => url.contains('/users'),
  const Duration(minutes: 15),
);

// This request WILL be cached for 15 minutes because it matches the rule
await dio.get('/api/v1/users/123');

// This request will not be affected by the rule
await dio.get('/api/v1/products');

// To remove the rule later:
DioCachePlusInterceptor.removeConditionalCaching('user_cache_rule');
```

### Force Refresh

Bypass the cache to get fresh data from the server. The new response will then be stored in the cache.

```dart
// This request will ignore any cached data and hit the network
final freshResponse = await dio.get(
  '/api/users/123',
  options: Options().setCaching(
    enableCache: true,
    invalidateCache: true),
);
```

### Request Deduplication

Multiple identical requests fired at the same time are automatically handled. Only one network call is made.

```dart
// All these requests are fired at once
final futures = List.generate(
  10,
  (_) => dio.get('/api/trending_topics'),
);

// You get 10 responses, but only 1 network request was made!
final responses = await Future.wait(futures);
```

## ⚙️ How It Works

### Caching

- When a request is made, a unique key is generated based on its method, URL, and query parameters.
- The interceptor checks if caching is enabled via global config, per-request options, or a matching conditional rule.
- If a valid, non-expired response exists in the cache, it's returned instantly. Otherwise, the request proceeds to the network.
- Successful network responses are stored in the cache with a timestamp for expiration.

### Deduplication

- The interceptor keeps track of all outgoing network requests.
- If an identical request is made while the original is still in flight, it's added to a queue instead of creating a new network call.
- Once the original request completes (with a success or error), all queued requests are resolved with the same result.

### Cache Invalidation & Management

- **Force Refresh**: The `invalidateCache : true` option in setCaching removes the entry before making the network request.
- **Expiration**: Cache entries are considered invalid if their age exceeds the configured duration (`_cacheDuration`, per-request duration, or conditional rule duration).
- **Global Clear**: `DioCachePlusInterceptor.clearAll()` wipes the entire cache.

## 📚 API Reference

### DioCachePlusInterceptor

The main interceptor class.

| Constructor / Method                                                                              | Description                                                                                             |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `DioCachePlusInterceptor({required bool cacheAll, required Duration commonCacheDuration, required bool Function(Response) isErrorResponse})` | Creates the interceptor with named parameters. `cacheAll: true` caches all requests by default; `false` requires explicit opt-in via `setCaching()`. `commonCacheDuration` sets default cache duration. `isErrorResponse` predicate prevents caching of failed responses. |
| `static void addConditionalCaching(String key, RequestMatcher condition, [Duration? duration])`   | Adds a global rule to cache requests that match the `condition`.                                        |
| `static void removeConditionalCaching(String key)`                                                | Removes a conditional caching rule and its associated cached data.                                      |
| `static Future<void> clearAll()`                                                                  | Clears all data from the cache.                                                                         |

### Cache Control Options

Control caching behavior per request using `options.setCaching()`:

| Parameter                   | Type       | Default | Description |
|-----------------------------|------------|---------|-------------|
| `enableCache`               | `bool`     | Required | Enables/disables caching (overrides global settings) |
| `duration`                  | `Duration?` | `null`  | Custom cache duration for this request |
| `overrideConditionalCache`  | `bool`     | `false` | When true with `enableCache=false`, bypasses all conditional caching rules |
| `invalidateCache`           | `bool`     | `false` | Forces remove network cache and updates it with fresh response |

## 🌍 Platform Support

| Platform | Status |
| :------- | :----: |
| Android  |   ✅   |
| iOS      |   ✅   |
| Web      |   ✅   |
| Windows  |   ✅   |
| macOS    |   ✅   |
| Linux    |   ✅   |

## 🏆 Performance Benefits

-   **Reduced Network Calls**: Caching and deduplication drastically cut down redundant requests.
-   **Faster Response Times**: Serving data from a local cache is instantaneous.
-   **Lower Bandwidth Usage**: Less data transfer means lower costs and better performance on slow networks.
-   **Improved User Experience**: Apps feel faster and more responsive, with better offline support.
-   **Server Load Reduction**: Protect your backend services from unnecessary traffic.

## 🤝 Contributing

Contributions are welcome! If you have a feature request or found a bug, please feel free to submit an issue or a pull request.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/amazing-feature`).
3.  Commit your changes (`git commit -m 'Add some amazing feature'`).
4.  Push to the branch (`git push origin feature/amazing-feature`).
5.  Open a Pull Request.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.