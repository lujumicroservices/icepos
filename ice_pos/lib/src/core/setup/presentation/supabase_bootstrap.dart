import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/setup/supabase_config_store.dart';
import 'package:ice_pos/src/core/setup/presentation/setup_supabase_screen.dart';

/// Si no hay Supabase configurado (.env ni preferencias) y el usuario no eligió
/// "sin nube", muestra el asistente de conexión antes del resto de la app.
class SupabaseBootstrap extends ConsumerStatefulWidget {
  const SupabaseBootstrap({
    super.key,
    required this.database,
    required this.child,
  });

  final AppDatabase database;
  final Widget child;

  @override
  ConsumerState<SupabaseBootstrap> createState() => _SupabaseBootstrapState();
}

enum _SetupPhase { loading, wizard, done }

class _SupabaseBootstrapState extends ConsumerState<SupabaseBootstrap> {
  _SetupPhase _phase = _SetupPhase.loading;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final skipped = await SupabaseConfigStore.isSetupSkipped();
    if (!mounted) return;
    if (SupabaseService.isInitialized || skipped) {
      setState(() => _phase = _SetupPhase.done);
      return;
    }
    setState(() => _phase = _SetupPhase.wizard);
  }

  void _onSetupFinished() {
    setState(() => _phase = _SetupPhase.done);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _SetupPhase.loading) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_phase == _SetupPhase.wizard) {
      final locale = ref.watch(localeProvider);
      return MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: SetupSupabaseScreen(
          database: widget.database,
          onFinished: _onSetupFinished,
        ),
      );
    }
    return widget.child;
  }
}
