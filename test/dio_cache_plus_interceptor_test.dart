import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';
import 'package:dio_cache_plus/src/core/models/typedef.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock interceptor that simulates network responses
class MockNetworkInterceptor extends Interceptor {
  final Map<String, dynamic> mockResponses;
  int callCount = 0;

  MockNetworkInterceptor(this.mockResponses);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    callCount++;
    final responseData = mockResponses[options.path] ?? {'error': 'Not found'};

    final response = Response(
      requestOptions: options,
      data: responseData,
      statusCode: 200,
      headers: Headers(),
    );

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 10), () {
      handler.resolve(response);
    });
  }
}

void main() {
  late Dio dio;
  late DioCachePlusInterceptor cacheInterceptor;
  late MockNetworkInterceptor mockInterceptor;

  setUp(() {
    dio = Dio();
    mockInterceptor = MockNetworkInterceptor({
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
    );

    dio.interceptors.addAll([mockInterceptor, cacheInterceptor]);
  });

  tearDown(() {
    DioCachePlusInterceptor.clearAll();
  });

  group('Basic Caching', () {
    test('should cache GET request when enabled', () async {
      // Reset call count
      mockInterceptor.callCount = 0;

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
      expect(mockInterceptor.callCount, 1); // Only one network call
    });

    test('should not cache when enableCache is false', () async {
      // Reset call count
      mockInterceptor.callCount = 0;

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
      expect(mockInterceptor.callCount, 2); // Two network calls
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
      mockInterceptor.callCount = 0;

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
      expect(mockInterceptor.callCount, 3); // users(1) + products(2)
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

      // Act
      await dio.get('/news');
      await dio.get('/news');

      // Assert
      expect(dynamicCallCount, 2); // Called for each cache storage
    });
  });

  group('Request Deduplication', () {
    test('should deduplicate identical concurrent requests', () async {
      // Reset call count
      mockInterceptor.callCount = 0;

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
        mockInterceptor.callCount,
        1,
      ); // Only one network call despite 5 requests
    });
  });

  group('Force Refresh', () {
    test('should force refresh when invalidateCache is true', () async {
      // Reset call count
      mockInterceptor.callCount = 0;

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
        mockInterceptor.callCount,
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
      expect(capturedDetails!.url, '/test');
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
}
