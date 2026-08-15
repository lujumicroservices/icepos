import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/services/catalog_sync_progress.dart';

String catalogSyncStageLabel(AppLocalizations l10n, String stageKey) {
  switch (stageKey) {
    case 'syncStepStarting':
      return l10n.syncStepStarting;
    case 'syncStepDownloadingCategories':
      return l10n.syncStepDownloadingCategories;
    case 'syncStepDownloadingProducts':
      return l10n.syncStepDownloadingProducts;
    case 'syncStepDownloadingRecipes':
      return l10n.syncStepDownloadingRecipes;
    case 'syncStepDownloadingBundles':
      return l10n.syncStepDownloadingBundles;
    case 'syncStepSavingLocal':
      return l10n.syncStepSavingLocal;
    case 'syncStepSavingCategories':
      return l10n.syncStepSavingCategories;
    case 'syncStepSavingProducts':
      return l10n.syncStepSavingProducts;
    case 'syncStepSavingRecipes':
      return l10n.syncStepSavingRecipes;
    case 'syncStepSavingBundles':
      return l10n.syncStepSavingBundles;
    case 'syncStepFinishing':
      return l10n.syncStepFinishing;
    default:
      return l10n.syncingFromCloud;
  }
}

/// Blocking dialog that follows [progress] while a catalog sync runs.
class CatalogSyncProgressDialog extends StatelessWidget {
  const CatalogSyncProgressDialog({
    super.key,
    required this.progress,
    required this.l10n,
    this.title,
  });

  final ValueNotifier<CatalogSyncProgress> progress;
  final AppLocalizations l10n;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          title ?? l10n.syncFromCloud,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 320,
          child: ValueListenableBuilder<CatalogSyncProgress>(
            valueListenable: progress,
            builder: (context, p, _) {
              final stage = catalogSyncStageLabel(l10n, p.stageKey);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: p.fraction,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    stage,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.syncStepProgress(p.stepLabel),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (p.detail != null && p.detail!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      p.detail!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shows [CatalogSyncProgressDialog] and runs [run]. Always dismisses the dialog.
Future<T> showCatalogSyncProgressDialog<T>({
  required BuildContext context,
  required AppLocalizations l10n,
  required Future<T> Function(void Function(CatalogSyncProgress) report) run,
  String? title,
}) async {
  final progress = ValueNotifier(
    const CatalogSyncProgress(
      step: 1,
      totalSteps: 9,
      stageKey: 'syncStepStarting',
    ),
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CatalogSyncProgressDialog(
      progress: progress,
      l10n: l10n,
      title: title,
    ),
  );
  try {
    return await run((p) {
      progress.value = p;
    });
  } finally {
    progress.dispose();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
