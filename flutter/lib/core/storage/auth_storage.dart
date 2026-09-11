import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage(this._prefs);
  final SharedPreferences _prefs;
  static const _access = 'auth_access_token';
  static const _refresh = 'auth_refresh_token';
  static const _profile = 'auth_student_profile';

  String? get accessToken => _prefs.getString(_access);
  String? get refreshToken => _prefs.getString(_refresh);
  bool get isLoggedIn => accessToken?.isNotEmpty == true;

  Map<String, dynamic>? get profile {
    final raw = _prefs.getString(_profile);
    if (raw == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) { return null; }
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (token?.isNotEmpty == true) await _prefs.setString(_access, token!);
    if (refresh?.isNotEmpty == true) await _prefs.setString(_refresh, refresh!);
    final profile = <String, dynamic>{
      'studentId': data['studentId'], 'studentNumber': data['studentNumber'],
      'fullName': data['fullName'], 'departmentId': data['departmentId'],
    };
    await _prefs.setString(_profile, jsonEncode(profile));
  }

  Future<void> saveRefreshedSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (token?.isNotEmpty == true) await _prefs.setString(_access, token!);
    if (refresh?.isNotEmpty == true) await _prefs.setString(_refresh, refresh!);
  }

  Future<void> clear() async {
    await _prefs.remove(_access); await _prefs.remove(_refresh); await _prefs.remove(_profile);
  }
}
