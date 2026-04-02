import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';

/// Texto de la búsqueda rápida en el POS (vacío = navegación por categorías).
final posQuickSearchQueryProvider = StateProvider<String>((ref) => '');

/// Productos activos cuyo nombre contiene [posQuickSearchQueryProvider] (sin categoría).
final posSearchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final q = ref.watch(posQuickSearchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return const [];
  final all = await ref.read(posRepositoryProvider)!.getProducts();
  final matches = all
      .where((p) => p.name.toLowerCase().contains(q))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return matches;
});
