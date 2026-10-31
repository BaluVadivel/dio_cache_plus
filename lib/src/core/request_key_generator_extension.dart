// lib/src/core/request_key_generator_extension.dart

import 'dart:convert';

import 'package:dio/dio.dart';

import 'constants/sanitizer_constants.dart';

extension RequestKeyGeneratorExtension on RequestOptions {
  static int _uniqueKeyCounter = 0;

  String get generateRequestKey {
    if ((extra["generatedRequestKey"] is String) &&
        (extra["generatedRequestKey"] as String).isNotEmpty) {
      return extra["generatedRequestKey"] as String;
    }
    String rawKey;
    try {
      final method = this.method.toUpperCase();
      final path = uri.toString();
      // Dio sends query values via toString(), so use the same for the key.
      final queryParams = jsonEncode(
        Map.fromEntries(
          queryParameters.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)),
        ),
        toEncodable: (value) => value.toString(),
      );
      final body = data != null ? jsonEncode(data) : '';
      rawKey = '$method|$path|$queryParams|$body';
    } catch (_) {
      // The body (FormData, streams, ...) has no stable content key. Use a
      // unique key so distinct requests are never merged, and keep the
      // request out of caching.
      rawKey = 'non_cacheable|${_uniqueKeyCounter++}';
      extra[SanitizerConstants.nonCacheableRequestKey] = true;
    }
    extra["generatedRequestKey"] = rawKey;
    return rawKey;
  }
}
