import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';

final _cloudDevicesProvider = FutureProvider.autoDispose<List<CloudPosDeviceRecord>>((ref) async {
  return CloudSyncService.fetchPosDevicesFromCloud();
});

/// Lista de terminales registrados y acceso a ventas / cortes / cierre remoto (solo admin).
class CloudDevicesAdminTab extends ConsumerWidget {
  const CloudDevicesAdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(_cloudDevicesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_cloudDevicesProvider);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${l10n.error}: $e'),
            ),
          ],
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    l10n.cloudDevicesEmpty,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 15, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: devices.length,
            itemBuilder: (context, i) {
              final d = devices[i];
              final seen = d.lastSeenAt.toLocal();
              final seenStr =
                  '${seen.day}/${seen.month}/${seen.year} ${seen.hour.toString().padLeft(2, '0')}:${seen.minute.toString().padLeft(2, '0')}';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    d.deviceName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${l10n.storeLabel} #${d.storeId} · ${l10n.cloudDeviceLastSeen}: $seenStr · ${d.platform ?? '—'} · ${d.appVersion ?? '—'}',
                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CloudDeviceDetailScreen(device: d),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CloudDeviceDetailScreen extends ConsumerStatefulWidget {
  const CloudDeviceDetailScreen({super.key, required this.device});

  final CloudPosDeviceRecord device;

  @override
  ConsumerState<CloudDeviceDetailScreen> createState() => _CloudDeviceDetailScreenState();
}

class _CloudDeviceDetailScreenState extends ConsumerState<CloudDeviceDetailScreen> {
  CloudShiftSummary? _openShift;
  List<CloudShiftSummary> _shifts = [];
  List<CloudSaleBrief> _sales = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final sid = widget.device.storeId;
      final open = await CloudSyncService.fetchOpenShiftForDeviceCloud(
        widget.device.deviceId,
        storeId: sid,
      );
      final shifts = await CloudSyncService.fetchShiftsForDeviceFromCloud(
        widget.device.deviceId,
        storeId: sid,
      );
      final sales = await CloudSyncService.fetchSalesForDeviceFromCloud(
        widget.device.deviceId,
        storeId: sid,
      );
      if (mounted) {
        setState(() {
          _openShift = open;
          _shifts = shifts;
          _sales = sales;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _promptRemoteClose() async {
    final l10n = ref.read(appLocalizationsProvider);
    final shift = _openShift;
    if (shift == null) return;
    if (!ConnectivityService.instance.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.offlineRequiresInternet)));
      }
      return;
    }
    final controller = TextEditingController();
    final notesController = TextEditingController();
    double? declaredOut;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.cloudRemoteCloseShift),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.cloudRemoteCloseShiftHint,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: l10n.declaredCash,
                      border: const OutlineInputBorder(),
                      prefixText: r'$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: l10n.notesOptional,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () {
                  final v = parseDecimal(controller.text);
                  if (v != null && v >= 0) {
                    declaredOut = v;
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text(l10n.apply),
              ),
            ],
          );
        },
      );
      if (ok != true || declaredOut == null || !mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 20),
              Expanded(child: Text(l10n.syncingFromCloud)),
            ],
          ),
        ),
      );
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final notesTrim = notesController.text.trim();
      final err = await CloudSyncService.adminRemoteCloseShiftInCloud(
        shiftId: shift.id,
        declaredCash: declaredOut!,
        notes: notesTrim.isEmpty ? null : notesTrim,
      );
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err == null ? l10n.cloudShiftClosedRemoteOk : err),
            backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
          ),
        );
      }
      if (err == null) await _reload();
    } on OfflineMasterWriteException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      controller.dispose();
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.deviceName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${l10n.storeLabel} #${widget.device.storeId}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.device.deviceId,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.cloudDeviceOpenShift,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_openShift != null) ...[
                        Text(
                          '${l10n.openingTime}: ${_openShift!.startTime.toLocal()} · shift_id ${_openShift!.id}',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _promptRemoteClose,
                          icon: const Icon(Icons.point_of_sale),
                          label: Text(l10n.cloudRemoteCloseShift),
                        ),
                      ] else
                        Text(
                          l10n.cloudDeviceNoOpenShift,
                          style: GoogleFonts.inter(color: scheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.cloudSalesByDevice,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_sales.isEmpty)
                        Text(l10n.cloudNoSalesForDevice, style: GoogleFonts.inter(color: scheme.onSurfaceVariant))
                      else
                        ..._sales.take(40).map((s) {
                          final t = s.date.toLocal();
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '\$${s.totalAmount.toStringAsFixed(2)} · ${s.paymentMethod}',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            subtitle: Text('${t.day}/${t.month}/${t.year} ${t.hour}:${t.minute.toString().padLeft(2, '0')} · id ${s.id}'),
                          );
                        }),
                      const SizedBox(height: 24),
                      Text(
                        l10n.cloudClosuresByDevice,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_shifts.where((s) => s.closures.isNotEmpty).isEmpty)
                        Text(l10n.cloudNoClosuresForDevice, style: GoogleFonts.inter(color: scheme.onSurfaceVariant))
                      else
                        ..._shifts.where((s) => s.closures.isNotEmpty).map((s) {
                          final c = s.closures.first;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Shift ${s.id} · ${c.closureKind}'),
                              subtitle: Text(
                                '${l10n.declaredCash}: \$${c.declaredCash.toStringAsFixed(2)} · '
                                '${l10n.difference}: \$${c.difference.toStringAsFixed(2)} · '
                                '${c.closingTime.toLocal()}',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
