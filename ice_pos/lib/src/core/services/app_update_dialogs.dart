import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Muestra el resultado de [checkForUpdate] (mismo flujo que el menú Comprobar actualización).
Future<void> presentCheckUpdateResult(
  BuildContext context,
  AppLocalizations l10n,
  CheckUpdateResult result,
) async {
  if (!context.mounted) return;
  switch (result) {
    case UpdateAvailable(:final info):
      final release = info;
      final openUrl = release.downloadUrl != null;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.updateAvailable),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.versionBuild} ${release.version} (build ${release.buildNumber})'),
                if (release.messageEs != null) ...[
                  const SizedBox(height: 8),
                  Text(release.messageEs!),
                ],
                if (openUrl)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l10n.downloadHint,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.later),
            ),
            if (openUrl)
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(release.downloadUrl!);
                  var opened = false;
                  try {
                    opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                  if (!opened) {
                    try {
                      opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
                    } catch (_) {}
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (ctx.mounted && !opened) {
                    await Clipboard.setData(ClipboardData(text: release.downloadUrl!));
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(l10n.downloadLinkCopied),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 20),
                label: Text(l10n.download),
              ),
          ],
        ),
      );
    case AlreadyLatest():
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.alreadyLatestVersion),
          behavior: SnackBarBehavior.floating,
        ),
      );
    case CheckUpdateFailed(:final reason):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }
}
