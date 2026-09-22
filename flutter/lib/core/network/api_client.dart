import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/auth_storage.dart';

class _CachedResponse {
  const _CachedResponse(this.value, this.expiresAt);
  final Map<String, dynamic> value;
  final DateTime expiresAt;
}

enum ApiErrorKind { offline, timeout, server, response, auth, client }

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.cause, this.kind = ApiErrorKind.client, this.retryable = false});
  final String message; final int? statusCode; final Object? cause; final ApiErrorKind kind; final bool retryable;
  @override String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static final Map<String, _CachedResponse> _publicCache = <String, _CachedResponse>{};
  static Future<bool>? _refreshInFlight;
  ApiClient({required this.baseUrl, http.Client? client, this.authStorage}) : _client = client ?? http.Client();
  final String baseUrl; final http.Client _client; final AuthStorage? authStorage;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query, Duration? cacheTtl, bool forceRefresh = false}) async => _request('GET', path, query: query, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic> body = const {}}) async => _request('POST', path, body: body);
  Future<Map<String, dynamic>> deleteJson(String path) async => _request('DELETE', path);
  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required List<int> bytes,
    required String filename,
    required String fieldName,
    String contentType = 'application/octet-stream',
    Map<String, String> fields = const {},
  }) async {
    final uri = _buildUri(path);
    Future<Map<String, dynamic>> send() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      final token = await authStorage?.accessToken;
      if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename, contentType: _mediaType(contentType)));
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    }
    try {
      final result = await send();
      return result;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && (await authStorage?.refreshToken)?.isNotEmpty == true) {
        final refreshed = await _refreshSession();
        if (refreshed) return send();
      }
      rethrow;
    } on TimeoutException catch (e) {
      throw ApiException('انتهت مهلة معالجة الملف. أعد المحاولة.', cause: e, kind: ApiErrorKind.timeout, retryable: true);
    } on SocketException catch (e) {
      throw ApiException('لا يوجد اتصال بالإنترنت. تحقق من اتصالك ثم أعد المحاولة.', cause: e, kind: ApiErrorKind.offline, retryable: true);
    } on http.ClientException catch (e) {
      throw ApiException('لا يوجد اتصال بالإنترنت. تحقق من اتصالك ثم أعد المحاولة.', cause: e, kind: ApiErrorKind.offline, retryable: true);
    }
  }

  http.MediaType? _mediaType(String value) {
    final parts = value.split('/');
    if (parts.length != 2 || parts.any((p) => p.isEmpty)) return null;
    return http.MediaType(parts[0], parts[1]);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool retry = true,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    final uri = _buildUri(path, query);
    final cacheKey = uri.toString();
    final canCache = method == 'GET' && cacheTtl != null && authStorage == null;
    if (canCache && !forceRefresh) {
      final cached = _publicCache[cacheKey];
      if (cached != null && cached.expiresAt.isAfter(DateTime.now())) return cached.value;
      if (cached != null) _publicCache.remove(cacheKey);
    }
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final token = await authStorage?.accessToken;
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (body != null) { headers['Content-Type'] = 'application/json'; }
      final timeout = _requestTimeout(path);
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(timeout),
        'DELETE' => await _client.delete(uri, headers: headers).timeout(timeout),
        _ => await _client.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(timeout),
      };
      if (response.statusCode == 401 && retry && _canRefreshFor(path) && (await authStorage?.refreshToken)?.isNotEmpty == true) {
        final refreshed = await _refreshSession();
        if (refreshed) {
          return await _request(method, path, query: query, body: body, retry: false, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
        }
      }
      final decoded = _decode(response);
      if (canCache) {
        _publicCache[cacheKey] = _CachedResponse(decoded, DateTime.now().add(cacheTtl));
      }
      return decoded;
    } on ApiException { rethrow; }
      on TimeoutException catch (e) { throw ApiException('انتهت مهلة الاتصال بالخدمة. أعد المحاولة.', cause: e, kind: ApiErrorKind.timeout, retryable: true); }
      on SocketException catch (e) { throw ApiException('لا يوجد اتصال بالإنترنت. تحقق من اتصالك ثم أعد المحاولة.', cause: e, kind: ApiErrorKind.offline, retryable: true); }
      on http.ClientException catch (e) { throw ApiException('لا يوجد اتصال بالإنترنت. تحقق من اتصالك ثم أعد المحاولة.', cause: e, kind: ApiErrorKind.offline, retryable: true); }
  }

  Duration _requestTimeout(String path) {
    final normalized = path.toLowerCase();
    // The Worker gives Eino up to 30s for chat/vision/TTS and up to 60s for
    // OCR/STT. A 20s Flutter timeout would make the app report a failure
    // while the backend is still processing a valid request.
    if (normalized.contains('/eino/ocr') || normalized.contains('/eino/stt')) {
      return const Duration(seconds: 90);
    }
    if (normalized.contains('/eino/chat') ||
        normalized.contains('/eino/vision') ||
        normalized.contains('/eino/tts')) {
      return const Duration(seconds: 45);
    }
    return const Duration(seconds: 20);
  }

  bool _canRefreshFor(String path) {
    final normalized = path.toLowerCase();
    // Authentication endpoints must never be retried through an existing
    // student session. Doing so can rotate an unrelated refresh token while
    // the user is trying to log in/register, producing confusing auth failures.
    return !normalized.contains('/auth/login') &&
        !normalized.contains('/auth/register') &&
        !normalized.contains('/auth/staff/login') &&
        !normalized.contains('/auth/staff/bootstrap') &&
        !normalized.contains('/auth/refresh') &&
        !normalized.contains('/auth/logout');
  }

  Future<bool> _refreshSession() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _performRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  Future<bool> _performRefresh() async {
    final storage = authStorage;
    final refresh = await storage?.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _client.post(
        _buildUri('/api/v1/auth/refresh'),
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      ).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 &&
          decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) {
          await storage?.saveRefreshedSession(Map<String, dynamic>.from(data));
          return true;
        }
      }
    } catch (_) {}
    await storage?.clear();
    return false;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    final cleanPath = path.trim();
    final normalizedPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    final rawCombined = '$basePath$normalizedPath';
    final combined = rawCombined.replaceAll(RegExp(r'/+'), '/');
    return base.replace(
      path: combined.isEmpty ? '/' : combined,
      queryParameters: {...base.queryParameters, ...?query},
    );
  }
  Map<String, dynamic> _decode(http.Response response) {
    dynamic body; try { body = jsonDecode(response.body); } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      final server = status >= 500;
      final message = server ? 'هناك خطأ في السيرفر. حاول مرة أخرى.' : (_extractErrorMessage(body) ?? 'تعذر تنفيذ الطلب.');
      throw ApiException(message, statusCode: status, kind: server ? ApiErrorKind.server : (status == 401 ? ApiErrorKind.auth : ApiErrorKind.response), retryable: server || status == 408 || status == 429);
    }
    if (body is! Map<String, dynamic>) throw const ApiException('استجابة غير صالحة من السيرفر.', kind: ApiErrorKind.response);
    if (body['success'] == false) throw ApiException(_extractErrorMessage(body) ?? 'تعذر تنفيذ الطلب.');
    return body;
  }
  String? _extractErrorMessage(dynamic body) {
    if (body is! Map<String, dynamic>) return null; final error = body['error'];
    if (error is Map<String,dynamic> && error['message'] != null) return error['message'].toString();
    if (error != null && error is! Map) return error.toString(); if (body['message'] != null) return body['message'].toString(); return null;
  }
  void dispose() => _client.close();
}
