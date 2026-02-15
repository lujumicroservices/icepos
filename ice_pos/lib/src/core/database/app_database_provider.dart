import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/database/app_database.dart';

/// Provides the [AppDatabase] instance.
/// Create and seed in main(), then override:
/// ```dart
/// final db = AppDatabase();
/// await DatabaseSeeder(db).seed();
/// runApp(ProviderScope(
///   overrides: [appDatabaseProvider.overrideWith((_) => db)],
///   child: MyApp(),
/// ));
/// ```
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
