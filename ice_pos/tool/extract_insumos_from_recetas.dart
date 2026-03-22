// Ejecutar desde ice_pos: dart run tool/extract_insumos_from_recetas.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final path = 'assets/data/recetas_formato.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No existe $path (ejecuta desde el directorio ice_pos).');
    exit(1);
  }
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final recetas = map['recetas'] as List<dynamic>? ?? [];
  final names = <String>{};
  for (final r in recetas) {
    if (r is! Map<String, dynamic>) continue;
    final ings = r['ingredientes'] as List<dynamic>? ?? [];
    for (final ing in ings) {
      if (ing is! Map<String, dynamic>) continue;
      final n = (ing['insumo'] as String?)?.trim() ?? '';
      if (n.isNotEmpty) names.add(n);
    }
  }
  for (final n in names.toList()..sort()) {
    print(n);
  }
  stderr.writeln('Total: ${names.length}');
}
