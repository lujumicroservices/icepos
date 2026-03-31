/// Modo de conteo físico para un insumo.
abstract final class StockCountMode {
  static const quantity = 'quantity';
  static const qualitative = 'qualitative';
}

/// Niveles cualitativos para inventario (orden: de más a menos stock relativo).
abstract final class QualitativeLevel {
  static const alto = 'alto';
  static const medio = 'medio';
  static const bajo = 'bajo';
  /// Nivel más bajo (equivalente operativo a [resurtir] en datos antiguos).
  static const critico = 'critico';
  /// Valor legado; se acepta en lectura y se mapea como [critico] en UI nueva.
  static const resurtir = 'resurtir';

  static const all = [alto, medio, bajo, critico];

  static bool isValid(String? v) =>
      v != null && (all.contains(v) || v == resurtir);
}

/// Convierte nivel cualitativo a un valor numérico en [currentStock] para compatibilidad
/// con recetas/ventas (estimación relativa, no unidades físicas).
double stockFromQualitativeLevel(String level) {
  switch (level) {
    case QualitativeLevel.alto:
      return 1.0;
    case QualitativeLevel.medio:
      return 0.66;
    case QualitativeLevel.bajo:
      return 0.33;
    case QualitativeLevel.critico:
    case QualitativeLevel.resurtir:
      return 0.0;
    default:
      return 0.0;
  }
}
