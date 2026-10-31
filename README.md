# Dio Cache Plus

[![pub package](https://img.shields.io/pub/v/dio_cache_plus.svg)](https://pub.dev/packages/dio_cache_plus)
[![pub points](https://img.shields.io/pub/points/dio_cache_plus)](https://pub.dev/packages/dio_cache_plus/score)
[![likes](https://img.shields.io/pub/likes/dio_cache_plus)](https://pub.dev/packages/dio_cache_plus/score)
[![downloads](https://img.shields.io/pub/dm/dio_cache_plus)](https://pub.dev/packages/dio_cache_plus/score)
[![CI](https://github.com/BaluVadivel/dio_cache_plus/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/BaluVadivel/dio_cache_plus/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/github/license/BaluVadivel/dio_cache_plus)](https://github.com/BaluVadivel/dio_cache_plus/blob/main/LICENSE)

**Dio Cache Plus** is an advanced caching interceptor for Dio — offering per-request control, smart conditional caching, absolute expiry support, dynamic function-based durations, and efficient request deduplication.

---

## 🧱 Acknowledgments

Originally inspired by [flutter-network-sanitizer](https://github.com/aelkholy9/flutter-network-sanitizer) by [Ahmed Elkholy](https://github.com/aelkholy9).  
Completely reworked and expanded with a modern API, expiry-based caching, dynamic function support, version-safe Hive storage, and advanced request rules.

---

## ✨ Features

✅ **Conditional Caching** — cache only the requests you want.  
✅ **Per-Request Control** — customize caching for each call.  
✅ **Smart Expiry** — use either a relative `Duration` or an absolute `DateTime expiry`.  
✅ **Dynamic Functions** — use functions to calculate durations/expiry at runtime.  
✅ **Request Deduplication** — identical concurrent requests share the same network response.  
✅ **Persistent Cross-Platform Storage** — powered by Hive.  
✅ **Automatic Migration** — safe schema updates without crashes.  
✅ **Global or Local Cache Management** — total flexibility.  
✅ **Accurate Time-Based Expiry** — expiry calculations happen at storage time for precision.
✅ **Manual Cache Persistence** — explicitly save responses without enabling request caching.  
✅ **Direct Cache Access** — fetch cached responses without triggering a network call.

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dio_cache_plus: ^2.1.0
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

  dio.interceptors.add(
    DioCachePlusInterceptor(
      cacheAll: false,
      commonCacheDuration: const Duration(minutes: 5),
      isErrorResponse: (response) => response.statusCode != 200,

      // ✅ Conditional rules from constructor
      conditionalRules: [
        // Cache GET user API responses for 10 minutes
        ConditionalCacheRule.duration(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/users'),
          duration: const Duration(minutes: 10),
        ),

        // Cache GET market data until the market closes (e.g., 3:30 PM)
        ConditionalCacheRule.expiry(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/market'),
          expiry: DateTime.now().copyWith(hour: 15, minute: 30),
        ),

        // Dynamic caching based on time of day
        ConditionalCacheRule.durationFn(
          condition: (request) =>
              request.method == 'GET' && request.url.contains('/news'),
          durationFn: () {
            final hour = DateTime.now().hour;
            // Cache longer during off-peak hours
            return hour >= 22 || hour < 6 
                ? const Duration(hours: 4)
                : const Duration(minutes: 30);
          },
        ),
      ],
    ),
  );

  // Not cached
  await dio.get('/api/news');

  // Cached for 5 minutes (default duration)
  final cached = await dio.get(
    '/api/users',
    options: Options().setCaching(enableCache: true),
  );
}
```

## 🛠️ Usage Examples

### Per-Request Control

Use type-safe methods for different caching strategies:

```dart
// Cache GET requests with static duration
final response1 = await dio.get(
  '/api/big_data',
  options: Options().setCachingWithDuration(
    enableCache: true,
    duration: const Duration(hours: 2),
  ),
);

// Cache with dynamic duration function
final response2 = await dio.get(
  '/api/dynamic_data',
  options: Options().setCachingWithDurationFn(
    enableCache: true,
    durationFn: () {
      final hour = DateTime.now().hour;
      return hour >= 22 || hour < 6 
          ? const Duration(hours: 4)
          : const Duration(minutes: 30);
    },
  ),
);

// Cache with static expiry
final response3 = await dio.get(
  '/api/market_data',
  options: Options().setCachingWithExpiry(
    enableCache: true,
    expiry: DateTime.now().copyWith(hour: 16, minute: 0),
  ),
);

// Cache with dynamic expiry function
final response4 = await dio.get(
  '/api/reports',
  options: Options().setCachingWithExpiryFn(
    enableCache: true,
    expiryFn: () => DateTime.now().add(const Duration(days: 1)),
  ),
);

// Simple caching (uses global default duration)
final response5 = await dio.get(
  '/api/data',
  options: Options().setCaching(enableCache: true),
);

// Disable cache even if global cacheAll=true
final noCache = await dio.get(
  '/api/live_feed',
  options: Options().setCaching(enableCache: false),
);
```

### Dynamic Duration Functions

Calculate cache durations dynamically at runtime:

```dart
// Weekend-aware caching
final weekendResponse = await dio.get(
  '/api/weekly-report',
  options: Options().setCachingWithDurationFn(
    enableCache: true,
    durationFn: () {
      final isWeekend = DateTime.now().weekday >= 6; // Saturday or Sunday
      return isWeekend 
          ? const Duration(days: 3)  // Longer cache on weekends
          : const Duration(hours: 12); // Shorter cache on weekdays
    },
  ),
);

// User-based caching strategies
final userResponse = await dio.get(
  '/api/user/profile',
  options: Options().setCachingWithDurationFn(
    enableCache: true,
    durationFn: () {
      final userType = authService.currentUser?.type;
      switch (userType) {
        case UserType.premium:
          return const Duration(hours: 4);
        case UserType.standard:
          return const Duration(hours: 1);
        case UserType.guest:
        default:
          return const Duration(minutes: 15);
      }
    },
  ),
);
```

### Absolute Expiry with Dynamic Functions

Calculate expiry times dynamically based on business logic:

```dart
// Cache until next market close (dynamic calculation)
final marketResponse = await dio.get(
  '/api/market-data',
  options: Options().setCachingWithExpiryFn(
    enableCache: true,
    expiryFn: () {
      final now = DateTime.now();
      // If it's after 4 PM, cache until next day 4 PM
      if (now.hour >= 16) {
        return DateTime(now.year, now.month, now.day + 1, 16, 0);
      } else {
        return DateTime(now.year, now.month, now.day, 16, 0);
      }
    },
  ),
);

// Cache until top of next hour
final topOfHourResponse = await dio.get(
  '/api/hourly-data',
  options: Options().setCachingWithExpiryFn(
    enableCache: true,
    expiryFn: () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, now.hour + 1);
    },
  ),
);
```

### Force Refresh

Bypass the cache to get fresh data from the server:

```dart
// This request will ignore any cached data and hit the network
final freshResponse = await dio.get(
  '/api/users/123',
  options: Options().setCachingWithDuration(
    enableCache: true,
    duration: const Duration(minutes: 30),
    invalidateCache: true, // Forces network request
  ),
);
```

### Request Deduplication

Concurrent identical GET requests are automatically merged:

```dart
final futures = List.generate(
  10,
  (_) => dio.get('/api/trending'),
);

final responses = await Future.wait(futures);
// Only 1 actual network request was made 🎯
```

### Save Response Without Enabling Cache

Persist a response even when normal caching is disabled:

```dart
// Uses default expiry (7 days)
final response = await dio.get(
  'https://www.example.com/api/profile',
  options: Options().saveResponse(),
);

// Custom expiry duration
final responseWithDuration = await dio.get(
  'https://www.example.com/api/profile',
  options: Options().saveResponse(
    duration: const Duration(days: 30),
  ),
);

```

> Useful for one-time persistence, background syncs, or offline access.

### Read Cached Data Without Network Call

Fetch cached data directly using the same cache key logic:

```dart
final cachedResponse = await DioCachePlusInterceptor.getCacheData(
  url: 'https://www.example.com/api/profile',
);

if (cachedResponse != null) {
  print(cachedResponse.data);
}
```

* Does **not** trigger a network request
* Uses the **exact same cache key** as interceptor flow
* Can optionally respect expiry

> **Note:** `url` must be the **full URL**, including your Dio `baseUrl` (e.g. `https://www.example.com/api/profile`, not `/api/profile`). Pass the same `method`, `queryParameters` and `body` as the original request, otherwise the cache key won't match and `null` is returned.

```dart
await DioCachePlusInterceptor.getCacheData(
  url: 'https://www.example.com/api/profile',
  ignoreExpiry: false,
);
```

### Tell Cached Responses From Live Ones

Every response that passes through the interceptor gets a standard [`Cache-Status`](https://www.rfc-editor.org/rfc/rfc9211) header, and responses served from the cache also get an [`Age`](https://www.rfc-editor.org/rfc/rfc9111#name-age) header:

| Situation | `Cache-Status` |
|---|---|
| Served from cache (`ttl` = seconds of freshness left) | `dio_cache_plus; hit; ttl=240` |
| Served stale via `getCacheData(ignoreExpiry: true)` | `dio_cache_plus; hit; ttl=-120` |
| Not cached yet, fetched and stored | `dio_cache_plus; fwd=uri-miss; stored` |
| Cached entry had expired, fetched again | `dio_cache_plus; fwd=stale; stored` |
| Forced refresh (`invalidateCache: true`) | `dio_cache_plus; fwd=request; stored` |
| Caching not enabled for the request | `dio_cache_plus; fwd=bypass` |
| `saveResponse()` | `dio_cache_plus; fwd=bypass; stored` |

```dart
final response = await dio.get('/profile');
final cacheStatus = response.headers['cache-status']?.last ?? '';
final fromCache = cacheStatus.startsWith('dio_cache_plus; hit');
final secondsInCache = int.tryParse(response.headers.value('age') ?? '');
```

* `stored` appears only when the response was actually written to the cache.
* The original `Date` header is never changed. On a cached response, the server's time is `Date + Age`.
* If a server or CDN already sends `Cache-Status` or `Age`, they're kept: our entry is appended to `Cache-Status`, and our time in cache is added to `Age`.
* These headers are added when a response is returned and are never stored.

## 🔧 Runtime Rule Management

Add or remove conditional caching rules dynamically at runtime:

```dart
// Add rule with static duration
DioCachePlusInterceptor.addConditionalCaching(
  'user_cache',
  ConditionalCacheRule.duration(
    condition: (request) => 
        request.method == 'GET' && request.url.contains('/users'),
    duration: const Duration(minutes: 30),
  ),
);

// Add rule with dynamic duration function
DioCachePlusInterceptor.addConditionalCaching(
  'news_cache',
  ConditionalCacheRule.durationFn(
    condition: (request) => 
        request.method == 'GET' && request.url.contains('/news'),
    durationFn: () {
      final hour = DateTime.now().hour;
      return hour >= 22 || hour < 6 
          ? const Duration(hours: 4)   // Longer cache at night
          : const Duration(minutes: 30); // Shorter cache during day
    },
  ),
);

// Add rule with static expiry
DioCachePlusInterceptor.addConditionalCaching(
  'market_cache',
  ConditionalCacheRule.expiry(
    condition: (request) => 
        request.method == 'GET' && request.url.contains('/market'),
    expiry: DateTime.now().copyWith(hour: 16, minute: 0), // Until 4 PM today
  ),
);

// Add rule with dynamic expiry function  
DioCachePlusInterceptor.addConditionalCaching(
  'report_cache',
  ConditionalCacheRule.expiryFn(
    condition: (request) => 
        request.method == 'GET' && request.url.contains('/reports'),
    expiryFn: () => DateTime.now().add(const Duration(days: 1)), // Until same time tomorrow
  ),
);

// Add rule without specific timing (uses global default)
DioCachePlusInterceptor.addConditionalCaching(
  'api_cache',
  ConditionalCacheRule.conditionalOnly(
    condition: (request) => 
        request.method == 'GET' && request.url.contains('/api'),
  ),
);

// Remove a rule
DioCachePlusInterceptor.removeConditionalCaching('user_cache');

// Remove cached data based on condition
DioCachePlusInterceptor.removeConditionalCachingData(
  (request) => request.method == 'GET' && request.url.contains('/users'),
);

// Clear all cached data (but keep rules)
await DioCachePlusInterceptor.clearAll();
```

## ⚙️ How It Works

### Caching Flow

1. **Request Interception**: When a request is made, a unique key is generated based on method, URL, and parameters.
2. **Cache Check**: The interceptor checks if caching is enabled via global config, per-request options, or matching conditional rules.
3. **Expiry Validation**: If cached data exists, its timestamp is checked against the configured duration/expiry.
4. **Network Fallback**: If no valid cache exists, the request proceeds to the network.
5. **Storage**: Successful responses are stored with precise expiry calculation at storage time.
6. **Forced Persistence**: Requests marked with `saveResponse` are persisted with a configurable expiry even if caching is disabled.


### Smart Expiry Calculation

Unlike other caching solutions, Dio Cache Plus calculates expiry durations **at the moment of storage**, not when the request is configured. This ensures:

- **Market closing times** expire exactly at the specified time
- **Time-sensitive data** respects absolute deadlines
- **Dynamic functions** are executed at cache time for fresh values
- **No timing drift** between request configuration and actual caching

### Function Execution Precedence

When multiple duration/expiry options are provided, they are evaluated in this order:

1. `expiryFn` - Dynamic expiry function
2. `expiry` - Static expiry DateTime
3. `durationFn` - Dynamic duration function
4. `duration` - Static duration
5. Conditional rule functions
6. Global default duration

### Deduplication

- The interceptor tracks all outgoing network requests
- Identical concurrent requests are queued instead of creating new network calls
- All queued requests receive the same result when the original completes

### Cache Invalidation

- **Force Refresh**: `invalidateCache: true` removes existing cache before making the network request
- **Automatic Expiration**: Entries expire based on their configured duration or absolute expiry
- **Conditional Data Removal**: `removeConditionalCachingData()` removes cached data matching specific patterns
- **Global Clear**: `clearAll()` wipes the entire cache

## 📚 API Reference

### DioCachePlusInterceptor

The main interceptor class.

| Constructor Parameter | Type | Required | Description |
|----------------------|------|----------|-------------|
| `cacheAll` | `bool` | Yes | When `true`, caches all requests by default. When `false`, requires explicit opt-in via `setCaching()` |
| `commonCacheDuration` | `Duration` | Yes | Default cache duration when no specific duration is provided |
| `isErrorResponse` | `bool Function(Response)` | Yes | Predicate to determine if a response represents an error (prevents caching of errors) |
| `conditionalRules` | `List<ConditionalCacheRule>?` | No | List of conditional caching rules applied at interceptor creation |
| `cacheManager` | `SanitizerCacheManager?` | No | Custom cache storage implementation. Defaults to Hive-based storage |

> The interceptor is a singleton: only the first construction's parameters are used.

**Static Methods:**
- `addConditionalCaching(String key, ConditionalCacheRule rule)` - Adds a conditional caching rule
- `removeConditionalCaching(String key)` - Removes a conditional rule
- `removeConditionalCachingData(RequestMatcher condition)` - Removes cached data matching the condition
- `clearAll()` - Clears all cached data
- `getCacheData(...)` - Returns cached response directly without making a network request

> **Note:** Static methods wait until the interceptor has been created, then run. Create the interceptor early (e.g. at app startup); a call made before that simply waits, and only stays pending if the interceptor is never created.

### CacheOptionsExtension

Per-request cache control via `Options` extension methods:

| Method | Parameters | Description |
|--------|------------|-------------|
| `setCachingWithDuration` | `enableCache`, `duration`, `overrideConditionalCache`, `invalidateCache` | Caching with static duration |
| `setCachingWithDurationFn` | `enableCache`, `durationFn`, `overrideConditionalCache`, `invalidateCache` | Caching with dynamic duration function |
| `setCachingWithExpiry` | `enableCache`, `expiry`, `overrideConditionalCache`, `invalidateCache` | Caching with static expiry DateTime |
| `setCachingWithExpiryFn` | `enableCache`, `expiryFn`, `overrideConditionalCache`, `invalidateCache` | Caching with dynamic expiry function |
| `setCaching` | `enableCache`, `overrideConditionalCache`, `invalidateCache` | Simple caching (uses global default) |
| `saveResponse` | `duration` | Persists the response with a configurable expiry without enabling request-level caching |

### ConditionalCacheRule Factory Constructors

Define conditional caching rules with precise expiry control:

| Constructor | Parameters | Description |
|-------------|------------|-------------|
| `duration` | `condition`, `duration` | Rule with static duration |
| `durationFn` | `condition`, `durationFn` | Rule with dynamic duration function |
| `expiry` | `condition`, `expiry` | Rule with static expiry DateTime |
| `expiryFn` | `condition`, `expiryFn` | Rule with dynamic expiry function |
| `conditionalOnly` | `condition` | Rule without timing (uses global default) |

### RequestDetails Object

The `RequestDetails` object passed to condition functions contains:

| Property | Type | Description |
|----------|------|-------------|
| `method` | `String` | HTTP method (GET, POST, etc.) |
| `url` | `String` | Full request URL |
| `queryParameters` | `Map<String, dynamic>` | Request query parameters |

## 🎯 Advanced Usage

### Mixed Caching Strategies

```dart
// Combine static and dynamic caching rules
dio.interceptors.add(
  DioCachePlusInterceptor(
    cacheAll: false,
    commonCacheDuration: const Duration(minutes: 10),
    isErrorResponse: (r) => r.statusCode != 200,
    conditionalRules: [
      // GET User data with dynamic duration
      ConditionalCacheRule.durationFn(
        condition: (request) =>
          request.method == 'GET' && request.url.contains('/users'),
        durationFn: () {
          final isWeekend = DateTime.now().weekday >= 6;
          return isWeekend 
              ? const Duration(hours: 6)
              : const Duration(hours: 2);
        },
      ),
      // GET News articles cached until end of day
      ConditionalCacheRule.expiryFn(
        condition: (request) =>
          request.method == 'GET' && request.url.contains('/news'),
        expiryFn: () {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, 23, 59, 59);
        },
      ),
    ],
  ),
);
```

### Custom Cache Key Generation

Override the default cache key generation for specific requests:

```dart
final response = await dio.get(
  '/api/data',
  options: Options(extra: {
    'generatedRequestKey': 'custom_key_123', // Custom cache key
  }).setCachingWithDuration(
    enableCache: true,
    duration: const Duration(hours: 2),
  ),
);
```

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

- **Reduced Network Calls**: Caching and deduplication cut redundant requests by up to 90%
- **Faster Response Times**: Local cache serves data instantaneously
- **Lower Bandwidth Usage**: Optimized for slow networks and metered connections
- **Precise Expiry Control**: Time-sensitive data respects exact deadlines
- **Dynamic Optimization**: Cache behavior adapts to runtime conditions
- **Server Load Reduction**: Protect backend services from unnecessary traffic
- **Improved User Experience**: Apps feel faster and more responsive

## 🔧 Troubleshooting

### Cache Not Working?
- Ensure `enableCache: true` is set in `setCaching()` or `cacheAll: true` in interceptor
- Check that your `isErrorResponse` function correctly identifies successful responses
- Verify conditional rule conditions match your requests (remember to check method == 'GET')

### Expiry Not Respected?
- Use `expiry` or `expiryFn` instead of `duration` for absolute time boundaries
- Expiry is calculated at storage time, so it's always accurate
- Check that your DateTime includes timezone information if needed

### Function Errors?
- Wrap your durationFn/expiryFn in try-catch blocks if they might throw exceptions
- Functions are executed at cache time, not configuration time
- Ensure functions don't have side effects that could cause issues

### Memory Issues?
- The interceptor automatically cleans up completed requests
- Hive provides efficient disk-based storage
- Use `clearAll()` periodically if needed

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Dio Cache Plus** - Smart, dynamic, precise caching for Flutter apps. ⚡