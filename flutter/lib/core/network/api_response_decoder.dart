import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_error.dart';

class ApiResponseDecoder {
  const ApiResponseDecoder();

  Map<String, dynamic> decode(http.Response response) {
    final body = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      final server = status >= 500;
      throw ApiException(
        server ? ApiErrorMessages.server : (_message(body) ?? ApiErrorMessages.requestFailed),
        statusCode: status,
        code: _code(body),
        kind: server ? ApiErrorKind.server : (status == 401 ? ApiErrorKind.auth : ApiErrorKind.response),
        retryable: server || status == 408 || status == 429,
      );
    }
    if (body is! Map<String, dynamic>) {
      throw const ApiException(ApiErrorMessages.invalidResponse, kind: ApiErrorKind.response);
    }
    if (body['success'] == false) {
      throw ApiException(_message(body) ?? ApiErrorMessages.requestFailed, code: _code(body));
    }
    return body;
  }

  dynamic _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String? _message(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final error = body['error'];
    if (error is Map<String, dynamic> && error['message'] != null) return error['message'].toString();
    if (error != null && error is! Map) return error.toString();
    return body['message']?.toString();
  }

  String? _code(dynamic body) {
    if (body is! Map<String, dynamic>) return null;
    final error = body['error'];
    if (error is Map<String, dynamic> && error['code'] != null) return error['code'].toString();
    return body['code']?.toString();
  }
}
