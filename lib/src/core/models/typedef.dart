// lib/src/core/models/typedef.dart

typedef RequestMatcher = bool Function(RequestDetails request);

class RequestDetails {
  final String method;
  final String url;
  final Map<String, dynamic> queryParameters;

  RequestDetails(this.method, this.url, this.queryParameters);
}
