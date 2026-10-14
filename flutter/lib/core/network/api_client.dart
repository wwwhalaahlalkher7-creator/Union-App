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
  // TTL cache is scoped by the persistent cache key (public or student-specific).
  // This prevents one signed-in student's response from leaking to another.
  static final Map<String, _CachedResponse> _publicCache = <String, _CachedResponse>{};
  // Share concurrent identical GETs so a cold cache cannot trigger duplicate HTTP requests.
  static final Map<String, Future<Map<String, dynamic>>> _inFlightGets =
      <String, Future<Map<String, dynamic>>>{};
  static int _memoryCacheHits = 0;
  static int _persistentCacheHits = 0;
  static int _networkGetRequests = 0;
  static int _coalescedGetRequests = 0;
  static int _offlineFallbackHits = 0;

  /// In-process counters for diagnostics and tests; they are not user data and
  /// intentionally reset when the app process restarts.
  static ApiCacheMetrics get cacheMetrics => ApiCacheMetrics(
        memoryHits: _memoryCacheHits,
        persistentHits: _persistentCacheHits,
        networkGets: _networkGetRequests,
        coalescedGets: _coalescedGetRequests,
        offlineFallbackHits: _offlineFallbackHits,
      );

  static void resetCacheMetrics() {
    _memoryCacheHits = 0;
    _persistentCacheHits = 0;
    _networkGetRequests = 0;
    _coalescedGetRequests = 0;
    _offlineFallbackHits = 0;
  }

  /// Resets process-local caches for deterministic unit tests.
  static void resetCachesForTesting() {
    _publicCache.clear();
    _inFlightGets.clear();
    resetCacheMetrics();
  }
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

  Future<String> get cacheScope async {
    final studentNumber = await authStorage?.studentNumber;
    return (studentNumber == null || studentNumber.trim().isEmpty) ? 'public' : studentNumber.trim();
  }

  Future<void> invalidateCacheForPath(String path) async {
    _publicCache.removeWhere((key, _) => key.contains(path));
    _inFlightGets.removeWhere((key, _) => key.contains(path));
    await OfflineCache.instance.removeMatching(path);
  }

  /// Clears entries scoped to the currently authenticated student before logout.
  /// Static/public data is not shared with this scope, so other users are unaffected.
  Future<void> clearCurrentStudentCache() async {
    final number = (await authStorage?.studentNumber)?.trim();
    if (number == null || number.isEmpty) return;
    final scope = 'student:$number|';
    _publicCache.removeWhere((key, _) => key.startsWith(scope));
    _inFlightGets.removeWhere((key, _) => key.startsWith(scope));
    await OfflineCache.instance.removePrefix(scope);
  }

  bool _offlineCacheAllowed(String path) {
    final p = path.toLowerCase();
    if (!p.startsWith('/api/v1/')) return false;
    if (p.contains('/auth/')) return false;
    // Public catalogue data can be cached under the public scope. Personal
    // learning state and conversations are persisted only under a student scope.
    const publicLists = <String>{
      '/api/v1/public/news',
      '/api/v1/public/announcements',
      '/api/v1/public/activities',
      '/api/v1/public/achievements',
      '/api/v1/public/settings',
      '/api/v1/public/materials',
      '/api/v1/departments',
      '/api/v1/semesters',
      '/api/v1/subjects',
      '/api/v1/materials',
      '/api/v1/schedule',
    };
    if (publicLists.contains(p)) {
      return true;
    }
    if (RegExp(r'^/api/v1/public/(news|activities|achievements)/[^/]+$').hasMatch(p) ||
        RegExp(r'^/api/v1/materials/[^/]+$').hasMatch(p)) {
      return true;
    }

    // Personal offline data is allowed only for signed-in student scopes. The
    // persistent key includes student identity and logout removes that prefix.
    const personalPrefixes = <String>{
      '/api/v1/student/profile',
      '/api/v1/student/stats',
      '/api/v1/progress',
      '/api/v1/xp',
      '/api/v1/badges',
      '/api/v1/schedule',
      '/api/v1/chat/messages',
      '/api/v1/eino/chats',
      '/api/v1/eino/memory',
    };
    if (personalPrefixes.any((prefix) => p == prefix || p.startsWith('$prefix/'))) {
      return true;
    }
    return false;
  }


  bool _isPersonalOfflinePath(String path) {
    final p = path.toLowerCase();
    return p.startsWith('/api/v1/student/') ||
        p.startsWith('/api/v1/progress') || p.startsWith('/api/v1/xp') ||
        p.startsWith('/api/v1/badges') || p.startsWith('/api/v1/schedule') ||
        p.startsWith('/api/v1/chat/') || p.startsWith('/api/v1/eino/chats') ||
        p.startsWith('/api/v1/eino/memory');
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
    if (method != 'GET') {
      return _requestImpl(
        method, path, query: query, body: body, retry: retry,
        cacheTtl: cacheTtl, forceRefresh: forceRefresh,
      );
    }

    final uri = _buildUri(path, query);
    // Scope every GET (not only offline-cacheable paths) to the active student.
    // This prevents a private response cached by one account being reused by another.
    final scopedKey = await _persistentCacheKey(uri.toString());
    final flightKey = '$scopedKey|ttl:${cacheTtl?.inMilliseconds ?? 0}|refresh:$forceRefresh';
    final existing = _inFlightGets[flightKey];
    if (existing != null) {
      _coalescedGetRequests++;
      return existing;
    }

    final request = _requestImpl(
      method, path, query: query, body: body, retry: retry,
      cacheTtl: cacheTtl, forceRefresh: forceRefresh,
    );
    _inFlightGets[flightKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightGets[flightKey], request)) {
        _inFlightGets.remove(flightKey);
      }
    }
  }

  Future<Map<String, dynamic>> _requestImpl(
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
    final persistentCacheKey = method == 'GET'
        ? await _persistentCacheKey(cacheKey)
        : cacheKey;
    final canCache = method == 'GET' && cacheTtl != null;

    // Cache-first for explicitly cacheable GETs: fresh data is returned without
    // a Worker request. Expired entries are refreshed from the server; on a
    // network failure, the existing offline fallback may still serve stale data.
    if (canCache && !forceRefresh) {
      final memory = _publicCache[persistentCacheKey];
      if (memory != null && DateTime.now().isBefore(memory.expiresAt)) {
        _memoryCacheHits++;
        return memory.value;
      }
      if (_offlineCacheAllowed(path)) {
        final saved = await OfflineCache.instance.readEntry(persistentCacheKey, maxStale: _offlineCacheMaxStale);
        if (saved != null && saved.age <= cacheTtl) {
          _persistentCacheHits++;
          final value = saved.value;
          _publicCache[persistentCacheKey] = _CachedResponse(value, saved.savedAt.add(cacheTtl));
          return value;
        }
      }
    }
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final token = await authStorage?.accessToken;
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
      final timeout = _requestTimeout(path);
      if (method == 'GET') _networkGetRequests++;
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
          return await _requestImpl(method, path, query: query, body: body, retry: false, cacheTtl: cacheTtl, forceRefresh: forceRefresh);
        }
      }
      // Receiving any HTTP response proves that the device can reach the
      // server, even when the server returns 4xx/5xx. Clear the offline banner
      // before decoding the payload so server errors never look like offline mode.
      OfflineState.instance.markOnline();
      final decoded = _decoder.decode(response);
      if (canCache) {
        _publicCache[persistentCacheKey] = _CachedResponse(decoded, DateTime.now().add(cacheTtl));
      }
      if (method == 'GET' && _offlineCacheAllowed(path)) {
        final isPersonal = _isPersonalOfflinePath(path);
        if (!isPersonal || persistentCacheKey.startsWith('student:')) {
          await OfflineCache.instance.write(persistentCacheKey, decoded);
        }
      }
      return decoded;
    } on ApiException { rethrow; }
      on TimeoutException catch (e) {
        return _offlineFallbackOrThrow(persistentCacheKey, path, ApiException(ApiErrorMessages.timeout, cause: e, kind: ApiErrorKind.timeout, retryable: true));
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
    if (_offlineCacheAllowed(path) &&
        (!_isPersonalOfflinePath(path) || cacheKey.startsWith('student:'))) {
      final cached = await OfflineCache.instance.read(cacheKey, maxStale: _offlineCacheMaxStale);
      if (cached != null) {
        _offlineFallbackHits++;
        return cached;
      }
    }
    throw error;
  }

  Duration _requestTimeout(String path) {
    final normalized = path.toLowerCase();
    // The Worker gives Eino up to 30s for chat/vision/TTS and up to 60s for
    // OCR/STT. A 20s Flutter timeout would make the app report a failure
    // while the backend is still processing a valid request.
    if (normalized.contains('/eino/ocr') || normalized.contains('/eino/stt') || normalized.contains('/eino/file-analysis')) {
      return const Duration(seconds: 90);
    }
    if (normalized.contains('/eino/chat') ||
        normalized.contains('/eino/vision') ||
        normalized.contains('/eino/tts')) {
      return const Duration(seconds: 45);
    }
    if (normalized.contains('/eino/image')) {
      return const Duration(seconds: 90);
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


class ApiCacheMetrics {
  const ApiCacheMetrics({
    required this.memoryHits,
    required this.persistentHits,
    required this.networkGets,
    required this.coalescedGets,
    required this.offlineFallbackHits,
  });

  final int memoryHits;
  final int persistentHits;
  final int networkGets;
  final int coalescedGets;
  final int offlineFallbackHits;

  int get totalCacheHits => memoryHits + persistentHits + offlineFallbackHits;

  Map<String, int> toMap() => {
        'memoryHits': memoryHits,
        'persistentHits': persistentHits,
        'networkGets': networkGets,
        'coalescedGets': coalescedGets,
        'offlineFallbackHits': offlineFallbackHits,
      };
}
