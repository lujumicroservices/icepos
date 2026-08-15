/// Política: cajero ([UserRole.employee]) debe pedir aprobación de admin para ciertas acciones.

/// Si el efectivo declarado en corte está por debajo del esperado en más de este monto (pesos),
/// el cierre no se completa hasta que un administrador apruebe la solicitud en el mismo dispositivo.
const double kCashShortageRequiresApprovalPesos = 200.0;

/// [cashDifference] = efectivo declarado − efectivo esperado en caja (mismo criterio que el corte).
bool cashShortageRequiresAdminApproval(double cashDifference) =>
    cashDifference < -kCashShortageRequiresApprovalPesos;
