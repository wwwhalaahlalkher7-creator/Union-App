import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/auth_storage.dart';

class _CachedResponse {
  const _CachedResponse(this.value, this.expiresAt);
  final Map<String, dynamic> value;
  final DateTime expiresAt;
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.cause});
  final String message; final int? statusCode; final Object? cause;
  @override String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static final Map<String, _CachedResponse> _publicCache = <String, _CachedResponse>{};
  ApiClient({required this.baseUrl, http.Client? client, this.authStorage}) : _client = client ?? http.Client();
  final String baseUrl; final http.Client _client; final AuthStorage? authStorage;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query, Duration? cacheTtl, bool forceRefresh = false}) async => _request('GET', path, query: query, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic> body = const {}}) async => _request('POST', path, body: body);
  Future<Map<String, dynamic>> deleteJson(String path) async => _request('DELETE', path);

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
      final token = authStorage?.accessToken;
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (body != null) { headers['Content-Type'] = 'application/json'; }
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20)),
        'DELETE' => await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 20)),
        _ => await _client.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(const Duration(seconds: 20)),
      };
      if (response.statusCode == 401 && retry && authStorage?.refreshToken?.isNotEmpty == true) {
        final refreshed = await _refreshSession();
        if (refreshed) return _request(method, path, query: query, body: body, retry: false, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
      }
      final decoded = _decode(response);
      if (canCache) {
        _publicCache[cacheKey] = _CachedResponse(decoded, DateTime.now().add(cacheTtl));
      }
      return decoded;
    } on ApiException { rethrow; }
      on TimeoutException catch (e) { throw ApiException('انتهت مهلة الاتصال بالخدمة. أعد المحاولة.', cause: e); }
      on http.ClientException catch (e) { throw ApiException('تعذر الاتصال بالخدمة حاليًا. تحقق من اتصال الإنترنت ثم أعد المحاولة.', cause: e); }
  }

  Future<bool> _refreshSession() async {
    final refresh = authStorage?.refreshToken; if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _client.post(_buildUri('/api/v1/auth/refresh'), headers: const {'Accept':'application/json','Content-Type':'application/json'}, body: jsonEncode({'refreshToken': refresh})).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data']; if (data is Map) { await authStorage?.saveRefreshedSession(Map<String,dynamic>.from(data)); return true; }
      }
    } catch (_) {}
    await authStorage?.clear(); return false;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl); final normalized = path.trim();
    return base.replace(path: normalized.isEmpty || normalized == '/' ? base.path : '${base.path}${normalized.startsWith('/') ? normalized : '/$normalized'}', queryParameters: {...base.queryParameters, ...?query});
  }
  Map<String, dynamic> _decode(http.Response response) {
    dynamic body; try { body = jsonDecode(response.body); } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException(_extractErrorMessage(body) ?? 'حدث خطأ في الخادم', statusCode: response.statusCode);
    if (body is! Map<String, dynamic>) throw const ApiException('استجابة غير صالحة من الخادم');
    if (body['success'] == false) throw ApiException(_extractErrorMessage(body) ?? 'تعذر تنفيذ الطلب');
    return body;
  }
  String? _extractErrorMessage(dynamic body) {
    if (body is! Map<String, dynamic>) return null; final error = body['error'];
    if (error is Map<String,dynamic> && error['message'] != null) return error['message'].toString();
    if (error != null && error is! Map) return error.toString(); if (body['message'] != null) return body['message'].toString(); return null;
  }
  void dispose() => _client.close();
}
