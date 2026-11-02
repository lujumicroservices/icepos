import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Insistent admin temperature alarm: max-importance channel + repeating local notification
/// until [stop] (dismiss). Works without a custom audio asset.
class TemperatureAlarmService {
  TemperatureAlarmService._();
  static final TemperatureAlarmService instance = TemperatureAlarmService._();

  static const String channelId = 'ice_pos_temp_alarm';
  static const int _notifId = 71001;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  Timer? _insistTimer;
  bool _active = false;
  String _title = 'Alerta de temperatura';
  String _body = '';

  bool get isActive => _active;

  Future<void> ensureChannel() async {
    if (kIsWeb) return;
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'Alarma temperatura',
            description: 'Alertas críticas de congelador — volumen alto',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            // Bypass DND where the OEM allows alarm-category channels.
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
  }

  Future<void> start({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    _title = title;
    _body = body;
    await ensureChannel();
    _active = true;
    await _showOnce();
    _insistTimer?.cancel();
    _insistTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_active) return;
      unawaited(_showOnce());
    });
  }

  Future<void> stop() async {
    _active = false;
    _insistTimer?.cancel();
    _insistTimer = null;
    await _local.cancel(_notifId);
  }

  Future<void> _showOnce() async {
    try {
      await _local.show(
        _notifId,
        _title,
        _body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Alarma temperatura',
            channelDescription: 'Alertas críticas de congelador',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        ),
        payload: 'temperature_history',
      );
    } catch (e, st) {
      debugPrint('TemperatureAlarmService._showOnce: $e\n$st');
    }
  }
}
