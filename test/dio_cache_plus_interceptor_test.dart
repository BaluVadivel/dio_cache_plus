import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock adapter that simulates network responses, so every interceptor
// (including the cache interceptor) runs exactly as it would in production.
class MockNetworkAdapter implements HttpClientAdapter {
  final Map<String, dynamic> mockResponses;
  int callCount = 0;
  int statusCode = 200;

  /// Extra headers the "server" sends, e.g. from a CDN.
  Map<String, List<String>> upstreamHeaders = {};

  MockNetworkAdapter(this.mockResponses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final responseData = mockResponses[options.path] ?? {'error': 'Not found'};

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 10));
    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...upstreamHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// In-memory storage; Hive needs platform plugins that unit tests don't have.
class InMemoryCacheManager implements SanitizerCacheManager {
  final _store = <String, Response>{};

  int get length => _store.length;
  bool failWrites = false;

  /// Hand out the stored object itself instead of a copy.
  bool returnStoredObject = false;

  /// The single stored entry (as stored, not a copy).
  Response get onlyEntry => _store.values.single;

  /// Rewrites every entry's stored time.
  void setStoredAt(DateTime time) {
    for (final r in _store.values) {
      r.extra['cache_timestamp'] = time.toIso8601String();
    }
  }

  @override
  Future<void> setData(String key, Response response) async {
    if (failWrites) throw StateError('disk full');
    final duration = response.requestOptions.extra['cache_validity_duration'];
    _store[key] = Response(
      requestOptions: response.requestOptions,
      data: response.data,
      statusCode: response.statusCode,
      headers: response.headers,
      extra: {
        'cache_timestamp': DateTime.now().toIso8601String(),
        if (duration is Duration) 'cache_validity_duration': duration,
      },
    );
  }

  @override
  Future<Response?> getData(String key, RequestOptions options) async {
    final cached = _store[key];
    if (cached == null) return null;
    if (returnStoredObject) return cached;
    return Response(
      requestOptions: options,
      data: cached.data,
      statusCode: cached.statusCode,
      headers: cached.headers,
      extra: cached.extra,
    );
  }

  @override
  Future<void> clearAll() async => _store.clear();

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> removeConditional(RequestMatcher condition) async {
    _store.removeWhere((_, r) {
      final o = r.requestOptions;
      return condition(
        RequestDetails(o.method, o.uri.toString(), o.queryParameters),
      );
    });
  }
}

