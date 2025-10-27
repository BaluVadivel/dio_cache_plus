// lib/src/core/request_key_generator_extension.dart

import 'dart:convert';

import 'package:dio/dio.dart';

extension RequestKeyGeneratorExtension on RequestOptions {
  String get generateRequestKey {
    if ((extra["generatedRequestKey"] is String) &&
        (extra["generatedRequestKey"] as String).isNotEmpty) {
      return extra["generatedRequestKey"] as String;
    }
    final method = this.method.toUpperCase();
    final path = uri.toString();
    final queryParams = jsonEncode(
      Map.fromEntries(
        queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
    final body = data != null ? jsonEncode(data) : '';
    final rawKey = '$method|$path|$queryParams|$body';
    extra["generatedRequestKey"] = rawKey;
    return rawKey;
  }
}
