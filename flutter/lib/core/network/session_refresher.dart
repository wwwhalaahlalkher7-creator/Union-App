import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/auth_storage.dart';

class SessionRefresher {
  SessionRefresher({required this.client, required this.storage, required this.uri});

  final http.Client client;
  final AuthStorage? storage;
  final Uri uri;
  Future<bool>? _inFlight;

  Future<bool> refresh() async {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _perform();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<bool> _perform() async {
    final refreshToken = await storage?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await client.post(
        uri,
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
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
    } catch (_) {
      // Refresh failure is intentionally treated as an expired session.
    }
    await storage?.clear();
    return false;
  }
}
