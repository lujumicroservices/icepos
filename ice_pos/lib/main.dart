import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/utils/logger.dart';
import 'package:ice_pos/src/features/home/presentation/home_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/receipt_printer_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  try {
    await SupabaseService.initialize();
  } catch (_) {
    // App works offline without Supabase
  }

  final database = AppDatabase();
  // No automatic seed: data is loaded on demand via "Sincronizar" (cloud) or "Cargar menú desde JSON" (drawer).

  if (CloudSyncService.isEnabled) {
    try {
      final rows = await SupabaseService.instance.client.from('categories').select('id').limit(1);
      if ((rows as List).isNotEmpty) {
        final err = await CloudSyncService.syncFromCloud(database);
        if (err != null) debugPrint('Cloud sync warning: $err');
      }
    } catch (e) {
      debugPrint('Cloud sync skipped: $e');
    }
  }

  runApp(
    ProviderScope(
      observers: [RiverpodLogger()],
      overrides: [
        appDatabaseProvider.overrideWith((_) => database),
      ],
      child: const _AppWithPrinterRestore(),
    ),
  );
}

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