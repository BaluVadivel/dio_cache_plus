import 'package:dio/dio.dart';
import 'package:dio_cache_plus/dio_cache_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheOptionsExtension', () {
    test('setCachingWithDuration should set correct extra values', () {
      // Act
      final options = Options().setCachingWithDuration(
        enableCache: true,
        duration: const Duration(minutes: 30),
        invalidateCache: true,
        overrideConditionalCache: true,
      );

      // Assert
      expect(options.extra?['enableCache'], true);
      expect(
        options.extra?['cache_validity_duration'],
        const Duration(minutes: 30),
      );
      expect(options.extra?['invalidateCache'], true);
      expect(options.extra?['overrideConditionalCache'], true);
    });

    test('setCachingWithDurationFn should set function in extra', () {
      // Act
      final options = Options().setCachingWithDurationFn(
        enableCache: true,
        durationFn: () => const Duration(hours: 2),
      );

      // Assert
      expect(options.extra?['enableCache'], true);
      expect(options.extra?['duration_function_key'], isA<Function>());
    });

    test('setCachingWithExpiry should set expiry in extra', () {
      // Arrange
      final expiry = DateTime.now().add(const Duration(hours: 1));

      // Act
      final options = Options().setCachingWithExpiry(
        enableCache: true,
        expiry: expiry,
      );

      // Assert
      expect(options.extra?['enableCache'], true);
      expect(options.extra?['dio_cache_plus_expiry_key'], expiry);
    });

    test('setCachingWithExpiryFn should set expiry function in extra', () {
      // Act
      final options = Options().setCachingWithExpiryFn(
        enableCache: true,
        expiryFn: () => DateTime.now().add(const Duration(days: 1)),
      );

      // Assert
      expect(options.extra?['enableCache'], true);
      expect(options.extra?['expiry_function_key'], isA<Function>());
    });

    test('setCaching should set basic caching', () {
      // Act
      final options = Options().setCaching(enableCache: true);

      // Assert
      expect(options.extra?['enableCache'], true);
      expect(options.extra?['invalidateCache'], false);
      expect(options.extra?['overrideConditionalCache'], false);
    });
  });
}
