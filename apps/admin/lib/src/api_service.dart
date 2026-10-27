import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';

import 'session_store.dart';

/// API client for the TRINEX backend. The API root includes `/api/v1`.
/// Override it with --dart-define=TRINEX_API_BASE_URL=https://host/api/v1.
class ApiService {
  ApiService({required this.sessionStore, http.Client? client})
      : _client = client ?? http.Client();

  final SessionStore sessionStore;
  final http.Client _client;

  static const _configuredBase = String.fromEnvironment(
    'TRINEX_API_BASE_URL',
    defaultValue:
        'https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1',
  );
  static const _timeout = Duration(seconds: 90);
  Future<AdminSession>? _refreshFuture;

  Uri _uri(String path) {
    final base = _configuredBase.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      decoded = value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      final errorValue = decoded['error'];
      final nestedMessage = errorValue is Map<String, dynamic>
          ? errorValue['message']?.toString()
          : errorValue?.toString();
      final code = errorValue is Map<String, dynamic> ? errorValue['code']?.toString() : null;
      final details = errorValue is Map<String, dynamic> ? errorValue['details']?.toString() : null;
      var message = decoded['message']?.toString() ?? nestedMessage ?? 'تعذّر تنفيذ الطلب (HTTP ${response.statusCode}).';
      if (code != null && code.startsWith('IMPORT_')) { message = '[$code] $message${details != null && details != 'null' && details.isNotEmpty ? '\n$details' : ''}'; }
      throw ApiServiceException(message, statusCode: response.statusCode);
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) { return data; }
    return decoded;
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: requestHeaders).timeout(_timeout);
      case 'POST':
        return _client
            .post(uri, headers: requestHeaders, body: encodedBody ?? '{}')
            .timeout(_timeout);
      case 'PUT':
        return _client
            .put(uri, headers: requestHeaders, body: encodedBody ?? '{}')
            .timeout(_timeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: requestHeaders, body: encodedBody ?? '{}')
            .timeout(_timeout);
      case 'DELETE':
        return _client.delete(uri, headers: requestHeaders).timeout(_timeout);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    var session = authenticated
        ? await sessionStore.readIncludingExpired()
        : null;

    if (authenticated && session == null) {
      throw const ApiServiceException('تسجيل الدخول مطلوب.', statusCode: 401);
    }

    if (authenticated && session!.isExpired) {
      session = await _refreshSession(session);
    }

    final headers = <String, String>{};
    if (authenticated && session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final response = await _send(method, _uri(path), headers: headers, body: body);
    if (authenticated &&
        response.statusCode == 401 &&
        retryAfterRefresh &&
        session?.refreshToken?.isNotEmpty == true) {
      final refreshed = await _refreshSession(session!);
      final retry = await _send(
        method,
        _uri(path),
        headers: {'Authorization': 'Bearer ${refreshed.accessToken}'},
        body: body,
      );
      return _decodeResponse(retry);
    }
    return _decodeResponse(response);
  }

  Future<AdminSession> _refreshSession(AdminSession previous) {
    final refreshToken = previous.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return _clearExpiredSession();
    }

    // Several screens can receive 401/expire at once. Refresh tokens are single-use,
    // so all concurrent callers must await the same rotation instead of racing it.
    final inFlight = _refreshFuture;
    if (inFlight != null) { return inFlight; }

    final future = _performRefresh(previous, refreshToken);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) { _refreshFuture = null; }
    });
  }

  Future<AdminSession> _clearExpiredSession() async {
    await sessionStore.clear();
    throw const ApiServiceException(
      'انتهت الجلسة. سجّل الدخول مجددًا.',
      statusCode: 401,
    );
  }

  Future<AdminSession> _performRefresh(
    AdminSession previous,
    String refreshToken,
  ) async {
    try {
      final response = await _send(
        'POST',
        _uri('/auth/refresh'),
        body: {'refreshToken': refreshToken},
      );
      final data = await _decodeResponse(response);
      final token = data['token']?.toString() ?? '';
      final nextRefreshToken = data['refreshToken']?.toString() ?? '';
      if (token.isEmpty || nextRefreshToken.isEmpty) {
        throw const ApiServiceException('لم يُرجع الخادم بيانات جلسة مكتملة.');
      }
      final expires = int.tryParse(data['expiresInSeconds']?.toString() ?? '') ?? 900;
      final refreshed = AdminSession(
        accessToken: token,
        refreshToken: nextRefreshToken,
        displayName: data['staffDisplayName']?.toString() ?? previous.displayName,
        // Role IDs (e.g. super_admin) are used for permission matching;
        // staffRole is a human-readable label such as 'Super Admin'.
        role: data['staffRoleId']?.toString() ??
            data['role_name']?.toString() ??
            data['staffRole']?.toString() ??
            previous.role,
        expiresAt: DateTime.now().add(Duration(seconds: expires)),
      );
      await sessionStore.save(refreshed);
      return refreshed;
    } catch (_) {
      await sessionStore.clear();
      rethrow;
    }
  }

  Future<AdminSession> login(String userId, String password) async {
    final data = await _request(
      'POST',
      '/auth/staff/login',
      authenticated: false,
      body: {'userId': userId.trim(), 'password': password},
    );
    final token = data['token']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';
    if (token.isEmpty || refreshToken.isEmpty) {
      throw const ApiServiceException('لم يُرجع الخادم رموز جلسة مكتملة.');
    }
    final expires = int.tryParse(data['expiresInSeconds']?.toString() ?? '') ?? 900;
    final session = AdminSession(
      accessToken: token,
      refreshToken: refreshToken,
      displayName: data['staffDisplayName']?.toString() ?? userId.trim(),
      role: data['staffRoleId']?.toString() ??
          data['role_name']?.toString() ??
          data['staffRole']?.toString() ??
          '',
      expiresAt: DateTime.now().add(Duration(seconds: expires)),
    );
    await sessionStore.save(session);
    return session;
  }

  Future<void> logout() async {
    final session = await sessionStore.readIncludingExpired();
    if (session != null) {
      try {
        await _send(
          'POST',
          _uri('/auth/logout'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );
      } catch (_) {
        // Local logout must work even if the server is unreachable.
      }
    }
    await sessionStore.clear();
  }

  /// Upload one JPEG, PNG, or WebP image to the existing protected media endpoint.
  /// The server enforces MIME signature, 3 MB size and storage quota limits.
  Future<Map<String, dynamic>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final allowed = <String>{'image/jpeg', 'image/png', 'image/webp'};
    if (!allowed.contains(contentType.toLowerCase())) {
      throw const ApiServiceException('يسمح فقط بصور JPEG أو PNG أو WebP.');
    }
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      throw const ApiServiceException('حجم الصورة يجب أن يكون بين 1 بايت و3 ميغابايت.');
    }
    var session = await sessionStore.readIncludingExpired();
    if (session == null) {
      throw const ApiServiceException('تسجيل الدخول مطلوب.', statusCode: 401);
    }
    if (session.isExpired) { session = await _refreshSession(session); }
    final request = http.MultipartRequest('POST', _uri('/admin/media'));
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(contentType.toLowerCase()),
    ));
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed).timeout(_timeout);
    if (response.statusCode == 401 && session.refreshToken?.isNotEmpty == true) {
      final refreshed = await _refreshSession(session);
      final retry = http.MultipartRequest('POST', _uri('/admin/media'));
      retry.headers['Accept'] = 'application/json';
      retry.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      retry.files.add(http.MultipartFile.fromBytes(
        'file', bytes, filename: filename,
        contentType: MediaType.parse(contentType.toLowerCase()),
      ));
      return _decodeResponse(await http.Response.fromStream(await retry.send().timeout(_timeout)).timeout(_timeout));
    }
    return _decodeResponse(response);
  }

  /// Sends a temporary image/PDF directly to the dedicated OCR endpoint.
  /// The source is not stored by the application; the caller should release its
  /// byte buffer immediately after this request completes.
  Future<Map<String, dynamic>> uploadImportOcr({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > 100 * 1024 * 1024) {
      throw const ApiServiceException('الملف كبير جدًا. اختر ملفًا أصغر.');
    }
    var session = await sessionStore.readIncludingExpired();
    if (session == null) { throw const ApiServiceException('تسجيل الدخول مطلوب.', statusCode: 401); }
    if (session.isExpired) { session = await _refreshSession(session); }
    Future<http.Response> send(String token) async {
      final request = http.MultipartRequest('POST', _uri('/admin/imports/ocr'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename,
        contentType: MediaType.parse(contentType)));
      return http.Response.fromStream(await request.send().timeout(const Duration(seconds: 120)))
          .timeout(const Duration(seconds: 120));
    }
    var response = await send(session.accessToken);
    if (response.statusCode == 401 && session.refreshToken?.isNotEmpty == true) {
      session = await _refreshSession(session);
      response = await send(session.accessToken);
    }
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, body: body);
  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> getDashboardOverview() =>
      _request('GET', '/admin/dashboard/overview');

  Future<Map<String, dynamic>> getEinoUsage({int hours = 24}) =>
      _request('GET', '/admin/security/eino-usage?hours=${hours.clamp(1, 168)}');

  Future<bool> checkHealth() async {
    try {
      await _request('GET', '/health', authenticated: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ApiServiceException implements Exception {
  const ApiServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
