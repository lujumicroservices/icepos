import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDeviceIdKey = 'pos_device_id';
const _kDeviceNameKey = 'pos_device_name';

/// Identificador estable del dispositivo para asociar ventas en la nube.
/// Genera un UUID una vez por instalación y lo persiste en SharedPreferences.
class DeviceIdService {
  DeviceIdService._();

  static String? _cachedId;
  static String? _cachedName;

  /// ID único y estable de este dispositivo (mismo mientras no se desinstale la app).
  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _cachedId = id;
    return id;
  }

  /// Nombre legible del dispositivo. Si no se ha configurado, devuelve un label por defecto (ej. "Caja" + últimos 6 caracteres del id).
  static Future<String> getDeviceName() async {
    if (_cachedName != null) return _cachedName!;
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString(_kDeviceNameKey);
    if (name == null || name.isEmpty) {
      final id = await getDeviceId();
      name = 'Caja ${id.length >= 6 ? id.substring(id.length - 6) : id}';
    }
    _cachedName = name;
    return name;
  }

  /// Guarda un nombre personalizado para este dispositivo (ej. "Caja 1", "Tablet piso 2").
  static Future<void> setDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceNameKey, name);
    _cachedName = name;
  }

  /// Para usar al enviar ventas: (device_id, device_name).
  static Future<({String deviceId, String deviceName})> getDeviceInfo() async {
    final id = await getDeviceId();
    final name = await getDeviceName();
    return (deviceId: id, deviceName: name);
  }
}
