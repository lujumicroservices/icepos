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

/// Result of the update check: update available, already latest, or check failed (no data/error).
sealed class CheckUpdateResult {}

class UpdateAvailable extends CheckUpdateResult {
  UpdateAvailable(this.info);
  final AppReleaseInfo info;
}

class AlreadyLatest extends CheckUpdateResult {}

class CheckUpdateFailed extends CheckUpdateResult {
  CheckUpdateFailed(this.reason);
  final String reason;
}

/// Indica si el error parece ser de red y tiene sentido reintentar.
bool _isRetryableNetworkError(Object e) {
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('No address associated') ||
      s.contains('TimeoutException') ||
      s.contains('Connection refused') ||
      s.contains('ClientException') ||
      s.contains('AuthRetryableFetchException');
}

const _maxAttempts = 3;
const _retryDelay = Duration(seconds: 2);

/// Comprueba si hay una actualización disponible consultando Supabase app_releases.
/// Si la versión en la nube tiene build_number mayor al instalado, devuelve [UpdateAvailable].
/// Reintenta hasta [_maxAttempts] veces ante fallos de red (host lookup, timeout, etc.).
Future<CheckUpdateResult> checkForUpdate() async {
  if (!SupabaseService.isInitialized) {
    return CheckUpdateFailed('Supabase no configurado.');
  }

  Object? lastError;
  StackTrace? lastStack;

  for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (attempt == 1) {
        debugPrint('app_update_service: instalada build=$currentBuild (${packageInfo.version})');
      }

      final client = SupabaseService.instance.client;
      final res = await client
          .from('app_releases')
          .select('version, build_number, download_url, message_es')
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        final host = SupabaseService.debugHost;
        debugPrint(
          'app_update_service: la consulta no devolvió ninguna fila (tabla vacía o RLS). '
          'Host=${host ?? "?"}. Ejecuta scripts/test_app_releases_api.sh con tu .env para probar.',
        );
        return CheckUpdateFailed(
          'No hay datos de versiones en la nube. Revisa RLS en app_releases (migración 008).',
        );
      }

      final version = res['version'] as String? ?? '';
      final rawBuild = res['build_number'];
      final int cloudBuild = rawBuild is int
          ? rawBuild
          : rawBuild is num
              ? rawBuild.toInt()
              : int.tryParse(rawBuild?.toString() ?? '') ?? 0;
      final downloadUrl = res['download_url'] as String?;
      final messageEs = res['message_es'] as String?;

      debugPrint('app_update_service: nube version=$version build_number=$cloudBuild');

      if (cloudBuild > currentBuild) {
        return UpdateAvailable(AppReleaseInfo(
          version: version,
          buildNumber: cloudBuild,
          downloadUrl: downloadUrl?.trim().isEmpty == true ? null : downloadUrl?.trim(),
          messageEs: messageEs?.trim().isEmpty == true ? null : messageEs?.trim(),
        ));
      }
      return AlreadyLatest();
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      final retryable = _isRetryableNetworkError(e);
      debugPrint('app_update_service.checkForUpdate (intento $attempt/$_maxAttempts): $e');
      if (retryable && attempt < _maxAttempts) {
        debugPrint('app_update_service: reintento en ${_retryDelay.inSeconds}s...');
        await Future<void>.delayed(_retryDelay);
      } else {
        break;
      }
    }
  }

  debugPrint('app_update_service.checkForUpdate: $lastError');
  if (lastStack != null) debugPrint('$lastStack');
  return CheckUpdateFailed(lastError?.toString() ?? 'Error desconocido');
}
