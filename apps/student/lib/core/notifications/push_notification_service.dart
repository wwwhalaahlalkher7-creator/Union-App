import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../app_version.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../storage/auth_storage.dart';

/// Best-effort FCM registration lifecycle.
///
/// Firebase project values are supplied through --dart-define. When they are
/// absent, push is disabled without affecting login or normal app startup.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _apiKey = String.fromEnvironment('TRINEX_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('TRINEX_FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('TRINEX_FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('TRINEX_FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment('TRINEX_FIREBASE_STORAGE_BUCKET');

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  bool _initializing = false;
  bool _initialized = false;
  String? _registeredToken;
  AuthStorage? _storage;

  bool get isConfigured => _apiKey.isNotEmpty && _appId.isNotEmpty &&
      _senderId.isNotEmpty && _projectId.isNotEmpty;

  Future<void> initializeForCurrentSession() async {
    if (_initializing || !isConfigured) return;
    _initializing = true;
    try {
      final storage = await AuthStorage.create();
      if (!await storage.isLoggedIn) return;
      _storage = storage;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        ));
      }
      if (!_initialized) {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        _tokenSubscription = messaging.onTokenRefresh.listen((token) {
          unawaited(_registerToken(token));
        }, onError: (_) {});
        // FCM displays notification payloads automatically while backgrounded.
        // Foreground messages are consumed here so the stream is subscribed;
        // in-app notification history remains the canonical source in TRINEX.
        _foregroundSubscription = FirebaseMessaging.onMessage.listen((_) {});
        _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((_) {});
        _initialized = true;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (_) {
      // Notifications are optional; never make app startup/login fail because
      // Firebase project setup or network permission is not ready yet.
    } finally {
      _initializing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    final storage = _storage;
    if (storage == null || token.isEmpty || !await storage.isLoggedIn) return;
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);
    try {
      await client.postJson('/api/v1/student/notifications/device', body: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'web'),
        'appVersion': AppVersion.full,
      });
      _registeredToken = token;
    } catch (_) {
      // A later app start or token refresh will retry registration.
    } finally {
      client.dispose();
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final storage = _storage ?? await AuthStorage.create();
    String? token = _registeredToken;
    if (token == null && isConfigured && Firebase.apps.isNotEmpty) {
      try { token = await FirebaseMessaging.instance.getToken(); } catch (_) {}
    }
    if (token != null && token.isNotEmpty && await storage.isLoggedIn) {
      final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);
      try {
        await client.deleteJson('/api/v1/student/notifications/device', body: {'token': token});
      } catch (_) {} finally { client.dispose(); }
    }
    _registeredToken = null;
    _storage = null;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenSubscription = null;
    _openedSubscription = null;
    _foregroundSubscription = null;
    _initialized = false;
  }
}
