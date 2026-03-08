import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/admin/presentation/product_editor_screen.dart';

final _allProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(posRepositoryProvider).watchAllProducts();
});

final _categoriesProvider = FutureProvider<List<domain_cat.Category>>((ref) {
  return ref.read(posRepositoryProvider).getAllCategories();
});

/// One section: category name, optional color, and products.
class _CategorySection {
  const _CategorySection({
    required this.name,
    required this.products,
    this.color,
  });
  final String name;
  final List<Product> products;
  final String? color;
}

List<_CategorySection> _groupProductsByCategory(
  List<Product> products,
  List<domain_cat.Category> categories,
) {
  final map = <int?, List<Product>>{};
  for (final p in products) {
    map.putIfAbsent(p.categoryId, () => []).add(p);
  }
  final uncategorized = map.remove(null);
  final sections = <_CategorySection>[];

  for (final c in categories) {
    final list = map.remove(c.id);
    if (list != null && list.isNotEmpty) {
      list.sort((a, b) => a.name.compareTo(b.name));
      sections.add(_CategorySection(
        name: c.name,
        products: list,
        color: c.color,
      ));
    }
  }
  if (uncategorized != null && uncategorized.isNotEmpty) {
    uncategorized.sort((a, b) => a.name.compareTo(b.name));
    sections.add(_CategorySection(name: 'Sin categoría', products: uncategorized));
  }
  return sections;
}

class ProductManagementScreen extends ConsumerWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_allProductsStreamProvider);
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product Management',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading products',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Text(
                'No products. Tap + to add.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _flatProductList(context, ref, products),
            data: (categories) {
              final sections = _groupProductsByCategory(products, categories);
              return ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  for (final section in sections) ...[
                    _SectionHeader(
                      name: section.name,
                      count: section.products.length,
                      color: section.color,
                    ),
                    ...section.products.map((p) => _ProductTile(product: p, ref: ref)),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => const ProductEditorScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _flatProductList(BuildContext context, WidgetRef ref, List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: products.length,
      itemBuilder: (context, index) => _ProductTile(product: products[index], ref: ref),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.name,
    required this.count,
    this.color,
  });

  final String name;
  final int count;
  final String? color;

  static int _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF6200EE;
    final c = hex.replaceFirst('#', '');
    if (c.length == 6) return 0xFF000000 + int.parse(c, radix: 16);
    return 0xFF6200EE;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = color != null ? Color(_parseColor(color)) : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.ref});

  final Product product;
  final WidgetRef ref;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    await ref.read(posRepositoryProvider).setProductActive(
          product.id,
          !product.isActive,
        );
    ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product.isActive ? 'Producto desactivado' : 'Producto activado',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteProduct(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Eliminar "${product.name}"? Esta acción no se puede deshacer.\n\n'
          'Si el producto tiene ventas asociadas no se puede eliminar; en ese caso desactívalo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(posRepositoryProvider).deleteProduct(product.id);
      ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => ProductEditorScreen(productId: product.id),
          ),
        );
      },
      title: Text(
        product.name,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '\$${product.price.toStringAsFixed(2)}',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!product.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  'Inactivo',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'toggle') {
                await _toggleActive(context, ref);
              } else if (value == 'delete') {
                await _deleteProduct(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  product.isActive ? 'Desactivar' : 'Activar',
                  style: GoogleFonts.inter(),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
