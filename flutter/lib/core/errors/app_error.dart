/// Shared error types used across the Flutter application.
///
/// UI code should never need to know about HTTP implementation details.
/// Repositories/services throw [ApiException], and presentation code resolves
/// it to a user-facing message through [ErrorMessage].
library;

enum ApiErrorKind { offline, timeout, server, response, auth, client }

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.cause,
    this.kind = ApiErrorKind.client,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;
  final ApiErrorKind kind;
  final bool retryable;

  bool get isOffline => kind == ApiErrorKind.offline;
  bool get isAuth => kind == ApiErrorKind.auth || statusCode == 401;
  bool get isRetryable => retryable;

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, kind: $kind)';
}
