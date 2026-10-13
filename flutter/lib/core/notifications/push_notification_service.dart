import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../di/app_dependencies.dart';

/// FCM bootstrap. Firebase config is supplied by Firebase Console.
/// Missing config is handled safely so the app still runs during setup.
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _lifecycleObserverRegistered = false;
  final StreamController<void> _notificationArrived =
      StreamController<void>.broadcast();
  Stream<void> get notificationArrived => _notificationArrived.stream;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'association_notifications_v2', 'إشعارات الرابطة',
    description: 'إشعارات الأخبار والتنبيهات الجامعية',
    importance: Importance.max,
  );

  Future<void> initializeAtFirstLaunch() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _local.initialize(init);
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
      _initialized = true;
      final messaging = FirebaseMessaging.instance;
      // Ask only when the OS has not recorded a choice yet; do not nag after an explicit denial.
      final permission = await messaging.getNotificationSettings();
      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
      }
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      messaging.onTokenRefresh.listen((_) => registerCurrentDevice());
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpenedMessage(initial);
      // Remove notifications owned by this app when it is launched. This only
      // clears the Android notification tray; it does not delete app history.
      await _clearAppNotifications();
      await registerCurrentDevice();
    } catch (e) {
      debugPrint('FCM is not configured yet: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      // Also clear app notifications when returning from the background.
      unawaited(_clearAppNotifications());
    }
  }

  Future<void> _clearAppNotifications() async {
    try {
      await _local.cancelAll();
    } catch (e) {
      debugPrint('Unable to clear app notifications: $e');
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!_initialized) return;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await AppDependencies.instance.apiClient.postJson('/api/v1/student/notifications/device', body: {
        'token': token, 'platform': 'android', 'appVersion': '2.0.2',
      });
    } catch (e) {
      // Login may not have completed; login screen calls this again after saving session.
      debugPrint('FCM device registration deferred: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    _notificationArrived.add(null);
    await _local.show(
      message.hashCode,
      notification.title ?? 'إشعار جديد',
      notification.body ?? '',
      NotificationDetails(android: AndroidNotificationDetails(
        _channel.id, _channel.name, channelDescription: _channel.description,
        importance: Importance.max, priority: Priority.max, icon: 'ic_stat_notification',
      )),
      payload: message.data['announcementId']?.toString(),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    // Opening a push deliberately does not navigate or mutate the announcement.
  }
}
