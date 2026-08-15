import 'package:synchronized/synchronized.dart';

/// One lock for catalog refresh ([CloudSyncService.syncFromCloud]) and outbox replay
/// so SQLite + PostgREST operations do not overlap.
class SyncCoordinator {
  SyncCoordinator._();

  static final Lock _lock = Lock();

  static Future<T> synchronized<T>(Future<T> Function() fn) =>
      _lock.synchronized(fn);
}
