import 'package:dio_cache_plus/src/core/models/conditional_cache_rule.dart';
import 'package:dio_cache_plus/src/core/models/typedef.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConditionalCacheRule', () {
    test('duration factory should create rule with static duration', () {
      // Act
      final rule = ConditionalCacheRule.duration(
        condition: (request) => request.url.contains('/api'),
        duration: const Duration(minutes: 30),
      );

      // Assert
      expect(rule.duration, const Duration(minutes: 30));
      expect(rule.durationFn, isNull);
      expect(rule.expiry, isNull);
      expect(rule.expiryFn, isNull);
    });

    test('durationFn factory should create rule with dynamic duration', () {
      // Act
      final rule = ConditionalCacheRule.durationFn(
        condition: (request) => request.url.contains('/api'),
        durationFn: () => const Duration(hours: 2),
      );

      // Assert
      expect(rule.duration, isNull);
      expect(rule.durationFn, isA<Function>());
      expect(rule.expiry, isNull);
      expect(rule.expiryFn, isNull);
    });

    test('expiry factory should create rule with static expiry', () {
      // Arrange
      final expiryTime = DateTime.now().add(const Duration(hours: 1));

      // Act
      final rule = ConditionalCacheRule.expiry(
        condition: (request) => request.url.contains('/api'),
        expiry: expiryTime,
      );

      // Assert
      expect(rule.duration, isNull);
      expect(rule.durationFn, isNull);
      expect(rule.expiry, expiryTime);
      expect(rule.expiryFn, isNull);
    });

    test('expiryFn factory should create rule with dynamic expiry', () {
      // Act
      final rule = ConditionalCacheRule.expiryFn(
        condition: (request) => request.url.contains('/api'),
        expiryFn: () => DateTime.now().add(const Duration(days: 1)),
      );

      // Assert
      expect(rule.duration, isNull);
      expect(rule.durationFn, isNull);
      expect(rule.expiry, isNull);
      expect(rule.expiryFn, isA<Function>());
    });

    test('conditionalOnly factory should create rule without timing', () {
      // Act
      final rule = ConditionalCacheRule.conditionalOnly(
        condition: (request) => request.url.contains('/api'),
      );

      // Assert
      expect(rule.duration, isNull);
      expect(rule.durationFn, isNull);
      expect(rule.expiry, isNull);
      expect(rule.expiryFn, isNull);
    });

    test('condition should be called with RequestDetails', () {
      // Arrange
      RequestDetails? capturedDetails;
      final rule = ConditionalCacheRule.duration(
        condition: (request) {
          capturedDetails = request;
          return true;
        },
        duration: const Duration(minutes: 30),
      );

      // Act
      final result = rule.condition(
        RequestDetails('GET', '/api/users', {'page': '1'}),
      );

      // Assert
      expect(result, true);
      expect(capturedDetails, isNotNull);
      expect(capturedDetails!.method, 'GET');
      expect(capturedDetails!.url, '/api/users');
      expect(capturedDetails!.queryParameters, {'page': '1'});
    });
  });
}
