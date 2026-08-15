import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/app_update_dialogs.dart';
import 'package:ice_pos/src/core/services/app_update_service.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kRemoteUpdateAckMs = 'remote_update_last_ack_ms';

/// Envuelve [HomeScreen]: consulta en Supabase si el admin pidió actualizar esta caja (pull).
/// No usa push (FCM); al abrir la app y al volver al primer plano, si hay señal nueva muestra diálogo.
class RemoteUpdateBootstrap extends ConsumerStatefulWidget {
  const RemoteUpdateBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RemoteUpdateBootstrap> createState() => _RemoteUpdateBootstrapState();
}

class _RemoteUpdateBootstrapState extends ConsumerState<RemoteUpdateBootstrap>
    with WidgetsBindingObserver {
  DateTime? _lastPoll;
  static bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePoll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedulePoll();
    }
  }

  void _schedulePoll() {
    if (kIsWeb) return;
    if (!CloudSyncService.isEnabled) return;
    final now = DateTime.now();
    if (_lastPoll != null && now.difference(_lastPoll!) < const Duration(seconds: 45)) {
      return;
    }
    _lastPoll = now;
    Future<void>.delayed(Duration.zero, _poll);
  }

  Future<void> _poll() async {
    if (!mounted || kIsWeb || !CloudSyncService.isEnabled) return;
    if (!ConnectivityService.instance.isConnected) return;
    if (_dialogOpen) return;

    final signal = await CloudSyncService.fetchRemoteUpdateRequestForCurrentDevice();
    if (!mounted || signal == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final ackMs = prefs.getInt(_kRemoteUpdateAckMs) ?? 0;
    final atMs = signal.at.toUtc().millisecondsSinceEpoch;
    if (atMs <= ackMs) return;

    final l10n = ref.read(appLocalizationsProvider);
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.remoteUpdateRequestedTitle),
          content: SingleChildScrollView(
            child: Text(
              signal.message ?? l10n.remoteUpdateRequestedBodyDefault,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setInt(_kRemoteUpdateAckMs, atMs);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.remoteUpdateAckLater),
            ),
            FilledButton(
              onPressed: () async {
                final result = await checkForUpdate();
                if (!ctx.mounted) return;
                await presentCheckUpdateResult(ctx, l10n, result);
                await prefs.setInt(_kRemoteUpdateAckMs, atMs);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.remoteUpdateCheckNow),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
