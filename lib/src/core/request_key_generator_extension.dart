import 'dart:convert';

import 'package:dio/dio.dart';

extension RequestKeyGeneratorExtension on RequestOptions {
  String get generateRequestKey {
    final method = this.method.toUpperCase();
    final path = uri.toString();
    final queryParams = jsonEncode(Map.fromEntries(
        queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))));
    final headers = jsonEncode(Map.fromEntries(
        this.headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))));
    final body = data != null ? jsonEncode(data) : '';
    final rawKey = '$method|$path|$queryParams|$headers|$body';
    return rawKey;
  }
}
