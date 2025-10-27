# Migration Guide

## Migrating from 1.x to 2.0.0

Version 2.0.0 introduces breaking changes to improve type safety and API consistency. This guide will help you migrate your code.

## ⚠️ Breaking Changes

### 1. RequestMatcher Signature Change

**Before (v1.x):**
```dart
RequestMatcher condition = (String requestUrl, Map<String, dynamic> queryParameters) {
  return requestUrl.contains('/users');
}
```

**After (v2.0.0):**
```dart
RequestMatcher condition = (RequestDetails request) {
  return request.method == 'GET' && request.url.contains('/users');
}
```

### 2. Conditional Caching API Change

**Before (v1.x):**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'user_cache',
  (url, query) => url.contains('/users'),
  Duration(minutes: 30),
);
```

**After (v2.0.0):**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'user_cache',
  ConditionalCacheRule.duration(
    condition: (request) => request.url.contains('/users'),
    duration: Duration(minutes: 30),
  ),
);
```

### 3. Per-Request Caching Methods

**Before (v1.x):**
```dart
options.setCaching(
  enableCache: true,
  duration: Duration(minutes: 30),
);
```

**After (v2.0.0):**
```dart
options.setCachingWithDuration(
  enableCache: true,
  duration: Duration(minutes: 30),
);
```

## 🔄 Quick Migration Steps

### Step 1: Update Condition Functions

**Before:**
```dart
(url, query) => url.contains('/users')
```

**After:**
```dart
(request) => request.url.contains('/users')
```

### Step 2: Use Factory Constructors for Conditional Rules

**Before:**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'rule_key',
  (url, query) => url.contains('/api'),
  Duration(minutes: 30),
);
```

**After:**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'rule_key',
  ConditionalCacheRule.duration(
    condition: (request) => request.url.contains('/api'),
    duration: Duration(minutes: 30),
  ),
);
```

### Step 3: Update Per-Request Caching

**Before:**
```dart
options.setCaching(
  enableCache: true,
  duration: Duration(hours: 2),
);
```

**After:**
```dart
options.setCachingWithDuration(
  enableCache: true,
  duration: Duration(hours: 2),
);
```

## 📋 Complete Migration Examples

### Interceptor Setup

**Before (v1.x):**
```dart
dio.interceptors.add(
  DioCachePlusInterceptor(
    cacheAll: false,
    commonCacheDuration: Duration(minutes: 5),
    isErrorResponse: (response) => response.statusCode != 200,
  ),
);

// Add conditional rule
DioCachePlusInterceptor.addConditionalCaching(
  'user_rule',
  (url, query) => url.contains('/users'),
  Duration(minutes: 30),
);
```

**After (v2.0.0):**
```dart
dio.interceptors.add(
  DioCachePlusInterceptor(
    cacheAll: false,
    commonCacheDuration: Duration(minutes: 5),
    isErrorResponse: (response) => response.statusCode != 200,
    conditionalRules: [
      ConditionalCacheRule.duration(
        condition: (request) => request.url.contains('/users'),
        duration: Duration(minutes: 30),
      ),
    ],
  ),
);

// Or add rule at runtime
DioCachePlusInterceptor.addConditionalCaching(
  'user_rule',
  ConditionalCacheRule.duration(
    condition: (request) => request.url.contains('/users'),
    duration: Duration(minutes: 30),
  ),
);
```

### Available Factory Constructors

```dart
// Static duration
ConditionalCacheRule.duration(condition, duration)

// Dynamic duration function
ConditionalCacheRule.durationFn(condition, durationFn)

// Static expiry
ConditionalCacheRule.expiry(condition, expiry)

// Dynamic expiry function
ConditionalCacheRule.expiryFn(condition, expiryFn)

// Condition only (uses global default)
ConditionalCacheRule.conditionalOnly(condition)
```

### Available Options Methods

```dart
// Static duration
options.setCachingWithDuration(enableCache, duration)

// Dynamic duration function
options.setCachingWithDurationFn(enableCache, durationFn)

// Static expiry
options.setCachingWithExpiry(enableCache, expiry)

// Dynamic expiry function
options.setCachingWithExpiryFn(enableCache, expiryFn)

// Simple caching (uses global default)
options.setCaching(enableCache)
```

## 🆕 New Features in 2.0.0

### Dynamic Functions

```dart
// Dynamic duration based on time of day
options.setCachingWithDurationFn(
  enableCache: true,
  durationFn: () {
    final hour = DateTime.now().hour;
    return hour >= 22 ? Duration(hours: 4) : Duration(minutes: 30);
  },
);

// Dynamic expiry until specific time
options.setCachingWithExpiryFn(
  enableCache: true,
  expiryFn: () => DateTime.now().add(Duration(hours: 2)),
);
```

### Enhanced Request Details

Access more request information in conditions:
```dart
condition: (request) {
  return request.method == 'GET' &&
         request.url.contains('/api') &&
         request.queryParameters['cache'] == 'true';
}
```

## Need Help?

If you encounter issues during migration:
1. Check the updated [README.md](README.md) for examples
2. Review the [example/](example/) directory
3. Open an issue on GitHub for support
```