import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must be top-level for [FirebaseMessaging.onBackgroundMessage].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));

  final type = message.data['type'] as String? ?? '';
  final isTemp = type == 'temp_alert';
  final channelId = isTemp ? 'ice_pos_temp_alarm' : 'ice_pos_alerts';
  final channelName = isTemp ? 'Alarma temperatura' : 'ICE POS';

  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      channelId,
      channelName,
      importance: isTemp ? Importance.max : Importance.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage:
          isTemp ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    ),
  );

  final n = message.notification;
  final title = n?.title ?? (isTemp ? 'Alerta de temperatura' : 'ICE POS');
  final body = n?.body ?? message.data['body'] ?? '';

  await plugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: isTemp ? Importance.max : Importance.high,
        priority: isTemp ? Priority.max : Priority.high,
        category: isTemp ? AndroidNotificationCategory.alarm : null,
        fullScreenIntent: isTemp,
        ongoing: isTemp,
        autoCancel: !isTemp,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage:
            isTemp ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ),
    ),
    payload: message.data['route'] as String? ?? '',
  );
}
