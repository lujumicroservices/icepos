import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';
import 'package:ice_pos/src/features/monitoring/presentation/cloud_devices_admin_tab.dart';

class ShiftCloseEventRow {
  const ShiftCloseEventRow({
    required this.id,
    required this.createdAt,
    required this.event,
    required this.deviceId,
    required this.deviceName,
    this.shiftId,
    this.context,
  });

  final int id;
  final DateTime createdAt;
  final String event;
  final String deviceId;
  final String deviceName;
  final int? shiftId;
  final Map<String, dynamic>? context;

  static ShiftCloseEventRow? tryParse(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : int.tryParse('$idRaw');
    if (id == null) return null;
    final createdRaw = m['created_at'];
    final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
    if (createdAt == null) return null;
    final event = m['event'] as String? ?? '';
    final deviceId = m['device_id'] as String? ?? '';
    final deviceName = m['device_name'] as String? ?? '';
    final shiftRaw = m['shift_id'];
    final ctxRaw = m['context'];
    Map<String, dynamic>? ctx;
    if (ctxRaw is Map<String, dynamic>) {
      ctx = ctxRaw;
    } else if (ctxRaw is Map) {
      ctx = Map<String, dynamic>.from(ctxRaw);
    }
    return ShiftCloseEventRow(
      id: id,
      createdAt: createdAt,
      event: event,
      deviceId: deviceId,
      deviceName: deviceName,
      shiftId: shiftRaw is int ? shiftRaw : int.tryParse('$shiftRaw'),
      context: ctx,
    );
  }
}

final _shiftCloseEventsProvider = FutureProvider.autoDispose<List<ShiftCloseEventRow>>((ref) async {
  if (!SupabaseService.isInitialized) return [];
  try {
    final res = await SupabaseService.instance.client
        .from('shift_close_events')
        .select()
        .order('created_at', ascending: false)
        .limit(400);
    final list = res as List<dynamic>;
    final out = <ShiftCloseEventRow>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final row = ShiftCloseEventRow.tryParse(e);
      if (row != null) out.add(row);
    }
    return out;
  } catch (e) {
    throw Exception(e);
  }
});

/// Diagnóstico nube: eventos de cierre; administradores también ven dispositivos, ventas y cierre remoto.
class ShiftCloseEventsScreen extends ConsumerWidget {
  const ShiftCloseEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(userRoleProvider) == UserRole.admin;

    if (!CloudSyncService.isEnabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.shiftCloseDiagnosticsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.shiftCloseDiagnosticsDisabled,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.shiftCloseDiagnosticsTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        body: const ShiftCloseEventsTabBody(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.cloudPosDiagnosticsTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.shiftCloseEventsTab),
              Tab(text: l10n.devicesAndClosuresTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ShiftCloseEventsTabBody(),
            CloudDevicesAdminTab(),
          ],
        ),
      ),
    );
  }
}

class ShiftCloseEventsTabBody extends ConsumerWidget {
  const ShiftCloseEventsTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(_shiftCloseEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l10n.shiftCloseDiagnosticsSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_shiftCloseEventsProvider);
            },
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${l10n.error}: $e',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                ],
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.shiftCloseDiagnosticsEmpty,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final local = r.createdAt.toLocal();
                    final ts =
                        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
                        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
                    final ctxStr = r.context == null || r.context!.isEmpty
                        ? null
                        : const JsonEncoder.withIndent('  ').convert(r.context);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(
                          r.event,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '$ts · ${r.deviceName}',
                          style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'shift_id: ${r.shiftId ?? '—'}',
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'device_id: ${r.deviceId}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (ctxStr != null) ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    ctxStr,
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
