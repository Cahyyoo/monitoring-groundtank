import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/tank_level.dart';
import 'format.dart';

/// System notifications for a full or empty tank.
///
/// Safe to call from the background isolate: [init] is idempotent per isolate
/// and every call swallows a missing plugin, so a test or an unsupported
/// platform never fails because a notification could not be shown.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'tank_alerts',
    'Peringatan ground tank',
    description: 'Muncul saat air di ground tank penuh atau kosong.',
    importance: Importance.high,
  );

  /// One id per kind: a second "full" replaces the first instead of stacking,
  /// and entering one state clears the notification for the other.
  static int _idFor(TankAlertKind kind) => switch (kind) {
    TankAlertKind.full => 1,
    TankAlertKind.empty => 2,
  };

  static const _testId = 99;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_water'),
          // Asked for explicitly in [requestPermission], at a moment the user
          // can connect with what it is for.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Android 13+ and iOS both need consent. Returns whether it was granted.
  static Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  /// Null when the platform cannot say.
  static Future<bool?> areEnabled() async {
    await init();
    try {
      return await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  static Future<void> showAlert(TankAlertKind kind, double percent) async {
    await init();
    if (!_ready) return;
    final other = kind == TankAlertKind.full
        ? TankAlertKind.empty
        : TankAlertKind.full;
    try {
      await _plugin.cancel(id: _idFor(other));
      await _plugin.show(
        id: _idFor(kind),
        title: Format.alertTitle(kind),
        body: Format.alertBody(kind, percent),
        notificationDetails: _details(),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  static Future<void> showTest() async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _testId,
        title: 'Notifikasi uji',
        body: 'Notifikasi GroundTank berfungsi dengan baik.',
        notificationDetails: _details(),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  static NotificationDetails _details() => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF0B63C1),
      category: AndroidNotificationCategory.status,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBanner: true,
    ),
  );
}
