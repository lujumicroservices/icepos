import 'dart:convert';
import 'dart:typed_data';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:share_plus/share_plus.dart';

/// Exporta el catálogo de productos a CSV (abre bien en Excel) con columna
/// [precio_especial_empleado] (vacía: aún no hay precio de empleado en BD).
class ProductCatalogExport {
  ProductCatalogExport._();

  static String buildCsv({
    required List<Product> products,
    required List<domain_cat.Category> categories,
  }) {
    final catById = <int, String>{
      for (final c in categories) c.id: c.name,
    };
    final sorted = [...products]
      ..sort((a, b) {
        final ca = catById[a.categoryId] ?? '';
        final cb = catById[b.categoryId] ?? '';
        final byCat = ca.compareTo(cb);
        if (byCat != 0) return byCat;
        return a.name.compareTo(b.name);
      });

    final buf = StringBuffer()
      ..writeln(
        [
          'id',
          'nombre',
          'categoria',
          'precio',
          'precio_especial_empleado',
          'activo',
        ].map(_csvField).join(','),
      );

    for (final p in sorted) {
      final catName = p.categoryId == null
          ? 'Sin categoría'
          : (catById[p.categoryId] ?? 'Sin categoría');
      buf.writeln(
        [
          p.id.toString(),
          p.name,
          catName,
          p.price.toStringAsFixed(2),
          '', // employee special price — fill in Excel / future DB column
          p.isActive ? 'si' : 'no',
        ].map(_csvField).join(','),
      );
    }
    return buf.toString();
  }

  static String _csvField(String? value) {
    final v = value ?? '';
    if (v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// Comparte/descarga el CSV (UTF-8 con BOM para Excel).
  static Future<void> shareCsv(String csv, {String? fileName}) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final name = fileName ?? 'productos_catalogo_$stamp.csv';
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'text/csv',
          name: name,
        ),
      ],
      subject: 'Catálogo de productos',
      text: 'Lista de productos con columna precio_especial_empleado',
    );
  }
}
