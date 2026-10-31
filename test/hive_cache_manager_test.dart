import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_plus/src/core/cache_manager/hive_cache_manager.dart';
import 'package:dio_cache_plus/src/core/models/typedef.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

Response _response(String path, {Map<String, dynamic>? query}) {
  // Real apps set a base URL; Dio 4.0.0 can't build a URI without one.
  final options = RequestOptions(
    path: path,
    baseUrl: 'https://example.com',
    queryParameters: query,
  )..extra['cache_validity_duration'] = const Duration(minutes: 5);
  return Response(
    requestOptions: options,
    data: {'path': path},
    statusCode: 200,
    headers: Headers.fromMap({
      'content-type': ['application/json'],
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  void mockPathProvider() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (_) async => tempDir.path);
  }

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('dio_cache_plus_test');
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test(
    'a failed init rejects every waiter and retries on the next call',
    () async {
      // No path_provider available yet: initialization must fail, not hang.
      final manager = HiveCacheManager();
      final options = RequestOptions(path: '/a');
      final first = manager.getData('a', options);
      final second = manager.getData('a', options);
      await expectLater(first, throwsA(anything));
      await expectLater(second, throwsA(anything));

      mockPathProvider();
      expect(await manager.getData('a', options), isNull);
    },
  );

  group('with Hive available', () {
    late HiveCacheManager manager;

    setUp(() async {
      mockPathProvider();
      manager = HiveCacheManager();
      await manager.clearAll();
    });

    test('concurrent first calls share one initialization', () async {
      final results = await Future.wait([
        manager.getData('x', RequestOptions(path: '/x')),
        manager.getData('y', RequestOptions(path: '/y')),
      ]);
      expect(results, [null, null]);
    });

    test('stores, restores and removes a response', () async {
      final response = _response('/users');
      await manager.setData('users', response);

      final restored = await manager.getData('users', response.requestOptions);
      expect(restored?.data, {'path': '/users'});
      expect(restored?.statusCode, 200);
      expect(
        restored?.extra['cache_validity_duration'],
        const Duration(minutes: 5),
      );

      await manager.remove('users');
      expect(await manager.getData('users', response.requestOptions), isNull);
    });

    test(
      'removeConditional removes all matches and skips throwing matchers',
      () async {
        for (var i = 0; i < 5; i++) {
          await manager.setData('news$i', _response('/news/$i'));
        }
        await manager.setData('keep', _response('/keep'));
        await manager.setData('boom', _response('/boom'));

        bool matcher(RequestDetails r) {
          if (r.url.contains('/boom')) throw StateError('bad matcher');
          return r.url.contains('/news');
        }

        await manager.removeConditional(matcher);

        for (var i = 0; i < 5; i++) {
          expect(
            await manager.getData('news$i', RequestOptions(path: '/news/$i')),
            isNull,
          );
        }
        expect(
          await manager.getData('keep', RequestOptions(path: '')),
          isNotNull,
        );
        expect(
          await manager.getData('boom', RequestOptions(path: '')),
          isNotNull,
        );
      },
    );
  });
}
