import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAdminPinKey = 'admin_pin';
const _defaultPin = '0000';

enum UserRole { admin, employee }

/// Rol actual: empleado (solo POS e historial del día) o admin (todo).
/// Al iniciar la app siempre es [UserRole.employee]. Admin se desbloquea con PIN.
final userRoleProvider =
    NotifierProvider<UserRoleNotifier, UserRole>(UserRoleNotifier.new);

class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() => UserRole.employee;

  /// Desbloquea como admin si el PIN es correcto. Devuelve true si OK.
  Future<bool> unlockAdmin(String pin) async {
    final stored = await _getStoredPin();
    final ok = pin.trim() == stored;
    if (ok) state = UserRole.admin;
    return ok;
  }

  /// Bloquea como empleado (cierra sesión admin).
  void lockAsEmployee() {
    state = UserRole.employee;
  }

  /// Establece el rol desde la sesión de login (admin o cajero).
  void setRoleFromAuth(UserRole role) {
    state = role;
  }

  /// Establece el PIN de administrador (solo cuando ya eres admin).
  Future<void> setAdminPin(String newPin) async {
    if (state != UserRole.admin) return;
    final p = newPin.trim();
    if (p.length != 4) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdminPinKey, p);
  }

  static Future<String> _getStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_kAdminPinKey);
    return pin?.isNotEmpty == true ? pin! : _defaultPin;
  }
}
