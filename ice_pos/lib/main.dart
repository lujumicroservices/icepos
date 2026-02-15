import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/database/seeder.dart';
import 'package:ice_pos/src/core/utils/logger.dart';
import 'package:ice_pos/src/features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  await DatabaseSeeder(database).seed();

  runApp(
    ProviderScope(
      observers: [RiverpodLogger()],
      overrides: [
        appDatabaseProvider.overrideWith((_) => database),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICE POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}