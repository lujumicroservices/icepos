import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/realtime_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/utils/error_logger.dart';
import 'package:ice_pos/src/core/utils/logger.dart';
import 'package:ice_pos/src/core/auth/auth_gate.dart';
import 'package:ice_pos/src/features/home/presentation/home_screen.dart';
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
    };

    await _runApp();
  }, (Object error, StackTrace stackTrace) {
    logErrorToConsole(error, stackTrace);
  });
}

Future<void> _runApp() async {

  await dotenv.load(fileName: '.env');

  try {
    await SupabaseService.initialize();
    if (SupabaseService.isInitialized && SupabaseService.debugHost != null) {
      debugPrint('Supabase: host=${SupabaseService.debugHost} (mismo que en ice_pos/.env)');
    }
  } catch (_) {
    // App works offline without Supabase
  }

  final database = AppDatabase();
  // No automatic seed: with cloud enabled, data is synced at startup and kept in sync via Realtime; otherwise use "Cargar menú desde JSON" in drawer.

  if (CloudSyncService.isEnabled) {
    try {
      final err = await CloudSyncService.syncFromCloud(database);
      if (err != null) {
        debugPrint('Cloud sync al arranque: $err');
        await CloudSyncService.setStartupSyncError(err);
      }
    } catch (e) {
      debugPrint('Cloud sync al arranque (excepción): $e');
      CloudSyncService.lastSyncError = e.toString();
      await CloudSyncService.setStartupSyncError(e.toString());
    }
  }

  runApp(
    ProviderScope(
      observers: [RiverpodLogger()],
      overrides: [
        appDatabaseProvider.overrideWith((_) => database),
      ],
      child: AuthGate(child: const _AppWithPrinterRestore()),
    ),
  );
}

/// Ensures Realtime sync is started once when the app has ref (so we can invalidate providers on sync).
final _realtimeSyncInitProvider = Provider<void>((ref) {
  if (!CloudSyncService.isEnabled) return;
  final db = ref.read(appDatabaseProvider);
  void onSyncDone() {
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
  }
  RealtimeSyncService.start(db, onSyncDone);
});

/// Wrapper that restores the saved printer selection once the app has started.
class _AppWithPrinterRestore extends ConsumerStatefulWidget {
  const _AppWithPrinterRestore();

  @override
  ConsumerState<_AppWithPrinterRestore> createState() => _AppWithPrinterRestoreState();
}

class _AppWithPrinterRestoreState extends ConsumerState<_AppWithPrinterRestore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiptPrinterProvider.notifier).loadBondedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.read(_realtimeSyncInitProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'ICE POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
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
      home: const HomeScreen(),
    );
  }
}