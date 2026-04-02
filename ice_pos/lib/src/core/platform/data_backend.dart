import 'package:flutter/foundation.dart' show kIsWeb;

/// Web builds never use local SQLite ([AppDatabase] / Drift). All persistence is Supabase.
/// Native builds may use Drift for offline-first POS and sync.
bool get isSupabaseOnlyBackend => kIsWeb;
