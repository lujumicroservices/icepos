import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';

/// Cloud-first catalog: Supabase is the online source of truth; Drift holds a snapshot.
///
/// Call [fetchAndApplySnapshot] (or [CloudSyncService.syncFromCloud]) to refresh the local cache.
class CatalogRemoteDataSource {
  CatalogRemoteDataSource._();

  /// Fetches master catalog from Supabase and replaces matching Drift tables.
  static Future<String?> fetchAndApplySnapshot(AppDatabase db) =>
      CloudSyncService.applyCloudCatalogToLocalCache(db);

  /// Triggers a background full snapshot pull when the cache is older than [maxAge].
  static Future<void> refreshIfStale(
    AppDatabase db, {
    Duration maxAge = const Duration(minutes: 5),
  }) =>
      CloudSyncService.refreshCatalogCacheIfStale(db, maxAge: maxAge);
}
