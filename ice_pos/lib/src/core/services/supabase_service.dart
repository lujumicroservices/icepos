import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Inicializa Supabase con las credenciales del archivo .env.
  /// Debe llamarse después de dotenv.load() en main().
  /// Si faltan SUPABASE_URL o SUPABASE_ANON_KEY, no inicializa (isInitialized queda false).
  static Future<void> initialize() async {
    if (_instance != null) return;

    final url = dotenv.env['SUPABASE_URL']?.trim();
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      return; // App works offline without Supabase
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _instance = SupabaseService._();
  }

  /// Cliente de Supabase para realizar operaciones.
  SupabaseClient get client => Supabase.instance.client;
}
