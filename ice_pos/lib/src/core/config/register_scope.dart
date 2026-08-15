import 'package:shared_preferences/shared_preferences.dart';

const String _kActiveRegisterIdKey = 'pos_active_register_id';

/// Default register for new installs (matches seeded `pos_registers.id = 1`).
const int kDefaultRegisterId = 1;

/// Cajón / estación de caja activa en este terminal (`pos_registers.id` en Supabase).
class RegisterScope {
  RegisterScope._();

  static int? _mem;

  static Future<int> getActiveRegisterId() async {
    if (_mem != null) return _mem!;
    final prefs = await SharedPreferences.getInstance();
    _mem = prefs.getInt(_kActiveRegisterIdKey) ?? kDefaultRegisterId;
    return _mem!;
  }

  static Future<void> setActiveRegisterId(int id) async {
    if (id < 1) return;
    _mem = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kActiveRegisterIdKey, id);
  }

  static void clearMemoryCache() {
    _mem = null;
  }
}
