import 'package:shared_preferences/shared_preferences.dart';

const String _kActiveStoreIdKey = 'pos_active_store_id';

/// Default store for new installs and single-store deployments (matches Supabase seed `stores.id = 1`).
const int kDefaultStoreId = 1;

/// Tienda activa en este dispositivo.
///
/// Hoy: siempre [kDefaultStoreId] salvo valor en SharedPreferences.
/// Multi-tienda: selector en ajustes que llama a [setActiveStoreId].
class StoreScope {
  StoreScope._();

  static int? _mem;

  /// ID de tienda para ventas, turnos y registros en la nube.
  static Future<int> getActiveStoreId() async {
    if (_mem != null) return _mem!;
    final prefs = await SharedPreferences.getInstance();
    _mem = prefs.getInt(_kActiveStoreIdKey) ?? kDefaultStoreId;
    return _mem!;
  }

  /// Cambia la tienda activa (p. ej. tras login o selector). Persiste en el dispositivo.
  static Future<void> setActiveStoreId(int id) async {
    if (id < 1) return;
    _mem = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kActiveStoreIdKey, id);
  }

  /// Solo tests o reset.
  static void clearMemoryCache() {
    _mem = null;
  }
}
