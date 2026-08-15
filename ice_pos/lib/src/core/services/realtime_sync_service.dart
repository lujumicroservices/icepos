import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

/// Listens to Supabase Realtime on [CloudSyncService.supabaseCatalogTableNames] only,
/// debounces, then runs a full [CloudSyncService.syncFromCloud] (catalog snapshot into Drift).
/// Intentional scope: bootstrap, manual drawer sync, and this channel — not transactional outbox
/// ([OutboxSyncService]). Other tables have their own listeners or push paths.
/// Start after [SupabaseService] and [AppDatabase] are available.
class RealtimeSyncService {
  RealtimeSyncService._();

  static RealtimeChannel? _channel;
  static Timer? _debounceTimer;
  static Timer? _pollTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 2500);
  /// Safety net when Realtime WebSocket drops (common on tablets left open / backgrounded).
  static const Duration _pollInterval = Duration(minutes: 2);
  static AppDatabase? _db;
  static void Function()? _onSyncDone;
  static bool _syncInFlight = false;

  static bool get isSubscribed => _channel != null;

  /// Starts listening to postgres changes on master tables. Call once when app has [db] and
  /// [onSyncDone] (e.g. from a Riverpod provider that has [Ref] to invalidate [posCategoriesRefreshProvider]).
  static void start(AppDatabase db, void Function() onSyncDone) {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    _db = db;
    _onSyncDone = onSyncDone;
    if (_channel != null) return;
    _subscribe();
    _startPollTimer();
  }

  /// Tears down and re-subscribes (e.g. after app resume when the socket may be dead).
  static Future<void> restart() async {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    final db = _db;
    final onDone = _onSyncDone;
    if (db == null || onDone == null) return;
    await _unsubscribeChannelOnly();
    _db = db;
    _onSyncDone = onDone;
    _subscribe();
    _startPollTimer();
  }

  static void _subscribe() {
    if (_channel != null) return;
    if (_db == null) return;
    try {
      var channel = SupabaseService.instance.client.channel('pos-master-sync');
      for (final table in CloudSyncService.supabaseCatalogTableNames) {
        channel = channel.onPostgresChanges(
          schema: 'public',
          table: table,
          event: PostgresChangeEvent.all,
          callback: _onPostgresChange,
        );
      }
      _channel = channel.subscribe((status, [err]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('RealtimeSyncService: subscribed to catalog postgres changes');
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('RealtimeSyncService: channel status=$status $err');
        }
      });
    } catch (e) {
      debugPrint('RealtimeSyncService.start: $e');
    }
  }

  static void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(pullCatalogNow(reason: 'poll'));
    });
  }

  static void _onPostgresChange(PostgresChangePayload payload) {
    if (!CloudSyncService.supabaseCatalogTableNames.contains(payload.table)) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      _debounceTimer = null;
      await pullCatalogNow(reason: 'realtime:${payload.table}');
    });
  }

  /// Pulls catalog from Supabase into Drift and notifies UI. Safe to call from resume / poll.
  static Future<void> pullCatalogNow({String reason = 'manual'}) async {
    final db = _db;
    if (db == null) return;
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    if (!ConnectivityService.instance.isConnected) return;
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final err = await CloudSyncService.syncFromCloud(db);
      if (err != null) {
        debugPrint('RealtimeSyncService pull ($reason): $err');
      } else {
        debugPrint('RealtimeSyncService pull ok ($reason)');
      }
      _onSyncDone?.call();
    } catch (e) {
      debugPrint('RealtimeSyncService pull error ($reason): $e');
    } finally {
      _syncInFlight = false;
    }
  }

  static Future<void> _unsubscribeChannelOnly() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_channel != null) {
      try {
        await SupabaseService.instance.client.removeChannel(_channel!);
      } catch (e) {
        debugPrint('RealtimeSyncService unsubscribe: $e');
      }
      _channel = null;
    }
  }

  /// Stops the subscription (e.g. on logout). Safe to call if not started.
  static Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _unsubscribeChannelOnly();
    _db = null;
    _onSyncDone = null;
  }
}
