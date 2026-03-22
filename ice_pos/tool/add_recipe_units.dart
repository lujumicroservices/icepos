// Regenera assets/data/recetas_formato.json agregando "unidad" a cada ingrediente.
// Ejecutar desde ice_pos: dart run tool/add_recipe_units.dart

import 'dart:convert';
import 'dart:io';

/// Unidades alineadas con _unidades_sugeridas del JSON: pcs | lt | kg | ml
String unitFor(String insumo, double q) {
  final s = insumo.trim();
  final lower = s.toLowerCase();

  // Líquidos por volumen
  if (lower == 'leche' ||
      lower == 'agua mineral' ||
      lower == 'concentrado soda') {
    return 'lt';
  }

  // Masas / peso
  if (lower == 'nutella' || lower == 'nieve') return 'kg';
  if (lower == 'queso cheddar' || lower == 'queso panela') return 'kg';

  // Jamón: rebanadas (pcs) o cantidad pequeña en kg
  if (lower == 'jamón selva negra' || lower == 'jamon selva negra') {
    return q < 0.5 && q != q.roundToDouble() ? 'kg' : 'pcs';
  }

  // Queso gouda: en recetas es por rebanada
  if (lower == 'queso gouda') return 'pcs';

  // Por defecto: piezas / porciones
  return 'pcs';
}

void main() {
  final root = Directory.current.path.endsWith('ice_pos')
      ? Directory.current.path
      : '${Directory.current.path}${Platform.pathSeparator}ice_pos';
  final path = '$root${Platform.pathSeparator}assets${Platform.pathSeparator}data${Platform.pathSeparator}recetas_formato.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No encontrado: $path');
    exit(1);
  }

  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final recetas = List<dynamic>.from(map['recetas'] as List<dynamic>? ?? []);

  for (final raw in recetas) {
    if (raw is! Map<String, dynamic>) continue;
    final ingredients = raw['ingredientes'] as List<dynamic>? ?? [];
    final out = <Map<String, dynamic>>[];
    for (final row in ingredients) {
      if (row is! Map<String, dynamic>) continue;
      final insumo = (row['insumo'] as String?)?.trim() ?? '';
      final cant = row['cantidad'];
      final q = cant is num ? cant.toDouble() : double.tryParse('$cant') ?? 0.0;
      out.add({
        'insumo': row['insumo'],
        'unidad': unitFor(insumo, q),
        'cantidad': row['cantidad'],
      });
    }
    raw['ingredientes'] = out;
  }

  const unidadDoc =
      'Cada ingrediente incluye "unidad": pcs | lt | kg | ml (documentación; el import a BD sigue usando cantidad + insumo).';

  // Orden de claves: metadatos primero, luego recetas
  final ordered = <String, dynamic>{
    '_formato': map['_formato'],
    '_nota': map['_nota'],
    '_origen': map['_origen'],
    '_unidades_sugeridas': map['_unidades_sugeridas'],
    '_unidad_ingrediente': unidadDoc,
    '_modificadores_leyenda': map['_modificadores_leyenda'],
    'recetas': recetas,
  };

  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(ordered)}\n');
  stdout.writeln('OK: $path');
}
