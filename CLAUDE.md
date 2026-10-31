# dio_cache_plus

Dio interceptor for response caching, request deduplication and conditional caching, published on pub.dev and used in production apps. Treat every change as production-critical.

## Commands
- `flutter test`: unit tests (interceptor tests use a mock `HttpClientAdapter` + in-memory cache manager; `hive_cache_manager_test.dart` runs real Hive in a temp dir)
- `flutter analyze`: must report no issues
- `dart format lib test`
- `dart pub publish --dry-run`: must report 0 warnings before a release
- `dart run build_runner build`: only if `HiveCachedResponse` fields change (regenerates `hive_cached_response.g.dart`)

## Invariants: don't break these
- **Cache key format** (`request_key_generator_extension.dart`): changing the key for any JSON-encodable request makes every existing user's cache miss after upgrade. Keys must stay identical unless a breaking release is intended.
- **Never throw from `onRequest`**: it's an `async void` interceptor, and Dio doesn't catch its errors, so an exception there hangs the request forever. Wrap risky work in try/catch and fall through to `handler.next`.
- **Requests with non-keyable bodies** (FormData, streams) get a unique key plus the `nonCacheableRequestKey` flag. They must never be cached, saved (`saveResponse`) or deduplicated. A user-supplied `generatedRequestKey` bypasses this on purpose.
- **Hive schema**: type IDs 0 (`HiveCachedResponse`) and 1 (`DurationAdapter`) are fixed. A breaking schema change means bumping `currentVersion` in `HiveCacheManager._initHive`, which deletes older boxes.
- **Singleton**: `DioCachePlusInterceptor` is a singleton; only the first construction's parameters apply. Static methods wait for the first construction. `resetInstance()` exists for tests only.
- **Deduplication**: the first request doesn't register a completer; only duplicates do. Every path (cache hit, response, error, cancel) must drain `_incomingRequests` for its key.
- **Dio compatibility**: the pubspec allows Dio `>=4.0.0 <6.0.0`; don't use Dio 5-only APIs in `lib/`.
- **Public API**: everything exported from `lib/dio_cache_plus.dart` is public. Don't remove or rename anything without a major version bump.

## Known limitations (intentional or deferred)
- Conditional rules see the full URL including the query string, but `removeConditionalCachingData` matches against the stored URL without it.
- A force-refresh request that arrives while an identical request is in flight joins that in-flight request.
- `getCacheData(url:)` needs the full URL including `baseUrl`.

## Git workflow
- `main` is protected: no direct pushes or force pushes. Every change goes through a branch and a pull request, and merges only once the `verify` CI check (`.github/workflows/ci.yml`) passes.
- Only the repository admin can create `v*` tags.

## Releases
- Use `/release`. Version bump in `pubspec.yaml`, CHANGELOG entry dated like `2025-Dec-16`, merged via a `release/vX.Y.Z` pull request.
- Pushing a `vX.Y.Z` tag on `main` runs `.github/workflows/publish.yml`, which publishes to pub.dev after manual approval in the `pub.dev` environment. Never run `dart pub publish` locally.
- Keep user-facing changes under `## [Unreleased]` in CHANGELOG.md until release.
