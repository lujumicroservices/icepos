import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/connectivity_provider.dart';
import 'package:ice_pos/src/core/services/operation_log_level.dart';
import 'package:ice_pos/src/core/services/operation_log_sink.dart';
import 'package:ice_pos/src/core/services/outbox_sync_service.dart';
import 'package:ice_pos/src/core/services/pending_cashier_approvals_cloud_service.dart';
import 'package:ice_pos/src/core/services/realtime_sync_service.dart';
import 'package:ice_pos/src/core/services/remote_update_bootstrap.dart';
import 'package:ice_pos/src/core/services/fcm_push_service.dart';
import 'package:ice_pos/src/core/services/staff_tasks_notification_bootstrap.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/setup/presentation/supabase_bootstrap.dart';
import 'package:ice_pos/src/core/utils/error_logger.dart';
import 'package:ice_pos/src/core/utils/logger.dart';
import 'package:ice_pos/src/core/platform/data_backend.dart';
import 'package:ice_pos/src/core/auth/auth_gate.dart';
import 'package:ice_pos/src/features/home/presentation/home_screen.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/receipt_printer_controller.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';

void main() {
  // runApp must run in the same zone as ensureInitialized to avoid "Zone mismatch".
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Ensure errors are always printed to the terminal so you can copy them.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logErrorToConsole(details.exception, details.stack);
      unawaited(OperationLogSink.report(
        level: 'error',
        operation: 'flutter_error',
        message: details.exceptionAsString(),
        context: {
          if (details.library != null) 'library': details.library!,
        },
        stackTrace: details.stack,
      ));
    };

    await _runApp();
  }, (Object error, StackTrace stackTrace) {
    logErrorToConsole(error, stackTrace);
    unawaited(OperationLogSink.report(
      level: 'error',
      operation: 'unhandled_async',
      message: error.toString(),
      stackTrace: stackTrace,
    ));
  });
}

Future<void> _runApp() async {

  // Sin .env en assets (recomendado en producción), esto falla en silencio; Supabase usa el asistente.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // ignore: evita incluir credenciales en el APK/AAB.
  }

  try {
    await SupabaseService.initialize();
    if (SupabaseService.isInitialized && SupabaseService.debugHost != null) {
      debugPrint(
        'Supabase: host=${SupabaseService.debugHost} (.env o credenciales guardadas)',
      );
    }
  } catch (_) {
    // App works offline without Supabase
  }

  await ConnectivityService.instance.init();

  if (!kIsWeb) {
    await FcmPushService.instance.initialize();
  }

  // Web: no Drift/SQLite — admin reads/writes go to Supabase only. Native: local DB + sync.
  final AppDatabase? database = isSupabaseOnlyBackend ? null : AppDatabase();
  OperationLogSink.register(database);
  // No automatic seed: with cloud enabled, catalog sync runs after first frame (see _runColdStartCatalogSyncIfNeeded); otherwise use "Cargar menú desde JSON" in drawer.

  if (database != null && CloudSyncService.isEnabled) {
    unawaited(OutboxSyncService.drain(database));
  }

  runApp(
    ProviderScope(
      observers: [RiverpodLogger()],
      overrides: [
        appDatabaseProvider.overrideWith((_) => database),
      ],
      child: SupabaseBootstrap(
        database: database,
        child: AuthGate(child: const _AppWithPrinterRestore()),
      ),
    ),
  );
}

/// Full catalog sync after first frame so [runApp] is not blocked; sets [catalogInitialSyncCompletedProvider] on success.
Future<void> _runColdStartCatalogSyncIfNeeded(WidgetRef ref) async {
  final db = ref.read(appDatabaseProvider);
  if (db == null ||
      !CloudSyncService.isEnabled ||
      !ConnectivityService.instance.isConnected) {
    return;
  }
  try {
    final err = await CloudSyncService.syncFromCloud(db);
    if (err != null) {
      debugPrint('Cloud sync al arranque: $err');
      await CloudSyncService.setStartupSyncError(err);
      CloudSyncService.lastSyncError = err;
      await OperationLogSink.report(
        level: OperationLogLevel.critical,
        operation: 'sync_from_cloud_startup',
        message: err,
      );
    } else {
      ref.read(catalogInitialSyncCompletedProvider.notifier).state = true;
    }
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
  } catch (e, st) {
    debugPrint('Cloud sync al arranque (excepción): $e');
    CloudSyncService.lastSyncError = e.toString();
    await CloudSyncService.setStartupSyncError(e.toString());
    await OperationLogSink.report(
      level: OperationLogLevel.critical,
      operation: 'sync_from_cloud_startup',
      message: e.toString(),
      stackTrace: st,
    );
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
  }
}

