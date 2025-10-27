# Migration Guide

## Migrating from 1.x to 2.0.0

### ⚠️ Breaking Changes

#### 1. RequestMatcher Signature Change

**Before (v1.x):**
```dart
(url, query) => url.contains('/users')
```

**After (v2.0.0):**
```dart
(request) => request.url.contains('/users')
```

#### 2. Conditional Caching API Change

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

#### 3. Per-Request Caching Methods

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

### 🔄 Quick Migration Steps

1. **Update condition functions** to use `RequestDetails` parameter
2. **Use factory constructors** for `ConditionalCacheRule`
3. **Replace `setCaching`** with specific methods

### 📋 Migration Examples

#### Interceptor Setup
**Before:**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'user_rule',
  (url, query) => url.contains('/users'),
  Duration(minutes: 30),
);
```

**After:**
```dart
DioCachePlusInterceptor.addConditionalCaching(
  'user_rule',
  ConditionalCacheRule.duration(
    condition: (request) => request.url.contains('/users'),
    duration: Duration(minutes: 30),
  ),
);
```

#### Per-Request Caching
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

### 🆕 New Factory Constructors
```dart
ConditionalCacheRule.duration(condition, duration)
ConditionalCacheRule.durationFn(condition, durationFn)
ConditionalCacheRule.expiry(condition, expiry)
ConditionalCacheRule.expiryFn(condition, expiryFn)
ConditionalCacheRule.conditionalOnly(condition)
```

### 🆕 New Options Methods
```dart
options.setCachingWithDuration(enableCache, duration)
options.setCachingWithDurationFn(enableCache, durationFn)
options.setCachingWithExpiry(enableCache, expiry)
options.setCachingWithExpiryFn(enableCache, expiryFn)
options.setCaching(enableCache) // Simple caching
```

Need help? Check the [README.md](README.md) or open an issue on GitHub.