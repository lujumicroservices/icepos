import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
                    '${l10n.storeLabel} #${d.storeId}'
                    '${d.registerId != null ? ' · Caja #${d.registerId}' : ''}'
                    ' · ${l10n.cloudDeviceLastSeen}: $seenStr · ${d.platform ?? '—'} · ${d.appVersion ?? '—'}'
                    '${d.remoteUpdateRequestedAt != null ? ' · ${l10n.cloudUpdatePendingBadge}' : ''}',
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
  late CloudPosDeviceRecord _device;
  CloudShiftSummary? _openShift;
  List<CloudShiftSummary> _shifts = [];
  List<CloudSaleBrief> _sales = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final sid = _device.storeId;
      final refreshed = await CloudSyncService.fetchPosDeviceFromCloud(_device.deviceId);
      final open = await CloudSyncService.fetchOpenShiftForDeviceCloud(
        _device.deviceId,
        storeId: sid,
      );
      final shifts = await CloudSyncService.fetchShiftsForDeviceFromCloud(
        _device.deviceId,
        storeId: sid,
      );
      final sales = await CloudSyncService.fetchSalesForDeviceFromCloud(
        _device.deviceId,
        storeId: sid,
      );
      if (mounted) {
        setState(() {
          if (refreshed != null) _device = refreshed;
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

  Future<void> _promptRequestRemoteUpdate() async {
    final l10n = ref.read(appLocalizationsProvider);
    final messageController = TextEditingController(
      text: _device.remoteUpdateMessage ?? '',
    );
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.cloudRequestAppUpdate),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.cloudRequestAppUpdateSubtitle, style: GoogleFonts.inter(fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: l10n.cloudUpdateRequestMessageHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.apply)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (!ConnectivityService.instance.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.offlineRequiresInternet)));
        return;
      }
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final msg = messageController.text.trim();
      final err = await CloudSyncService.setRemoteUpdateRequestForDevice(
        deviceId: _device.deviceId,
        message: msg.isEmpty ? null : msg,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err == null ? l10n.cloudUpdateRequestSent : err),
          backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
        ),
      );
      if (err == null) {
        ref.invalidate(_cloudDevicesProvider);
        await _reload();
      }
    } on OfflineMasterWriteException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      messageController.dispose();
    }
  }

  Future<void> _clearRemoteUpdate() async {
    final l10n = ref.read(appLocalizationsProvider);
    if (!ConnectivityService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.offlineRequiresInternet)));
      return;
    }
    try {
      OfflineWritePolicy.requireOnlineForMasterWrite();
      final err = await CloudSyncService.clearRemoteUpdateRequestForDevice(_device.deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err == null ? l10n.cloudUpdateRequestCleared : err),
          backgroundColor: err != null ? Theme.of(context).colorScheme.error : null,
        ),
      );
      if (err == null) {
        ref.invalidate(_cloudDevicesProvider);
        await _reload();
      }
    } on OfflineMasterWriteException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
        title: Text(_device.deviceName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                        '${l10n.storeLabel} #${_device.storeId}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _device.deviceId,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _promptRequestRemoteUpdate,
                        icon: const Icon(Icons.system_update_alt, size: 20),
                        label: Text(l10n.cloudRequestAppUpdate),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.cloudRequestAppUpdateSubtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      if (_device.remoteUpdateRequestedAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 20, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${l10n.cloudUpdatePendingBadge}: '
                                '${_device.remoteUpdateRequestedAt!.toLocal()}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading ? null : _clearRemoteUpdate,
                          child: Text(l10n.cloudClearUpdateRequest),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.cloudDeviceOpenShift,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_openShift != null) ...[
                        Text(
                          '${l10n.openingTime}: ${_openShift!.startTime.toLocal()} · shift_id ${_openShift!.id}'
                          '${_openShift!.registerLabel != null ? ' · ${_openShift!.registerLabel}' : ''}',
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