/// Ensures Realtime sync is started once when the app has ref (so we can invalidate providers on sync).
final _realtimeSyncInitProvider = Provider<void>((ref) {
  if (!CloudSyncService.isEnabled) return;
  final db = ref.read(appDatabaseProvider);
  if (db == null) return;
  void onSyncDone() {
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
  }
  RealtimeSyncService.start(db, onSyncDone);
});

/// Cuando un admin resuelve una solicitud en web, la caja aplica cierre local o limpia la cola.
final _pendingApprovalsCloudBridgeProvider = Provider<void>((ref) {
  if (!CloudSyncService.isEnabled) return;
  final db = ref.watch(appDatabaseProvider);
  final pos = ref.watch(posRepositoryProvider);
  if (db == null || pos == null) return;
  PendingCashierApprovalsCloudService.startDeviceListener(
    db: db,
    onResolution: ({
      required String cloudId,
      required String status,
      String? kind,
      Map<String, dynamic>? payload,
    }) => pos.applyCloudResolutionForPending(
      cloudId: cloudId,
      status: status,
      kind: kind,
      cloudPayload: payload,
    ),
    onSyncDone: () =>
        ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1),
  );
  ref.onDispose(() {
    unawaited(PendingCashierApprovalsCloudService.stopDeviceListener());
  });
});

/// Replays pending sales/movements when connectivity returns; refreshes stale catalog cache.
final _outboxConnectivityBridgeProvider = Provider<void>((ref) {
  ref.listen(connectivityStreamProvider, (prev, next) {
    next.whenData((online) async {
      if (!online) return;
      final db = ref.read(appDatabaseProvider);
      if (db == null || !CloudSyncService.isEnabled) return;
      await OutboxSyncService.drain(db);
      await RealtimeSyncService.restart();
      await RealtimeSyncService.pullCatalogNow(reason: 'connectivity');
      ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
    });
  });
});

/// Wrapper that restores the saved printer selection once the app has started.
class _AppWithPrinterRestore extends ConsumerStatefulWidget {
  const _AppWithPrinterRestore();

  @override
  ConsumerState<_AppWithPrinterRestore> createState() => _AppWithPrinterRestoreState();
}

class _AppWithPrinterRestoreState extends ConsumerState<_AppWithPrinterRestore>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb) {
        ref.read(receiptPrinterProvider.notifier).loadBondedDevices();
      }
      unawaited(_runColdStartCatalogSyncIfNeeded(ref));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      final db = ref.read(appDatabaseProvider);
      if (db != null && CloudSyncService.isEnabled) {
        unawaited(() async {
          // Realtime sockets often die in background; resubscribe + pull catalog
          // so web product/bundle edits appear on tablets without a manual sync.
          await RealtimeSyncService.restart();
          await OutboxSyncService.drain(db);
          await RealtimeSyncService.pullCatalogNow(reason: 'app_resume');
          if (mounted) {
            ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
          }
        }());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.read(_realtimeSyncInitProvider);
    ref.read(_pendingApprovalsCloudBridgeProvider);
    ref.read(_outboxConnectivityBridgeProvider);
    final locale = ref.watch(localeProvider);
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);
    return MaterialApp(
      title: 'ICE POS',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          elevation: 4,
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            );
          }),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          showUnselectedLabels: true,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
        ),
      ),
      locale: locale,
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RemoteUpdateBootstrap(
        child: StaffTasksNotificationBootstrap(child: HomeScreen()),
      ),
    );
  }
}