import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:intl/intl.dart';

/// Admin (terminal con Drift): enlazar tienda/cajón y turno a un turno abierto en Supabase.
class LinkOpenShiftScreen extends ConsumerStatefulWidget {
  const LinkOpenShiftScreen({super.key});

  @override
  ConsumerState<LinkOpenShiftScreen> createState() => _LinkOpenShiftScreenState();
}

class _LinkOpenShiftScreenState extends ConsumerState<LinkOpenShiftScreen> {
  List<CloudShiftSummary> _shifts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final l10n = ref.read(appLocalizationsProvider);
    if (!ConnectivityService.instance.isConnected) {
      setState(() {
        _loading = false;
        _error = l10n.offlineRequiresInternet;
      });
      return;
    }
    final list = await CloudSyncService.fetchAllOpenShiftsForAdmin();
    if (!mounted) return;
    setState(() {
      _shifts = list;
      _loading = false;
    });
  }

  String _formatStarted(DateTime t) {
    final locale = ref.read(localeProvider);
    final tag = locale.languageCode == 'en' ? 'en' : 'es';
    return DateFormat('dd/MM/yyyy HH:mm', tag).format(t.toLocal());
  }

  Future<void> _onTapShift(CloudShiftSummary shift) async {
    final l10n = ref.read(appLocalizationsProvider);
    final pos = ref.read(posRepositoryProvider);
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminLinkOpenShiftRequiresLocalDb)),
      );
      return;
    }
    final local = await pos.getCurrentShift();
    if (!mounted) return;
    final localCloud = local != null ? CloudSyncService.supabaseShiftId(local) : null;
    final showUnlinkNote = local != null && localCloud != shift.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final storeName = shift.storeName ?? '${l10n.storeLabel} ${shift.storeId}';
        final reg = shift.registerLabel ?? '—';
        return AlertDialog(
          title: Text(l10n.adminLinkOpenShiftConfirmTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.adminLinkOpenShiftConfirmBody(shift.id, storeName, reg),
                  style: GoogleFonts.inter(height: 1.35),
                ),
                if (showUnlinkNote) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.adminLinkOpenShiftUnlinkNote,
                    style: GoogleFonts.inter(
                      height: 1.35,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.apply)),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.adminLinkOpenShiftLinking)),
          ],
        ),
      ),
    );

    final err = await pos.adminLinkDeviceToCloudOpenShift(shift);
    if (mounted) Navigator.of(context).pop();

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminLinkOpenShiftLinkedOk)));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final pos = ref.watch(posRepositoryProvider);

    if (pos == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminLinkOpenShiftTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.adminLinkOpenShiftRequiresLocalDb, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminLinkOpenShiftTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              : _shifts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.adminLinkOpenShiftEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _shifts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = _shifts[i];
                        final storeName = s.storeName ?? '${l10n.storeLabel} ${s.storeId}';
                        final reg = s.registerLabel ?? '—';
                        final dev = s.deviceName ?? s.deviceId ?? '—';
                        return Card(
                          child: ListTile(
                            title: Text(
                              l10n.adminLinkOpenShiftLine(
                                storeName,
                                reg,
                                '${s.id}',
                                _formatStarted(s.startTime),
                              ),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                l10n.adminLinkOpenShiftDeviceLine(dev),
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                            isThreeLine: true,
                            onTap: () => _onTapShift(s),
                          ),
                        );
                      },
                    ),
    );
  }
}