void main() {
  late Dio dio;
  late DioCachePlusInterceptor cacheInterceptor;
  late MockNetworkAdapter mockAdapter;
  late InMemoryCacheManager cacheManager;

  setUp(() {
    DioCachePlusInterceptor.resetInstance();
    dio = Dio();
    mockAdapter = MockNetworkAdapter({
      '/test': {'data': 'test'},
      '/users': {
        'users': ['user1', 'user2'],
      },
      '/products': {
        'products': ['product1', 'product2'],
      },
      '/news': {
        'news': ['news1', 'news2'],
      },
    });

    cacheInterceptor = DioCachePlusInterceptor(
      cacheAll: false,
      commonCacheDuration: const Duration(minutes: 5),
      isErrorResponse: (response) => response.statusCode != 200,
      cacheManager: cacheManager = InMemoryCacheManager(),
    );

    dio.httpClientAdapter = mockAdapter;
    dio.interceptors.add(cacheInterceptor);
  });

  tearDown(() async {
    await DioCachePlusInterceptor.clearAll();
  });

  group('Basic Caching', () {
    test('should cache GET request when enabled', () async {
      // Reset call count
      mockAdapter.callCount = 0;

      // Act - First request (should hit network)
      final response1 = await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
        ),
      );

      // Act - Second request (should hit cache)
      final response2 = await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
        ),
      );

      // Assert
      expect(response1.data, {'data': 'test'});
      expect(response2.data, {'data': 'test'});
      expect(mockAdapter.callCount, 1); // Only one network call
    });

    test('should not cache when enableCache is false', () async {
      // Reset call count
      mockAdapter.callCount = 0;

      // Act
      final response1 = await dio.get(
        '/test',
        options: Options().setCaching(enableCache: false),
      );

      final response2 = await dio.get(
        '/test',
        options: Options().setCaching(enableCache: false),
      );

      // Assert - Both should be network calls
      expect(response1.data, {'data': 'test'});
      expect(response2.data, {'data': 'test'});
      expect(mockAdapter.callCount, 2); // Two network calls
    });
  });

  group('Dynamic Duration Functions', () {
    test('should use dynamic duration function', () async {
      // Arrange
      var durationCallCount = 0;

      // Act
      final response = await dio.get(
        '/test',
        options: Options().setCachingWithDurationFn(
          enableCache: true,
          durationFn: () {
            durationCallCount++;
            return const Duration(minutes: 15);
          },
        ),
      );

      // Assert
      expect(response.data, {'data': 'test'});
      expect(durationCallCount, 1);
    });
  });

  group('Dynamic Expiry Functions', () {
    test('should use dynamic expiry function', () async {
      // Arrange
      var expiryCallCount = 0;

      // Act
      final response = await dio.get(
        '/test',
        options: Options().setCachingWithExpiryFn(
          enableCache: true,
          expiryFn: () {
            expiryCallCount++;
            return DateTime.now().add(const Duration(hours: 2));
          },
        ),
      );

      // Assert
      expect(response.data, {'data': 'test'});
      expect(expiryCallCount, 1);
    });
  });

  group('Conditional Caching Rules', () {
    test('should cache based on conditional rule', () async {
      // Reset call count
      mockAdapter.callCount = 0;

      // Add conditional rule
      DioCachePlusInterceptor.addConditionalCaching(
        'users_rule',
        ConditionalCacheRule.duration(
          condition: (request) => request.url.contains('/users'),
          duration: const Duration(minutes: 30),
        ),
      );

      // Act - This should be cached due to rule
      final userResponse1 = await dio.get('/users');
      final userResponse2 = await dio.get('/users');

      // Act - This should not be cached (no rule match)
      final productResponse1 = await dio.get('/products');
      final productResponse2 = await dio.get('/products');

      // Assert
      expect(userResponse1.data, {
        'users': ['user1', 'user2'],
      });
      expect(userResponse2.data, {
        'users': ['user1', 'user2'],
      });
      expect(productResponse1.data, {
        'products': ['product1', 'product2'],
      });
      expect(productResponse2.data, {
        'products': ['product1', 'product2'],
      });
      expect(mockAdapter.callCount, 3); // users(1) + products(2)
    });

    test('should use dynamic duration in conditional rule', () async {
      // Arrange
      var dynamicCallCount = 0;

      DioCachePlusInterceptor.addConditionalCaching(
        'news_rule',
        ConditionalCacheRule.durationFn(
          condition: (request) => request.url.contains('/news'),
          durationFn: () {
            dynamicCallCount++;
            return const Duration(hours: 1);
          },
        ),
      );

      mockAdapter.callCount = 0;

      // Act
      await dio.get('/news');
      await dio.get('/news'); // served from cache, nothing stored

      // Assert
      expect(dynamicCallCount, 1); // Called once, at cache storage time
      expect(mockAdapter.callCount, 1);
    });
  });

  group('Request Deduplication', () {
    test('should deduplicate identical concurrent requests', () async {
      // Reset call count
      mockAdapter.callCount = 0;

      // Act - Fire multiple identical requests simultaneously
      final futures = List.generate(
        5,
        (i) => dio.get(
          '/test',
          options: Options().setCachingWithDuration(
            enableCache: true,
            duration: const Duration(minutes: 5),
          ),
        ),
      );

      final responses = await Future.wait(futures);

      // Assert - All responses should be the same, only one network call
      expect(responses.length, 5);
      for (final response in responses) {
        expect(response.data, {'data': 'test'});
      }
      expect(
        mockAdapter.callCount,
        1,
      ); // Only one network call despite 5 requests
    });
  });

  group('Force Refresh', () {
    test('should force refresh when invalidateCache is true', () async {
      // Reset call count
      mockAdapter.callCount = 0;

      // Act - First request (cache)
      final response1 = await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
        ),
      );

      // Act - Second request (force refresh)
      final response2 = await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 10),
          invalidateCache: true,
        ),
      );

      // Assert - Both should work, but two network calls due to force refresh
      expect(response1.data, {'data': 'test'});
      expect(response2.data, {'data': 'test'});
      expect(
        mockAdapter.callCount,
        2,
      ); // Two network calls due to force refresh
    });
  });

  group('RequestDetails', () {
    test('should provide correct request details to condition', () async {
      // Arrange
      RequestDetails? capturedDetails;

      DioCachePlusInterceptor.addConditionalCaching(
        'test_rule',
        ConditionalCacheRule.conditionalOnly(
          condition: (request) {
            capturedDetails = request;
            return true;
          },
        ),
      );

      // Act
      await dio.get('/test', queryParameters: {'page': '1', 'limit': '10'});

      // Assert
      expect(capturedDetails, isNotNull);
      expect(capturedDetails!.method, 'GET');
      // url is the full request URL, query string included
      expect(Uri.parse(capturedDetails!.url).path, '/test');
      expect(capturedDetails!.queryParameters, {'page': '1', 'limit': '10'});
    });
  });

  group('Factory Constructors', () {
    test('should work with all factory constructor types', () {
      // Test duration factory
      final durationRule = ConditionalCacheRule.duration(
        condition: (request) => request.url.contains('/api'),
        duration: const Duration(minutes: 30),
      );
      expect(durationRule.duration, const Duration(minutes: 30));

      // Test durationFn factory
      final durationFnRule = ConditionalCacheRule.durationFn(
        condition: (request) => request.url.contains('/api'),
        durationFn: () => const Duration(hours: 2),
      );
      expect(durationFnRule.durationFn, isA<Function>());

      // Test expiry factory
      final expiry = DateTime.now().add(const Duration(hours: 1));
      final expiryRule = ConditionalCacheRule.expiry(
        condition: (request) => request.url.contains('/api'),
        expiry: expiry,
      );
      expect(expiryRule.expiry, expiry);

      // Test expiryFn factory
      final expiryFnRule = ConditionalCacheRule.expiryFn(
        condition: (request) => request.url.contains('/api'),
        expiryFn: () => DateTime.now().add(const Duration(days: 1)),
      );
      expect(expiryFnRule.expiryFn, isA<Function>());

      // Test conditionalOnly factory
      final conditionalOnlyRule = ConditionalCacheRule.conditionalOnly(
        condition: (request) => request.url.contains('/api'),
      );
      expect(conditionalOnlyRule.duration, isNull);
    });
  });

  group('Edge Cases', () {
    Options cached() => Options().setCachingWithDuration(
      enableCache: true,
      duration: const Duration(minutes: 5),
    );

    test('constructing the interceptor again returns the same instance', () {
      final second = DioCachePlusInterceptor(
        cacheAll: true,
        commonCacheDuration: const Duration(seconds: 1),
        isErrorResponse: (_) => false,
      );
      expect(identical(second, cacheInterceptor), true);
    });

    test('FormData requests complete and are never cached or merged', () async {
      mockAdapter.callCount = 0;
      FormData form() => FormData.fromMap({'file': 'contents'});

      await dio.post('/test', data: form(), options: cached());
      await dio.post('/test', data: form(), options: cached());
      await Future.wait([
        dio.post('/test', data: form(), options: cached()),
        dio.post('/test', data: form(), options: cached()),
      ]);

      expect(mockAdapter.callCount, 4);
    });

    test('non-JSON query values still produce a stable cache key', () async {
      mockAdapter.callCount = 0;
      final query = {'since': DateTime.utc(2025, 1, 1)};

      await dio.get('/test', queryParameters: query, options: cached());
      await dio.get('/test', queryParameters: query, options: cached());

      expect(mockAdapter.callCount, 1);
    });

    test(
      'errors reach every deduplicated request and are not cached',
      () async {
        mockAdapter.callCount = 0;
        mockAdapter.statusCode = 500;

        final results = await Future.wait(
          List.generate(
            3,
            (_) => dio
                .get('/test', options: cached())
                .then<Object>((r) => r, onError: (Object e) => e),
          ),
        );
        expect(results, everyElement(isA<DioException>()));
        expect(mockAdapter.callCount, 1);

        mockAdapter.statusCode = 200;
        final response = await dio.get('/test', options: cached());
        expect(response.data, {'data': 'test'});
        expect(mockAdapter.callCount, 2);
      },
    );

    test('expired entries are fetched again', () async {
      mockAdapter.callCount = 0;
      final shortLived = Options().setCachingWithDuration(
        enableCache: true,
        duration: const Duration(milliseconds: 20),
      );

      await dio.get('/test', options: shortLived);
      await Future.delayed(const Duration(milliseconds: 40));
      await dio.get('/test', options: shortLived);

      expect(mockAdapter.callCount, 2);
    });

    test(
      'saveResponse stores without caching and getCacheData reads it',
      () async {
        mockAdapter.callCount = 0;
        await dio.get('/news', options: Options().saveResponse());
        await dio.get('/news', options: Options().saveResponse());

        // Saved responses are not served from cache automatically
        expect(mockAdapter.callCount, 2);
        final saved = await DioCachePlusInterceptor.getCacheData(url: '/news');
        expect(saved?.data, {
          'news': ['news1', 'news2'],
        });
      },
    );

    test('saveResponse with a FormData body stores nothing', () async {
      final form = FormData.fromMap({'file': 'contents'});
      await dio.post('/news', data: form, options: Options().saveResponse());

      final saved = await DioCachePlusInterceptor.getCacheData(
        url: '/news',
        method: 'POST',
        body: form,
      );
      expect(saved, isNull);
      expect(cacheManager.length, 0);
    });

    test('force refresh replaces the cached entry', () async {
      mockAdapter.callCount = 0;
      await dio.get('/test', options: cached());
      await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 5),
          invalidateCache: true,
        ),
      );
      await dio.get('/test', options: cached());

      expect(mockAdapter.callCount, 2);
    });
  });

  group('Cache-Status and Age headers', () {
    const name = 'dio_cache_plus';
    Options cached([Duration d = const Duration(minutes: 5)]) =>
        Options().setCachingWithDuration(enableCache: true, duration: d);
    List<String>? status(Response r) => r.headers['cache-status'];
    String? age(Response r) => r.headers.value('age');

    test('caching disabled: fwd=bypass, not from cache, no Age', () async {
      final r = await dio.get('/test');
      expect(status(r), ['$name; fwd=bypass']);
      expect(age(r), isNull);
    });

    test('miss is stored, then served as hit with ttl and Age', () async {
      final live = await dio.get('/test', options: cached());
      expect(status(live), ['$name; fwd=uri-miss; stored']);

      final hit = await dio.get('/test', options: cached());
      expect(age(hit), '0');
      final ttl = int.parse(
        RegExp(r'ttl=(-?\d+)').firstMatch(status(hit)!.single)!.group(1)!,
      );
      expect(ttl, inInclusiveRange(298, 300));
      expect(status(hit)!.single, startsWith('$name; hit; ttl='));
    });

    test('Age and ttl reflect time spent in cache', () async {
      await dio.get('/test', options: cached());
      cacheManager.setStoredAt(
        DateTime.now().subtract(const Duration(seconds: 100)),
      );
      final hit = await dio.get('/test', options: cached());
      expect(int.parse(age(hit)!), inInclusiveRange(100, 101));
      final ttl = int.parse(
        RegExp(r'ttl=(-?\d+)').firstMatch(status(hit)!.single)!.group(1)!,
      );
      expect(ttl, inInclusiveRange(198, 200));
    });

    test('expired entry is fetched again: fwd=stale; stored', () async {
      await dio.get('/test', options: cached(const Duration(milliseconds: 10)));
      await Future.delayed(const Duration(milliseconds: 30));
      final r = await dio.get(
        '/test',
        options: cached(const Duration(milliseconds: 10)),
      );
      expect(status(r), ['$name; fwd=stale; stored']);
    });

    test('forced refresh: fwd=request; stored', () async {
      await dio.get('/test', options: cached());
      final r = await dio.get(
        '/test',
        options: Options().setCachingWithDuration(
          enableCache: true,
          duration: const Duration(minutes: 5),
          invalidateCache: true,
        ),
      );
      expect(status(r), ['$name; fwd=request; stored']);
    });

    test('getCacheData marks hits, with negative ttl when stale', () async {
      await dio.get('/test', options: cached(const Duration(seconds: 10)));
      cacheManager.setStoredAt(
        DateTime.now().subtract(const Duration(seconds: 70)),
      );
      final stale = await DioCachePlusInterceptor.getCacheData(url: '/test');
      expect(status(stale!)!.single, startsWith('$name; hit; ttl=-'));
      final ttl = int.parse(
        RegExp(r'ttl=(-?\d+)').firstMatch(status(stale)!.single)!.group(1)!,
      );
      expect(ttl, inInclusiveRange(-61, -60));
      expect(int.parse(age(stale)!), inInclusiveRange(70, 71));
    });

    test('saveResponse: fwd=bypass; stored', () async {
      final r = await dio.get('/test', options: Options().saveResponse());
      expect(status(r), ['$name; fwd=bypass; stored']);
    });

    test('FormData upload: fwd=bypass, never stored', () async {
      final r = await dio.post(
        '/test',
        data: FormData.fromMap({'f': 'x'}),
        options: cached(),
      );
      expect(status(r), ['$name; fwd=bypass']);
    });

    test('"stored" only when the write really happened', () async {
      // isErrorResponse rejects 201 in this setup
      mockAdapter.statusCode = 201;
      final rejected = await dio.get('/test', options: cached());
      expect(status(rejected), ['$name; fwd=uri-miss']);

      mockAdapter.statusCode = 200;
      final zero = await dio.get('/users', options: cached(Duration.zero));
      expect(status(zero), ['$name; fwd=uri-miss']);

      cacheManager.failWrites = true;
      final failed = await dio.get('/news', options: cached());
      expect(status(failed), ['$name; fwd=uri-miss']);
      expect(cacheManager.length, 0);
    });

    test('upstream Age and Cache-Status are kept and combined', () async {
      mockAdapter.upstreamHeaders = {
        'age': ['100'],
        'cache-status': ['cloudflare; hit'],
      };
      final live = await dio.get('/test', options: cached());
      expect(status(live), ['cloudflare; hit', '$name; fwd=uri-miss; stored']);
      expect(age(live), '100');

      final hit = await dio.get('/test', options: cached());
      expect(status(hit)!.length, 2);
      expect(status(hit)!.first, 'cloudflare; hit');
      expect(status(hit)!.last, startsWith('$name; hit; ttl='));
      expect(int.parse(age(hit)!), inInclusiveRange(100, 101));
    });

    test('invalid upstream Age is ignored', () async {
      mockAdapter.upstreamHeaders = {
        'age': ['soon'],
      };
      await dio.get('/test', options: cached());
      final hit = await dio.get('/test', options: cached());
      expect(age(hit), '0');
    });

    test('stored entry is never modified by the added headers', () async {
      await dio.get('/test', options: cached());
      await dio.get('/test', options: cached());
      await dio.get('/test', options: cached());

      final stored = cacheManager.onlyEntry;
      expect(stored.headers['cache-status'], isNull);
      expect(stored.headers['age'], isNull);

      // repeated hits never stack entries
      final hit = await dio.get('/test', options: cached());
      expect(status(hit)!.length, 1);
    });

    test(
      'manager returning its stored object: Age never double-counts',
      () async {
        cacheManager.returnStoredObject = true;
        mockAdapter.upstreamHeaders = {
          'age': ['100'],
        };
        await dio.get('/test', options: cached());
        cacheManager.setStoredAt(
          DateTime.now().subtract(const Duration(seconds: 50)),
        );
        for (var i = 0; i < 3; i++) {
          final hit = await dio.get('/test', options: cached());
          // 100 from upstream + 50 in this cache, on every hit
          expect(int.parse(age(hit)!), inInclusiveRange(150, 151));
          expect(status(hit)!.single, startsWith('$name; hit; ttl='));
        }
        expect(cacheManager.onlyEntry.headers.value('age'), '100');
      },
    );

    test('empty upstream Age list is ignored', () async {
      mockAdapter.upstreamHeaders = {'age': []};
      await dio.get('/test', options: cached());
      final hit = await dio.get('/test', options: cached());
      expect(age(hit), '0');
      expect(status(hit)!.single, startsWith('$name; hit; ttl='));
    });

    test('device clock moved backwards: Age clamps to 0', () async {
      await dio.get('/test', options: cached());
      cacheManager.setStoredAt(DateTime.now().add(const Duration(hours: 1)));
      final hit = await dio.get('/test', options: cached());
      expect(age(hit), '0');
    });

    test('deduplicated requests share the same status', () async {
      final responses = await Future.wait(
        List.generate(3, (_) => dio.get('/test', options: cached())),
      );
      for (final r in responses) {
        expect(status(r), ['$name; fwd=uri-miss; stored']);
      }
    });

    test('error responses are not marked', () async {
      mockAdapter.statusCode = 500;
      try {
        await dio.get('/test', options: cached());
        fail('expected DioException');
      } on DioException catch (e) {
        expect(e.response?.headers['cache-status'], isNull);
      }
    });
  });

  test(
    'a throwing isErrorResponse callback does not hang the request',
    () async {
      DioCachePlusInterceptor.resetInstance();
      final adapter = MockNetworkAdapter({
        '/test': {'data': 'test'},
      });
      final store = InMemoryCacheManager();
      final throwingDio = Dio()..httpClientAdapter = adapter;
      throwingDio.interceptors.add(
        DioCachePlusInterceptor(
          cacheAll: true,
          commonCacheDuration: const Duration(minutes: 5),
          isErrorResponse: (r) => throw StateError('bad callback'),
          cacheManager: store,
        ),
      );

      final r = await throwingDio
          .get('/test')
          .timeout(const Duration(seconds: 2));
      expect(r.data, {'data': 'test'});
      expect(r.headers['cache-status'], ['dio_cache_plus; fwd=uri-miss']);
      expect(store.length, 0);
    },
  );
}
