import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Guarda el CSV en el directorio de documentos de la app. Devuelve la ruta o null.
Future<String?> saveRecipeImportCsv(String csv) async {
  final dir = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('${dir.path}/recipe_import_$stamp.csv');
  await file.writeAsString(csv, encoding: utf8);
  return file.path;
}
