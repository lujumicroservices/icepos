import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ice_pos/src/core/setup/supabase_config_store.dart';

/// Singleton que gestiona la conexión con Supabase.
/// Lee URL y ANON_KEY desde el archivo .env.
class SupabaseService {
  SupabaseService._();

  static SupabaseService? _instance;

  static SupabaseService get instance {
    if (_instance == null) {
      throw StateError(
        'SupabaseService no inicializado. '
        'Llama a SupabaseService.initialize() antes de usar.',
      );
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  /// Host de Supabase usado (para debug: confirmar que la app apunta al proyecto correcto).
  static String? get debugHost => _initializedHost;
  static String? _initializedHost;

  static const int _initMaxAttempts = 3;
  static const Duration _initRetryDelay = Duration(seconds: 2);

  /// Inicializa Supabase con credenciales de `.env` (prioridad) o de [SupabaseConfigStore].
  ///
  /// [overrideUrl] / [overrideAnonKey]: usados por el asistente tras guardar en preferencias
  /// (evita depender de una segunda lectura y tienen prioridad sobre `.env` en web donde
  /// a menudo no hay `.env` en assets).
  ///
  /// Debe llamarse después de dotenv.load() en main().
  /// Si faltan URL y anon key en ambos sitios, no inicializa (isInitialized queda false).
  /// Reintenta hasta [_initMaxAttempts] veces ante fallos de red (host lookup, timeout).
  static Future<void> initialize({
    String? overrideUrl,
    String? overrideAnonKey,
  }) async {
    if (_instance != null) return;

    // En web sin .env en assets, dotenv.load() falla y dotenv.env lanza NotInitializedError.
    final envUrl = dotenv.isInitialized
        ? dotenv.env['SUPABASE_URL']?.trim()
        : null;
    final envKey = dotenv.isInitialized
        ? dotenv.env['SUPABASE_ANON_KEY']?.trim()
        : null;
    final stored = await SupabaseConfigStore.loadCredentials();

    final ou = overrideUrl?.trim();
    final ok = overrideAnonKey?.trim();
    final String? urlRaw = (ou != null && ou.isNotEmpty)
        ? ou
        : (envUrl != null && envUrl.isNotEmpty)
            ? envUrl
            : stored.url;
    final String? anonKey = (ok != null && ok.isNotEmpty)
        ? ok
        : (envKey != null && envKey.isNotEmpty)
            ? envKey
            : stored.anonKey;

    if (urlRaw == null || urlRaw.isEmpty || anonKey == null || anonKey.isEmpty) {
      return; // App works offline without Supabase
    }
    // Trailing slash breaks functions.invoke URLs (…co//functions/v1/…).
    final url = urlRaw.endsWith('/') ? urlRaw.substring(0, urlRaw.length - 1) : urlRaw;

    try {
      _initializedHost = Uri.parse(url).host;
    } catch (_) {
      _initializedHost = null;
    }

    for (var attempt = 1; attempt <= _initMaxAttempts; attempt++) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _instance = SupabaseService._();
        return;
      } catch (e) {
        await _disposeSupabaseIfPartial();
        final msg = e.toString();
        final retryable = msg.contains('SocketException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('No address associated') ||
            msg.contains('TimeoutException') ||
            msg.contains('ClientException') ||
            msg.contains('AuthRetryableFetchException');
        if (retryable && attempt < _initMaxAttempts) {
          await Future<void>.delayed(_initRetryDelay);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Si [Supabase.initialize] falla después de un estado parcial, el paquete puede quedar
  /// "inicializado" y el siguiente intento no vuelve a aplicar URL/key; [dispose] lo resetea.
  static Future<void> _disposeSupabaseIfPartial() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  }

  /// Cliente de Supabase para realizar operaciones.
  SupabaseClient get client => Supabase.instance.client;
}
