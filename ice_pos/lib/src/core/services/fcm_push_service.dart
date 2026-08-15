import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ice_pos/firebase_options.dart';
import 'package:ice_pos/src/core/config/store_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ice_pos/src/core/services/device_id_service.dart';
import 'package:ice_pos/src/core/services/fcm_background_handler.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Registra token FCM en Supabase y muestra notificaciones en primer plano.
class FcmPushService {
  FcmPushService._();
  static final FcmPushService instance = FcmPushService._();

  static const String _channelId = 'ice_pos_alerts';
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(String route)? onOpenRoute;

  bool get isAvailable =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && DefaultFirebaseOptions.isConfigured;

  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (details) {
          final route = details.payload;
          if (route != null && route.isNotEmpty) {
            onOpenRoute?.call(route);
          }
        },
      );

      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _channelId,
                'ICE POS',
                description: 'Tareas, aprobaciones y avisos',
                importance: Importance.high,
              ),
            );
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          debugPrint('FcmPushService: notification permission not granted');
        }
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromNotification);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleMessageRoute(initial);

      FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerTokenForCurrentUser());

      _initialized = true;
      debugPrint('FcmPushService: initialized');
    } catch (e, st) {
      debugPrint('FcmPushService.initialize: $e');
      debugPrint('$st');
    }
  }

  Future<void> registerTokenForCurrentUser() async {
    if (!_initialized || !SupabaseService.isInitialized) return;
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final storeId = await StoreScope.getActiveStoreId();
      final device = await DeviceIdService.getDeviceInfo();
      String? userId = SupabaseService.instance.client.auth.currentUser?.id;
      if (userId == null) {
        final prefs = await SharedPreferences.getInstance();
        final local = prefs.getString('auth_user_id');
        if (local != null && local.isNotEmpty) {
          userId = 'local:$local';
        }
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      await SupabaseService.instance.client.from('fcm_device_tokens').upsert(
        {
          'token': fcmToken,
          'store_id': storeId,
          'device_id': device.deviceId,
          'user_id': userId,
          'platform': platform,
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
      debugPrint('FcmPushService: token registered for store $storeId');
    } catch (e, st) {
      debugPrint('FcmPushService.registerToken: $e');
      debugPrint('$st');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final route = message.data['route'] as String? ?? '';
    unawaited(
      _local.show(
        message.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'ICE POS',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: route,
      ),
    );
  }

  void _onOpenedFromNotification(RemoteMessage message) {
    _handleMessageRoute(message);
  }

  void _handleMessageRoute(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      onOpenRoute?.call(route);
    }
  }
}
