/// Unidad reservada: inventario por **nivel** (alto/medio/bajo/crítico), no por cantidad.
/// Valor almacenado en `supplies.unit` (4 caracteres).
const String kQualitativeUnitMarker = 'qual';

/// Unidades de medida habituales para insumos (`supplies.unit`, máx. 10 caracteres).
const List<String> kSupplyUnitOptions = [
  'kg',
  'lt',
  'pz',
  'pcs',
  'g',
  'ml',
  kQualitativeUnitMarker,
];

/// Opciones para un dropdown: lista estándar más la unidad actual si no está en la lista.
List<String> supplyUnitDropdownItems(String currentUnit) {
  final out = List<String>.from(kSupplyUnitOptions);
  final u = currentUnit.trim();
  if (u.isNotEmpty && !out.contains(u)) {
    out.add(u);
  }
  return out;
}
