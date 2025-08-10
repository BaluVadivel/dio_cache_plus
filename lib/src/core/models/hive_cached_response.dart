import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../constants/sanitizer_constants.dart';

part 'hive_cached_response.g.dart';

@HiveType(typeId: 0)
class HiveCachedResponse extends HiveObject {
  @override
  @HiveField(0)
  late String key;

  @HiveField(1)
  late int statusCode;

  @HiveField(2)
  late String data;

  @HiveField(3)
  late String headersJson;

  @HiveField(4)
  late DateTime timestamp;

  @HiveField(5)
  Duration? validity;

  @HiveField(6)
  String requestUrl;

  @HiveField(7)
  Map<String, dynamic> queryParameters;

  HiveCachedResponse({
    required this.key,
    required this.statusCode,
    required this.data,
    required this.headersJson,
    required this.timestamp,
    required this.validity,
    required this.requestUrl,
    required this.queryParameters,
  });

  HiveCachedResponse.fromResponse({
    required this.key,
    required Response response,
    Duration? validityDuration,
  })  : statusCode = response.statusCode ?? 200,
        data = jsonEncode(response.data),
        headersJson = jsonEncode(response.headers.map),
        timestamp = DateTime.now(),
        requestUrl = response.requestOptions.uri.toString().split("?").first,
        queryParameters = response.requestOptions.queryParameters,
        validity = validityDuration;

  Response toResponse(RequestOptions requestOptions) {
    return Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: jsonDecode(data),
        headers: Headers.fromMap(
          (jsonDecode(headersJson) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, List<String>.from(v))),
        ),
        extra: {
          SanitizerConstants.cacheTimeStampKey: timestamp.toIso8601String(),
          if (validity != null)
            SanitizerConstants.cacheValidityDurationKey: validity,
        });
  }
}
