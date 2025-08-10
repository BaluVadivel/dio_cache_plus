typedef RequestMatcher = bool Function(
  String requestUrl,
  Map<String, dynamic> queryParameters,
);
