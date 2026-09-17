import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure persistence for authentication state.
///
/// Access/refresh tokens and the cached student profile are kept in the
/// platform secure storage. A one-time migration moves legacy values from
/// SharedPreferences and removes the old copies.
class AuthStorage {
  AuthStorage._(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  static const _access = 'auth_access_token';
  static const _refresh = 'auth_refresh_token';
  static const _profile = 'auth_student_profile';

  static Future<AuthStorage> create() async {
    const secure = FlutterSecureStorage();
    final storage = AuthStorage._(secure);
    await storage._migrateLegacyPreferences();
    return storage;
  }

  Future<String?> get accessToken async => _secureStorage.read(key: _access);

  Future<String?> get refreshToken async => _secureStorage.read(key: _refresh);

  Future<bool> get isLoggedIn async {
    final token = await accessToken;
    return token?.isNotEmpty == true;
  }

  Future<Map<String, dynamic>?> get profile async {
    final raw = await _secureStorage.read(key: _profile);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> get studentName async {
    final p = await profile;
    return p?['fullName']?.toString() ?? p?['name']?.toString();
  }

  Future<String?> get studentNumber async {
    final p = await profile;
    return p?['studentNumber']?.toString();
  }

  Future<String?> get departmentName async {
    final p = await profile;
    return p?['departmentName']?.toString();
  }

  Future<String?> get semesterName async {
    final p = await profile;
    return p?['semesterName']?.toString();
  }

  Future<String?> get currentSemesterId async {
    final p = await profile;
    return p?['currentSemesterId']?.toString() ?? p?['semesterId']?.toString();
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (token?.isNotEmpty == true) {
      await _secureStorage.write(key: _access, value: token);
    }
    if (refresh?.isNotEmpty == true) {
      await _secureStorage.write(key: _refresh, value: refresh);
    }

    final profile = <String, dynamic>{
      'studentId': data['studentId'],
      'studentNumber': data['studentNumber'],
      'fullName': data['fullName'],
      'departmentId': data['departmentId'],
      'departmentName': data['departmentName'],
      'currentSemesterId': data['currentSemesterId'] ?? data['semesterId'],
      'semesterName': data['semesterName'],
      'email': data['email'],
    };
    await _secureStorage.write(key: _profile, value: jsonEncode(profile));
  }

  Future<void> updateCachedSemester({required String semesterId, required String semesterName}) async {
    final current = await profile ?? <String, dynamic>{};
    current['currentSemesterId'] = semesterId;
    current['semesterName'] = semesterName;
    await _secureStorage.write(key: _profile, value: jsonEncode(current));
  }

  Future<void> saveRefreshedSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (token?.isNotEmpty == true) {
      await _secureStorage.write(key: _access, value: token);
    }
    if (refresh?.isNotEmpty == true) {
      await _secureStorage.write(key: _refresh, value: refresh);
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _secureStorage.delete(key: _access),
      _secureStorage.delete(key: _refresh),
      _secureStorage.delete(key: _profile),
    ]);
  }

  Future<void> _migrateLegacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyAccess = prefs.getString(_access);
    final legacyRefresh = prefs.getString(_refresh);
    final legacyProfile = prefs.getString(_profile);

    if (legacyAccess?.isNotEmpty == true) {
      await _secureStorage.write(key: _access, value: legacyAccess);
    }
    if (legacyRefresh?.isNotEmpty == true) {
      await _secureStorage.write(key: _refresh, value: legacyRefresh);
    }
    if (legacyProfile?.isNotEmpty == true) {
      await _secureStorage.write(key: _profile, value: legacyProfile);
    }

    if (legacyAccess != null || legacyRefresh != null || legacyProfile != null) {
      await prefs.remove(_access);
      await prefs.remove(_refresh);
      await prefs.remove(_profile);
    }
  }
}
