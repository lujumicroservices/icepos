import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

/// Listens to Supabase Realtime Postgres changes and runs [CloudSyncService.syncFromCloud],
/// then invokes [onSyncDone] so the UI can invalidate providers (e.g. [posCategoriesRefreshProvider]).
/// Start after [SupabaseService] and [AppDatabase] are available.
class RealtimeSyncService {
  RealtimeSyncService._();

  static RealtimeChannel? _channel;
  static Timer? _debounceTimer;
  static Timer? _periodicTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 1500);
  static const Duration _periodicInterval = Duration(seconds: 50);
  static const Duration _periodicSkipIfRealtimeWithin = Duration(seconds: 30);
  static DateTime? _lastSyncFromRealtime;
  static AppDatabase? _db;
  static void Function()? _onSyncDone;

  static bool get isSubscribed => _channel != null;

  /// Starts listening to postgres changes on master tables. Call once when app has [db] and
  /// [onSyncDone] (e.g. from a Riverpod provider that has [Ref] to invalidate [posCategoriesRefreshProvider]).
  static void start(AppDatabase db, void Function() onSyncDone) {
    if (!CloudSyncService.isEnabled || !SupabaseService.isInitialized) return;
    if (_channel != null) return; // already started

    _db = db;
    _onSyncDone = onSyncDone;

    try {
      _channel = SupabaseService.instance.client
          .channel('pos-master-sync')
          .onPostgresChanges(
            schema: 'public',
            event: PostgresChangeEvent.all,
            callback: _onPostgresChange,
          )
          .subscribe((status, [err]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('RealtimeSyncService: subscribed to postgres changes');
        } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
          debugPrint('RealtimeSyncService: channel status=$status $err');
        }
      });
      _startPeriodicSync();
    } catch (e) {
      debugPrint('RealtimeSyncService.start: $e');
    }
  }

  static void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicInterval, (_) async {
      final db = _db;
      if (db == null) return;
      final last = _lastSyncFromRealtime;
      if (last != null && DateTime.now().difference(last) < _periodicSkipIfRealtimeWithin) return;
      try {
        final err = await CloudSyncService.syncFromCloud(db);
        if (err != null) debugPrint('RealtimeSyncService periodic sync: $err');
        _onSyncDone?.call();
      } catch (e) {
        debugPrint('RealtimeSyncService periodic sync error: $e');
      }
    });
  }

  static void _onPostgresChange(PostgresChangePayload payload) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      _debounceTimer = null;
      final db = _db;
      if (db == null) return;
      try {
        final err = await CloudSyncService.syncFromCloud(db);
        _lastSyncFromRealtime = DateTime.now();
        if (err != null) debugPrint('RealtimeSyncService sync after change: $err');
        _onSyncDone?.call();
      } catch (e) {
        debugPrint('RealtimeSyncService sync error: $e');
      }
    });
  }

  /// Stops the subscription (e.g. on logout). Safe to call if not started.
  static Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    if (_channel != null) {
      await SupabaseService.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _db = null;
    _onSyncDone = null;
    _lastSyncFromRealtime = null;
  }
}
