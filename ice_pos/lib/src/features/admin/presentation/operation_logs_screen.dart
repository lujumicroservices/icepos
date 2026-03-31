import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final _operationLogsProvider = FutureProvider<List<OperationLog>>((ref) {
  return ref.read(posRepositoryProvider).getOperationLogs(limit: 800);
});

/// Local diagnostic log (failed sales, cloud sync issues). Export as .txt to share.
class OperationLogsScreen extends ConsumerWidget {
  const OperationLogsScreen({super.key});

  static Future<void> _exportAndShare(List<OperationLog> logs) async {
    final buf = StringBuffer()
      ..writeln('ICE POS — operation log')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Entries: ${logs.length}')
      ..writeln();
    for (final l in logs) {
      buf
        ..writeln('---')
        ..writeln(l.createdAt.toIso8601String())
        ..writeln('[${l.level}] ${l.operation}')
        ..writeln(l.message);
      if (l.contextJson != null && l.contextJson!.isNotEmpty) {
        buf.writeln('context: ${l.contextJson}');
      }
      if (l.stackTrace != null && l.stackTrace!.isNotEmpty) {
        buf.writeln('stack:\n${l.stackTrace}');
      }
      buf.writeln();
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ice_pos_operation_log_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await file.writeAsString(buf.toString(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ICE POS operation log',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(_operationLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.operationLogTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.operationLogEmpty,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: () => _exportAndShare(logs),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.exportOperationLog),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final l = logs[i];
                    final color = switch (l.level) {
                      'error' => Theme.of(context).colorScheme.error,
                      'warning' => Colors.orange.shade800,
                      _ => Theme.of(context).colorScheme.onSurfaceVariant,
                    };
                    return ListTile(
                      title: Text(
                        '${l.operation} · ${l.level}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.createdAt.toLocal().toString().split('.').first,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.message,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          if (l.contextJson != null &&
                              l.contextJson!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              l.contextJson!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: async.maybeWhen(
        data: (logs) {
          if (logs.isEmpty) return null;
          return FloatingActionButton.extended(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.clearOperationLogConfirmTitle),
                  content: Text(l10n.clearOperationLogConfirmBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.clear),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ref.read(posRepositoryProvider).clearOperationLogs();
                ref.invalidate(_operationLogsProvider);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.clear),
          );
        },
        orElse: () => null,
      ),
    );
  }
}
