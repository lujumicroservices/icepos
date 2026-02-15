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
  static Future<SupabaseService> initialize() async {
    if (_instance != null) {
      return _instance!;
    }

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw StateError(
        'SUPABASE_URL no encontrada en .env. '
        'Asegúrate de definir SUPABASE_URL=tu_url en el archivo .env',
      );
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY no encontrada en .env. '
        'Asegúrate de definir SUPABASE_ANON_KEY=tu_key en el archivo .env',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _instance = SupabaseService._();
    return _instance!;
  }

  /// Cliente de Supabase para realizar operaciones.
  SupabaseClient get client => Supabase.instance.client;
}
