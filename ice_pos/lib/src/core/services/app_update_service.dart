import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

/// Información de una versión disponible (desde Supabase app_releases).
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.buildNumber,
    this.downloadUrl,
    this.messageEs,
  });

  final String version;
  final int buildNumber;
  final String? downloadUrl;
  final String? messageEs;
}

/// Comprueba si hay una actualización disponible consultando Supabase app_releases.
/// Si la versión en la nube tiene build_number mayor al instalado, devuelve [AppReleaseInfo].
/// Devuelve null si no hay Supabase, no hay filas, o la app ya está al día.
Future<AppReleaseInfo?> checkForUpdate() async {
  if (!SupabaseService.isInitialized) return null;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final client = SupabaseService.instance.client;
    final res = await client
        .from('app_releases')
        .select('version, build_number, download_url, message_es')
        .order('build_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;

    final version = res['version'] as String? ?? '';
    final buildNumber = res['build_number'] as int? ?? 0;
    final downloadUrl = res['download_url'] as String?;
    final messageEs = res['message_es'] as String?;

    if (buildNumber > currentBuild) {
      return AppReleaseInfo(
        version: version,
        buildNumber: buildNumber,
        downloadUrl: downloadUrl?.trim().isEmpty == true ? null : downloadUrl?.trim(),
        messageEs: messageEs?.trim().isEmpty == true ? null : messageEs?.trim(),
      );
    }
    return null;
  } catch (e, st) {
    debugPrint('app_update_service.checkForUpdate: $e');
    debugPrint('$st');
    return null;
  }
}
