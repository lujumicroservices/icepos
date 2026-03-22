import 'package:shared_preferences/shared_preferences.dart';

/// Persiste URL y anon key de Supabase cuando no se usan solo desde `.env`.
class SupabaseConfigStore {
  SupabaseConfigStore._();

  static const String _urlKey = 'supabase_url_stored';
  static const String _anonKeyKey = 'supabase_anon_key_stored';
  static const String _setupSkippedKey = 'supabase_setup_skipped';

  static Future<void> saveCredentials({
    required String url,
    required String anonKey,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_urlKey, url.trim());
    await p.setString(_anonKeyKey, anonKey.trim());
  }

  static Future<void> clearCredentials() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_urlKey);
    await p.remove(_anonKeyKey);
  }

  /// El usuario eligió continuar sin nube (no volver a mostrar el asistente).
  static Future<void> setSetupSkipped(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_setupSkippedKey, value);
  }

  static Future<bool> isSetupSkipped() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_setupSkippedKey) ?? false;
  }

  static Future<String?> loadStoredUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_urlKey)?.trim();
  }

  static Future<String?> loadStoredAnonKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_anonKeyKey)?.trim();
  }

  /// Una sola lectura para [SupabaseService.initialize].
  static Future<({String? url, String? anonKey})> loadCredentials() async {
    final p = await SharedPreferences.getInstance();
    return (
      url: p.getString(_urlKey)?.trim(),
      anonKey: p.getString(_anonKeyKey)?.trim(),
    );
  }
}
