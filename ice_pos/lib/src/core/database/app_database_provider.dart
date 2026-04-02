import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/database/app_database.dart';

/// Local Drift [AppDatabase], or null on web (web never uses SQLite; use Supabase directly).
/// [main] overrides with [AppDatabase] or null; default is null unless overridden.
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);
