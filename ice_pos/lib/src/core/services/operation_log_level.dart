/// Niveles para [OperationLogs.level] (texto en SQLite, máx. 16 en esquema).
///
/// Usa [critical] para **cualquier fallo de escritura** en base local (Drift) o en la nube (Supabase).
abstract final class OperationLogLevel {
  OperationLogLevel._();

  /// Escritura fallida: INSERT/UPDATE/UPSERT en SQLite o Supabase.
  static const critical = 'critical';

  /// Error grave que no es claramente una escritura a BD (p. ej. Flutter, async, provider).
  static const error = 'error';

  static const warning = 'warning';
  static const info = 'info';
}
