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
  /// Debe llamarse después de dotenv.load() en main().
  /// Si faltan URL y anon key en ambos sitios, no inicializa (isInitialized queda false).
  /// Reintenta hasta [_initMaxAttempts] veces ante fallos de red (host lookup, timeout).
  static Future<void> initialize() async {
    if (_instance != null) return;

    final envUrl = dotenv.env['SUPABASE_URL']?.trim();
    final envKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    final stored = await SupabaseConfigStore.loadCredentials();

    final url = (envUrl != null && envUrl.isNotEmpty) ? envUrl : stored.url;
    final anonKey = (envKey != null && envKey.isNotEmpty) ? envKey : stored.anonKey;

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      return; // App works offline without Supabase
    }

    try {
      _initializedHost = Uri.parse(url).host;
    } catch (_) {
      _initializedHost = null;
    }

    Object? lastError;
    for (var attempt = 1; attempt <= _initMaxAttempts; attempt++) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _instance = SupabaseService._();
        return;
      } catch (e) {
        lastError = e;
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
    if (lastError != null) throw lastError!;
  }

  /// Cliente de Supabase para realizar operaciones.
  SupabaseClient get client => Supabase.instance.client;
}
