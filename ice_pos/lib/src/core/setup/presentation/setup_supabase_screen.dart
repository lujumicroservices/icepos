import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/core/setup/supabase_config_store.dart';

/// Primer arranque: formulario para guardar URL y anon key y conectar a Supabase.
class SetupSupabaseScreen extends ConsumerStatefulWidget {
  const SetupSupabaseScreen({
    super.key,
    required this.database,
    required this.onFinished,
  });

  final AppDatabase database;
  final VoidCallback onFinished;

  @override
  ConsumerState<SetupSupabaseScreen> createState() => _SetupSupabaseScreenState();
}

class _SetupSupabaseScreenState extends ConsumerState<SetupSupabaseScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final url = await SupabaseConfigStore.loadStoredUrl();
    final key = await SupabaseConfigStore.loadStoredAnonKey();
    if (mounted) {
      if (url != null && url.isNotEmpty) _urlCtrl.text = url;
      if (key != null && key.isNotEmpty) _keyCtrl.text = key;
    }
  }

  bool _validHttpsUrl(String s) {
    try {
      final u = Uri.parse(s.trim());
      return u.hasScheme && u.scheme == 'https' && u.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _connect() async {
    final l10n = ref.read(appLocalizationsProvider);
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (!_validHttpsUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setupSupabaseInvalidUrl)),
      );
      return;
    }
    if (key.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setupSupabaseError)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseConfigStore.saveCredentials(url: url, anonKey: key);
      await SupabaseService.initialize();
      if (!SupabaseService.isInitialized) {
        throw StateError('init');
      }
      final err = await CloudSyncService.syncFromCloud(widget.database);
      if (err != null) {
        await CloudSyncService.setStartupSyncError(err);
      }
      if (mounted) widget.onFinished();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.read(appLocalizationsProvider).setupSupabaseError} $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    await SupabaseConfigStore.setSetupSkipped(true);
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.cloud_outlined, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.setupSupabaseTitle,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.setupSupabaseSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.setupSupabaseUrlLabel,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.setupSupabaseAnonKeyLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.setupSupabaseSchemaNote,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: _busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(l10n.setupSupabaseConnecting),
                            ],
                          )
                        : Text(l10n.setupSupabaseConnect),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _skip,
                    child: Text(l10n.setupSupabaseSkip),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
