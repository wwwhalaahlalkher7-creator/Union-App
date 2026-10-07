import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../storage/auth_storage.dart';
import 'offline_cache.dart';
import 'offline_state.dart';
import 'api_transport.dart';
import 'api_response_decoder.dart';
import 'api_error_messages.dart';
import 'session_refresher.dart';
import '../errors/app_error.dart';
export '../errors/app_error.dart' show ApiException, ApiErrorKind;

class _CachedResponse {
  const _CachedResponse(this.value, this.expiresAt);

  final Map<String, dynamic> value;
  final DateTime expiresAt;
}

class ApiClient {
  static final Map<String, _CachedResponse> _publicCache = <String, _CachedResponse>{};
  ApiClient({required this.baseUrl, http.Client? client, this.authStorage}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final AuthStorage? authStorage;
  late final ApiTransport _transport = ApiTransport(_client);
  late final ApiResponseDecoder _decoder = const ApiResponseDecoder();
  late final SessionRefresher _sessionRefresher = SessionRefresher(
    client: _client,
    storage: authStorage,
    uri: _buildUri('/api/v1/auth/refresh'),
  );

  static const _offlineCacheMaxStale = Duration(days: 7);

  bool _offlineCacheAllowed(String path) {
    final p = path.toLowerCase();
    if (!p.startsWith('/api/v1/')) return false;
    if (p.contains('/auth/')) return false;
    if (p.contains('/eino/')) return false;
    return p.startsWith('/api/v1/public/') ||
        p.startsWith('/api/v1/departments') ||
        p.startsWith('/api/v1/semesters') ||
        p.startsWith('/api/v1/subjects') ||
        p.startsWith('/api/v1/materials') ||
        p.startsWith('/api/v1/schedule') ||
        p.startsWith('/api/v1/student/stats') ||
        p.startsWith('/api/v1/progress') ||
        p.startsWith('/api/v1/xp') ||
        p.startsWith('/api/v1/badges');
  }


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
      return _decoder.decode(response);
    }
    try {
      final result = await send();
      return result;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && (await authStorage?.refreshToken)?.isNotEmpty == true) {
        final refreshed = await _sessionRefresher.refresh();
        if (refreshed) return send();
      }
      rethrow;
    } on TimeoutException catch (e) {
      throw ApiException(ApiErrorMessages.fileTimeout, cause: e, kind: ApiErrorKind.timeout, retryable: true);
    } on SocketException catch (e) {
      throw ApiException(ApiErrorMessages.offline, cause: e, kind: ApiErrorKind.offline, retryable: true);
    } on http.ClientException catch (e) {
      throw ApiException(ApiErrorMessages.offline, cause: e, kind: ApiErrorKind.offline, retryable: true);
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
    final persistentCacheKey = method == 'GET' && _offlineCacheAllowed(path)
        ? await _persistentCacheKey(cacheKey)
        : cacheKey;
    final canCache = method == 'GET' && cacheTtl != null && authStorage == null;
    // Network-first policy: the server is authoritative. Persistent cache is
    // used only after a confirmed network failure, never as a silent substitute
    // while the device is online.
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final token = await authStorage?.accessToken;
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (body != null) { headers['Content-Type'] = 'application/json'; }
      final timeout = _requestTimeout(path);
      final response = await _transport.send(
        method,
        uri,
        headers: headers,
        body: body,
        timeout: timeout,
      );
      if (response.statusCode == 401 && retry && _canRefreshFor(path) && (await authStorage?.refreshToken)?.isNotEmpty == true) {
        final refreshed = await _sessionRefresher.refresh();
        if (refreshed) {
          return await _request(method, path, query: query, body: body, retry: false, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
        }
      }
      // Receiving any HTTP response proves that the device can reach the
      // server, even when the server returns 4xx/5xx. Clear the offline banner
      // before decoding the payload so server errors never look like offline mode.
      OfflineState.instance.markOnline();
      final decoded = _decoder.decode(response);
      if (canCache) {
        _publicCache[cacheKey] = _CachedResponse(decoded, DateTime.now().add(cacheTtl));
      }
      if (method == 'GET' && _offlineCacheAllowed(path)) {
        await OfflineCache.instance.write(persistentCacheKey, decoded);
      }
      return decoded;
    } on ApiException { rethrow; }
      on TimeoutException catch (e) {
        throw ApiException(ApiErrorMessages.timeout, cause: e, kind: ApiErrorKind.timeout, retryable: true);
      }
      on SocketException catch (e) {
        return _offlineFallbackOrThrow(persistentCacheKey, path, ApiException(ApiErrorMessages.offline, cause: e, kind: ApiErrorKind.offline, retryable: true));
      }
      on http.ClientException catch (e) {
        return _offlineFallbackOrThrow(persistentCacheKey, path, ApiException(ApiErrorMessages.offline, cause: e, kind: ApiErrorKind.offline, retryable: true));
      }
  }

  Future<String> _persistentCacheKey(String uri) async {
    final studentNumber = await authStorage?.studentNumber;
    if (studentNumber == null || studentNumber.trim().isEmpty) return 'public|$uri';
    return 'student:${studentNumber.trim()}|$uri';
  }

  Future<Map<String, dynamic>> _offlineFallbackOrThrow(String cacheKey, String path, ApiException error) async {
    OfflineState.instance.markOffline();
    if (_offlineCacheAllowed(path)) {
      final cached = await OfflineCache.instance.read(cacheKey, maxStale: _offlineCacheMaxStale);
      if (cached != null) return cached;
    }
    throw error;
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
  void dispose() => _transport.dispose();
}
