import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';

/// One line of the CSV / audit report for [RecipeJsonImportService].
class RecipeImportReportRow {
  const RecipeImportReportRow({
    required this.status,
    required this.productName,
    this.productId,
    this.insumo,
    this.unidad,
    this.cantidad,
    this.supplyId,
    this.message,
  });

  /// OK | ERR_NO_PRODUCT | ERR_NO_SUPPLY | SKIP_EMPTY | INFO_MODIFIER | WARN_DUP_PRODUCT_NAME | SUMMARY
  final String status;
  final String productName;
  final String? productId;
  final String? insumo;
  final String? unidad;
  final String? cantidad;
  final String? supplyId;
  final String? message;
}

/// Result of importing [assets/data/recetas_formato.json] into local [recipes].
class RecipeImportResult {
  RecipeImportResult({
    required this.rows,
    required this.productsUpdated,
    required this.recipeLinesInserted,
    required this.productsSkippedEmptyJson,
    required this.productsFailed,
    required this.updatedProductIds,
  });

  final List<RecipeImportReportRow> rows;
  final int productsUpdated;
  final int recipeLinesInserted;
  final int productsSkippedEmptyJson;
  final int productsFailed;

  /// Product IDs that received a full recipe replace + insert (for optional cloud sync).
  final Set<int> updatedProductIds;

  /// RFC 4180-style CSV (UTF-8). First row is header.
  static String toCsv(List<RecipeImportReportRow> rows) {
    const header =
        'status,product_name,product_id,insumo,unidad,cantidad,supply_id,message';
    final lines = <String>[header];
    for (final r in rows) {
      lines.add([
        _csvField(r.status),
        _csvField(r.productName),
        _csvField(r.productId),
        _csvField(r.insumo),
        _csvField(r.unidad),
        _csvField(r.cantidad),
        _csvField(r.supplyId),
        _csvField(r.message),
      ].join(','));
    }
    return '${lines.join('\n')}\n';
  }

