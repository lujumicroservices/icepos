// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:ice_pos/src/core/services/supabase_service.dart';

class WebPushSubscriptionService {
  const WebPushSubscriptionService();

  static const String _vapidPublicKey =
      String.fromEnvironment('WEB_PUSH_VAPID_PUBLIC_KEY');

  /// Registra push web para la tienda (admin y empleados en navegador).
  Future<void> ensureSubscribed({
    required int storeId,
    String? userId,
  }) async {
    if (!SupabaseService.isInitialized) return;
    if (_vapidPublicKey.isEmpty) return;
    if (html.window.isSecureContext != true) return;
    if (html.Notification.supported != true) return;
    final swContainer = html.window.navigator.serviceWorker;
    if (swContainer == null) return;

    final permission = await _ensurePermission();
    if (permission != 'granted') return;

    final registration =
        await swContainer.register('/push_sw.js', <String, dynamic>{'scope': '/push/'});
    final pushManager = registration.pushManager;
    if (pushManager == null) return;

    dynamic subscription;
    try {
      subscription = await pushManager.getSubscription();
    } catch (_) {}

    if (subscription == null) {
      try {
        subscription = await pushManager.subscribe(
          <String, dynamic>{
            'userVisibleOnly': true,
            'applicationServerKey': _urlBase64ToUint8List(_vapidPublicKey),
          },
        );
      } catch (_) {
        return;
      }
    }
    if (subscription == null) return;
    final json = jsonDecode(jsonEncode(subscription));
    if (json is! Map<String, dynamic>) return;
    final endpoint = json['endpoint'] as String?;
    final keys = json['keys'];
    if (endpoint == null || keys is! Map<String, dynamic>) return;
    final p256dh = keys['p256dh'] as String?;
    final auth = keys['auth'] as String?;
    if (p256dh == null || auth == null) return;

    await SupabaseService.instance.client.from('web_push_subscriptions').upsert({
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'store_id': storeId,
      'user_id': userId,
      'user_agent': html.window.navigator.userAgent,
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'endpoint');
  }

  Future<String> _ensurePermission() async {
    final current = html.Notification.permission ?? 'default';
    if (current == 'granted' || current == 'denied') return current;
    try {
      return await html.Notification.requestPermission();
    } catch (_) {
      return current;
    }
  }

  Uint8List _urlBase64ToUint8List(String base64String) {
    var output = base64String.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        break;
    }
    return Uint8List.fromList(base64Decode(output));
  }
}

