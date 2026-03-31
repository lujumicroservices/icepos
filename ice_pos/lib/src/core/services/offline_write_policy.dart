import 'package:ice_pos/src/core/services/connectivity_service.dart';

/// Thrown when a master-data write is attempted while offline.
class OfflineMasterWriteException implements Exception {
  OfflineMasterWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Master data (menú, insumos, categorías, etc.) is read-only without connectivity.
/// POS flows (ventas, movimientos, corte, pedidos apartados) stay allowed locally.
class OfflineWritePolicy {
  OfflineWritePolicy._();

  static void requireOnlineForMasterWrite() {
    if (!ConnectivityService.instance.isConnected) {
      throw OfflineMasterWriteException(
        'Sin conexión. Menú, insumos y administración solo se pueden editar con internet. '
        'Las ventas y caja siguen funcionando en este dispositivo.',
      );
    }
  }
}