  static String _csvField(String? value) {
    if (value == null || value.isEmpty) return '';
    final s = value;
    if (s.contains(',') || s.contains('"') || s.contains('\r') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

/// Imports recipe ingredients from `recetas_formato.json` into Drift [recipes].
///
/// - Does **not** create modifier groups/options from `modificadores` (only logs [INFO_MODIFIER]).
/// - Per product: all ingredients must resolve to supplies or the product is skipped (no partial write).
/// - Empty `ingredientes: []` skips the product (existing local recipes are left unchanged).
/// - Optional per line: `unidad` (pcs|lt|kg|ml) is ignored for DB insert; included in CSV report.
class RecipeJsonImportService {
  RecipeJsonImportService(this._db);

  final AppDatabase _db;

  /// [jsonString] = full file contents. [assetLabel] appears in SUMMARY row.
  Future<RecipeImportResult> importRecetasFormatoJson(
    String jsonString, {
    required String assetLabel,
    bool applyChanges = true,
    bool pushUpdatedProductsToCloud = false,
  }) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final rawList = map['recetas'] as List<dynamic>? ?? [];

    final products = await _db.select(_db.products).get();
    final supplies = await _db.select(_db.supplies).get();

    final nameToProductId = <String, int>{};
    final duplicateProductNames = <String>{};
    for (final p in products) {
      final key = p.name.trim();
      if (nameToProductId.containsKey(key)) {
        duplicateProductNames.add(key);
      } else {
        nameToProductId[key] = p.id;
      }
    }

    final nameToSupplyId = <String, int>{};
    final duplicateSupplyNames = <String>{};
    for (final s in supplies) {
      final key = s.name.trim();
      if (nameToSupplyId.containsKey(key)) {
        duplicateSupplyNames.add(key);
      } else {
        nameToSupplyId[key] = s.id;
      }
    }

    final rows = <RecipeImportReportRow>[];
    for (final name in duplicateProductNames) {
      rows.add(RecipeImportReportRow(
        status: 'WARN_DUP_PRODUCT_NAME',
        productName: name,
        message:
            'Hay más de un producto con este nombre; se usa el primero encontrado por id.',
      ));
    }
    for (final name in duplicateSupplyNames) {
      rows.add(RecipeImportReportRow(
        status: 'WARN_DUP_SUPPLY_NAME',
        productName: '',
        insumo: name,
        message:
            'Hay más de un insumo con este nombre; se usa el primero encontrado por id.',
      ));
    }

    var productsUpdated = 0;
    var recipeLinesInserted = 0;
    var productsSkippedEmptyJson = 0;
    var productsFailed = 0;
    final updatedProductIds = <int>{};

    for (final raw in rawList) {
      if (raw is! Map<String, dynamic>) continue;
      final productName = (raw['producto'] as String?)?.trim() ?? '';
      if (productName.isEmpty) continue;

      final modificadores = raw['modificadores'];
      if (modificadores != null) {
        rows.add(RecipeImportReportRow(
          status: 'INFO_MODIFIER',
          productName: productName,
          message:
              'El JSON describe modificadores; no se importan desde este archivo. '
              'Usa los JSON de modificadores (nieves_modifiers, etc.) o admin.',
        ));
      }

      final ingredients = raw['ingredientes'] as List<dynamic>? ?? [];
      if (ingredients.isEmpty) {
        productsSkippedEmptyJson++;
        rows.add(RecipeImportReportRow(
          status: 'SKIP_EMPTY',
          productName: productName,
          message:
              'Sin ingredientes en JSON; no se modifican recetas locales de este producto.',
        ));
        continue;
      }

      final productId = nameToProductId[productName];
      if (productId == null) {
        productsFailed++;
        rows.add(RecipeImportReportRow(
          status: 'ERR_NO_PRODUCT',
          productName: productName,
          message: 'No existe un producto con este nombre exacto en la BD local.',
        ));
        continue;
      }

      final resolved =
          <({String insumo, String? unidad, double cantidad, int supplyId})>[];
      var supplyError = false;
      for (final ing in ingredients) {
        if (ing is! Map<String, dynamic>) continue;
        final insumo = (ing['insumo'] as String?)?.trim() ?? '';
        final unidadRaw = ing['unidad'];
        final unidad = unidadRaw is String ? unidadRaw.trim() : null;
        final cant = ing['cantidad'];
        final qty = cant is num ? cant.toDouble() : double.tryParse('$cant') ?? 0.0;
        if (insumo.isEmpty) continue;
        final sid = nameToSupplyId[insumo];
        if (sid == null) {
          supplyError = true;
          rows.add(RecipeImportReportRow(
            status: 'ERR_NO_SUPPLY',
            productName: productName,
            productId: '$productId',
            insumo: insumo,
            unidad: unidad?.isEmpty ?? true ? null : unidad,
            cantidad: '$qty',
            message: 'Insumo no encontrado en BD local (nombre exacto).',
          ));
        } else {
          resolved.add((
            insumo: insumo,
            unidad: unidad?.isEmpty ?? true ? null : unidad,
            cantidad: qty,
            supplyId: sid
          ));
        }
      }

      if (supplyError) {
        productsFailed++;
        rows.add(RecipeImportReportRow(
          status: 'ERR_ABORT_PRODUCT',
          productName: productName,
          productId: '$productId',
          message:
              'No se escribieron recetas para este producto por insumos faltantes.',
        ));
        continue;
      }

      if (resolved.isEmpty) {
        productsSkippedEmptyJson++;
        rows.add(RecipeImportReportRow(
          status: 'SKIP_EMPTY',
          productName: productName,
          productId: '$productId',
          message: 'Lista de ingredientes sin filas válidas.',
        ));
        continue;
      }

      if (applyChanges) {
        await _db.transaction(() async {
          await (_db.delete(_db.recipes)..where((r) => r.productId.equals(productId)))
              .go();
          for (final r in resolved) {
            await _db.into(_db.recipes).insert(
                  RecipesCompanion.insert(
                    productId: productId,
                    supplyId: r.supplyId,
                    quantityRequired: r.cantidad,
                  ),
                );
          }
        });
      }

      productsUpdated++;
      recipeLinesInserted += resolved.length;
      updatedProductIds.add(productId);

      for (final r in resolved) {
        rows.add(RecipeImportReportRow(
          status: applyChanges ? 'OK' : 'DRY_RUN_OK',
          productName: productName,
          productId: '$productId',
          insumo: r.insumo,
          unidad: r.unidad,
          cantidad: '${r.cantidad}',
          supplyId: '${r.supplyId}',
          message: applyChanges ? 'receta insertada' : 'simulación sin escribir BD',
        ));
      }
    }

    rows.add(RecipeImportReportRow(
      status: 'SUMMARY',
      productName: assetLabel,
      message: jsonEncode({
        'products_updated': productsUpdated,
        'recipe_lines_inserted': recipeLinesInserted,
        'products_skipped_empty_json': productsSkippedEmptyJson,
        'products_failed_or_aborted': productsFailed,
        'apply_changes': applyChanges,
        'push_cloud_requested': pushUpdatedProductsToCloud,
      }),
    ));

    final result = RecipeImportResult(
      rows: rows,
      productsUpdated: productsUpdated,
      recipeLinesInserted: recipeLinesInserted,
      productsSkippedEmptyJson: productsSkippedEmptyJson,
      productsFailed: productsFailed,
      updatedProductIds: updatedProductIds,
    );

    if (applyChanges &&
        pushUpdatedProductsToCloud &&
        CloudSyncService.isEnabled) {
      for (final pid in updatedProductIds) {
        CloudSyncService.syncProductToCloudFull(_db, pid).catchError((Object e) {
          debugPrint('Recipe import: syncProductToCloudFull($pid): $e');
          return null;
        });
      }
    }

    return result;
  }
}
