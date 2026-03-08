/// Regla de descuento aplicada a productos cuyo nombre contenga [nameContains].
/// Ej.: 20% de descuento en productos que contengan "nieve" (Cono Chico, Vaso Grande, etc.).
class ProductDiscountRule {
  const ProductDiscountRule({
    required this.nameContains,
    required this.percentage,
    this.label,
  });

  /// Texto a buscar en el nombre del producto (case insensitive). Ej. "nieve".
  final String nameContains;

  /// Porcentaje de descuento (0.20 = 20%).
  final double percentage;

  /// Etiqueta opcional para el ticket (ej. "Día de la mujer").
  final String? label;
}
