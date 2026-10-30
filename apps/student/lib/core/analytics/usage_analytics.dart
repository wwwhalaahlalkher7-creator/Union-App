import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../constants/app_constants.dart';

/// Sends only allowlisted screen metadata and a random anonymous session token.
/// Never sends account IDs, IP addresses, route parameters, search terms or content.
class UsageAnalytics {
  UsageAnalytics._();

  static const _sessionKey = 'trinex_anon_usage_session_v1';
  static String? _lastPath;
  static bool _sessionStarted = false;

  static const _sections = <String, String>{
    '/home': 'home',
    '/media': 'media',
    '/media/detail': 'media',
    '/materials': 'materials',
    '/schedule': 'schedule',
    '/student': 'student',
    '/tools': 'tools',
    '/recent': 'recent',
    '/notifications': 'notifications',
    '/eino': 'eino',
    '/general-chat': 'chat',
    '/market': 'market',
    '/settings': 'settings',
    '/account-settings': 'settings',
    '/edit-profile': 'settings',
    '/more': 'more',
    '/xp': 'student',
  };

  static Future<void> trackRoute(String path) async {
    final normalized = path.split('?').first;
    if (_lastPath == normalized) return;
    final section = _sections[normalized] ?? _sectionForPrefix(normalized);
    if (section == null) return; // Never track auth, onboarding, or splash routes.
    _lastPath = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      var sessionId = prefs.getString(_sessionKey);
      if (sessionId == null || !RegExp(r'^[a-zA-Z0-9_-]{16,128}$').hasMatch(sessionId)) {
        sessionId = _randomSessionId();
        await prefs.setString(_sessionKey, sessionId);
      }
      if (!_sessionStarted) {
        _sessionStarted = true;
        await _send({
          'sessionId': sessionId,
          'platform': 'app',
          'eventName': 'session_start',
          'section': section,
          'appVersion': AppVersion.full,
        });
      }
      await _send({
        'sessionId': sessionId,
        'platform': 'app',
        'eventName': 'screen_view',
        'section': section,
        'appVersion': AppVersion.full,
      });
    } catch (_) {
      // Analytics is best-effort and must never interrupt app navigation.
    }
  }


  static Future<void> _send(Map<String, String> payload) async {
    final base = AppConstants.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/v1/usage/events');
    await http.post(uri,
      headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 4));
  }

  static String? _sectionForPrefix(String path) {
    if (path.startsWith('/student/profile/')) return 'student';
    return null;
  }

  static String _randomSessionId() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    return List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
