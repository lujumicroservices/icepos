import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import 'package:ice_pos/src/core/database/app_database.dart';

/// Persists diagnostics to local [operation_logs] (Registro de operaciones).
///
/// Niveles: critical / error / warning / info (critical = fallo de escritura en BD local o nube).
///
/// Registered from [main] when [AppDatabase] exists. [CloudSyncService] and
/// global error handlers use this so failures are not only [debugPrint].
class OperationLogSink {
  OperationLogSink._();

  static AppDatabase? _db;

  /// Call once after opening SQLite (native POS). Web / no DB: no-op forever.
  static void register(AppDatabase? db) {
    _db = db;
  }

  /// Same contract as [PosRepository.logOperationEvent]. Never throws.
  static Future<void> report({
    required String level,
    required String operation,
    required String message,
    Map<String, Object?>? context,
    StackTrace? stackTrace,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      String? ctxJson;
      if (context != null && context.isNotEmpty) {
        try {
          ctxJson = jsonEncode(context);
        } catch (_) {
          ctxJson = context.toString();
        }
      }
      await db.into(db.operationLogs).insert(
            OperationLogsCompanion.insert(
              level: level,
              operation: operation,
              message: message.length > 8000 ? '${message.substring(0, 8000)}…' : message,
              contextJson: Value(ctxJson),
              stackTrace: Value(
                stackTrace == null
                    ? null
                    : stackTrace.toString().length > 16000
                        ? '${stackTrace.toString().substring(0, 16000)}…'
                        : stackTrace.toString(),
              ),
            ),
          );
    } catch (e, st) {
      debugPrint('OperationLogSink.report insert failed: $e\n$st');
    }
  }
}
