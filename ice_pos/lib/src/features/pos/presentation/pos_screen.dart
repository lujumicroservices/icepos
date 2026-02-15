import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart' hide CartItem;
import 'package:ice_pos/src/features/pos/presentation/product_modifier_dialog.dart';
import 'package:ice_pos/src/features/pos/domain/cart_state.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/cart_controller.dart';
import 'package:ice_pos/src/features/pos/presentation/qr_scanner_screen.dart';

final _productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(posRepositoryProvider).watchProducts();
});

final _parkedOrdersStreamProvider = StreamProvider<List<ParkedOrder>>((ref) {
  return ref.watch(posRepositoryProvider).watchParkedOrders();
});

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_productsStreamProvider);
    final cartState = ref.watch(cartControllerProvider);
    final parkedOrdersAsync = ref.watch(_parkedOrdersStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          _RetrieveBar(
            parkedOrdersAsync: parkedOrdersAsync,
            onRetrieveTap: () => _showRetrieveBottomSheet(context, ref),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _ProductsGrid(
              productsAsync: productsAsync,
              onProductTap: (context, product) async {
                final groups = await ref
                    .read(posRepositoryProvider)
                    .getModifierGroupsForProduct(product.id);
                if (!context.mounted) return;
                if (groups.isEmpty) {
                  ref.read(cartControllerProvider.notifier).addToCart(product);
                } else {
                  final result = await showModalBottomSheet<List<ModifierOption>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => ProductModifierDialog(
                      product: product,
                      modifierGroups: groups,
                    ),
                  );
                  if (result != null && context.mounted) {
                    ref
                        .read(cartControllerProvider.notifier)
                        .addToCart(product, selectedModifiers: result);
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: _CartSummaryPanel(
              cartState: cartState,
              receiptAsync: ref.watch(currentReceiptProvider),
              onCheckout: () async {
                await ref.read(cartControllerProvider.notifier).checkout();
              },
              onPark: () => _showParkDialog(context, ref),
              onDiscountTap: () => _showDiscountDialog(context, ref),
              onScanDiscount: () => _scanAndApplyDiscount(context, ref),
              onRemoveDiscount: () =>
                  ref.read(cartControllerProvider.notifier).removeDiscount(),
            ),
          ),
        ],
      ),
    ),
        ],
      ),
    );
  }
}


void _showParkDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Park Order'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Customer Reference / Name (optional)',
          hintText: 'e.g. The guy in the red shirt',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Park'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    final cart = ref.read(cartControllerProvider).items;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }
    final name = controller.text.trim().isEmpty ? null : controller.text.trim();
    await ref.read(posRepositoryProvider).parkOrder(name, cart);
    ref.read(cartControllerProvider.notifier).clearCart();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order parked')),
      );
    }
  }
}

void _scanAndApplyDiscount(BuildContext context, WidgetRef ref) async {
  final code = await Navigator.push<String>(
    context,
    MaterialPageRoute<String>(
      builder: (_) => const QrScannerScreen(),
    ),
  );
  if (code == null || code.isEmpty || !context.mounted) return;
  final applied = await ref.read(cartControllerProvider.notifier).applyDiscount(code);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(applied ? 'Discount applied' : 'Invalid discount code'),
        backgroundColor: applied ? Colors.green : Colors.red,
      ),
    );
  }
}

void _showDiscountDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Apply Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Discount Code',
              hintText: 'e.g. SCHOOL_CAMPO_VERDE',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final code = await Navigator.push<String>(
                ctx,
                MaterialPageRoute<String>(
                  builder: (_) => const QrScannerScreen(),
                ),
              );
              if (code != null && code.isNotEmpty && ctx.mounted) {
                Navigator.pop(ctx, code);
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = controller.text.trim();
            if (code.isNotEmpty) {
              Navigator.pop(ctx, code);
            }
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
  if (result != null && result.isNotEmpty && context.mounted) {
    final ok = await ref.read(cartControllerProvider.notifier).applyDiscount(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Discount applied' : 'Invalid discount code'),
          backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  return '${diff.inDays} days ago';
}

void _showRetrieveBottomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Consumer(
        builder: (ctx, ref, _) {
          final parkedAsync = ref.watch(_parkedOrdersStreamProvider);
          return _ParkedOrdersList(
            scrollController: scrollController,
            parkedOrdersAsync: parkedAsync,
            onRestore: (order) async {
              await ref.read(cartControllerProvider.notifier).restoreOrder(order);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            onDelete: (order) async {
              await ref.read(posRepositoryProvider).deleteParkedOrder(order.id);
            },
          );
        },
      ),
    ),
  );
}

class _RetrieveBar extends StatelessWidget {
  const _RetrieveBar({
    required this.parkedOrdersAsync,
    required this.onRetrieveTap,
  });

  final AsyncValue<List<ParkedOrder>> parkedOrdersAsync;
  final VoidCallback onRetrieveTap;

  @override
  Widget build(BuildContext context) {
    final count = parkedOrdersAsync.when(
      data: (orders) => orders.length,
      loading: () => 0,
      error: (_, __) => 0,
    );
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: onRetrieveTap,
                  tooltip: 'Retrieve Parked Order',
                ),
                if (count > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkedOrdersList extends StatelessWidget {
  const _ParkedOrdersList({
    required this.scrollController,
    required this.parkedOrdersAsync,
    required this.onRestore,
    required this.onDelete,
  });

  final ScrollController scrollController;
  final AsyncValue<List<ParkedOrder>> parkedOrdersAsync;
  final Future<void> Function(ParkedOrder order) onRestore;
  final Future<void> Function(ParkedOrder order) onDelete;

  @override
  Widget build(BuildContext context) {
    return parkedOrdersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No parked orders',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Parked Orders',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Dismissible(
                    key: ValueKey(order.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white, size: 28),
                    ),
                    confirmDismiss: (direction) async {
                      return direction == DismissDirection.endToStart;
                    },
                    onDismissed: (_) => onDelete(order),
                    child: ListTile(
                      title: Text(
                        order.customerName ?? 'Guest',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _timeAgo(order.parkedAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        '\$${order.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () => onRestore(order),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  const _ProductsGrid({
    required this.productsAsync,
    required this.onProductTap,
  });

  final AsyncValue<List<Product>> productsAsync;
  final Future<void> Function(BuildContext context, Product product)
      onProductTap;

  @override
  Widget build(BuildContext context) {
    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
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
              'No products available',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: products[index],
                onTap: () => onProductTap(context, products[index]),
              );
            },
          ),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _ProductImage(imageUrl: product.imageUrl),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ImagePlaceholder(),
      );
    }
    return _ImagePlaceholder();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.coffee,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryPanel extends StatelessWidget {
  const _CartSummaryPanel({
    required this.cartState,
    required this.receiptAsync,
    required this.onCheckout,
    required this.onPark,
    required this.onDiscountTap,
    required this.onScanDiscount,
    required this.onRemoveDiscount,
  });

  final CartState cartState;
  final AsyncValue<ReceiptResult> receiptAsync;
  final VoidCallback onCheckout;
  final VoidCallback onPark;
  final VoidCallback onDiscountTap;
  final VoidCallback onScanDiscount;
  final VoidCallback onRemoveDiscount;

  @override
  Widget build(BuildContext context) {
    final receiptAsync = this.receiptAsync;
    final items = cartState.items;
    final receipt = receiptAsync.value;
    final total = receipt?.total ?? 0.0;
    final bundleTotal = receipt?.lines
            .where((l) => l.isBundle)
            .fold<double>(0.0, (s, l) => s + l.amount) ??
        0.0;
    final standaloneSubtotal = receipt?.standaloneSubtotal ?? 0.0;
    final discountAmount = cartState.appliedDiscount != null
        ? standaloneSubtotal * cartState.appliedDiscount!.percentage
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Cart',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: receiptAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Error loading receipt',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
              data: (receipt) {
                if (items.isEmpty || receipt.lines.isEmpty) {
                  return Center(
                    child: Text(
                      'Cart is empty',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: receipt.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = receipt.lines[index];
                    final isDiscount = line.amount < 0;
                    final subtitleWidget = line.quantity > 1
                        ? Text(
                            'Qty: ${line.quantity}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          )
                        : const SizedBox.shrink();
                    return ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.description,
                              style: GoogleFonts.inter(
                                fontWeight: line.isBundle
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (line.isBundle)
                            Chip(
                              label: Text(
                                'Combo',
                                style: GoogleFonts.inter(fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      subtitle: subtitleWidget,
                      trailing: Text(
                        '${isDiscount ? '-' : ''}\$${line.amount.abs().toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDiscount
                              ? Colors.green.shade700
                              : null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TotalsRow(label: 'Bundles', value: '\$${bundleTotal.toStringAsFixed(2)}'),
                _TotalsRow(
                  label: 'Subtotal (Other)',
                  value: '\$${standaloneSubtotal.toStringAsFixed(2)}',
                ),
                if (cartState.appliedDiscount != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Discount (${(cartState.appliedDiscount!.percentage * 100).toStringAsFixed(0)}%)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '-\$${discountAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: onRemoveDiscount,
                        tooltip: 'Remove discount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.confirmation_number_outlined),
                          onPressed: onDiscountTap,
                          tooltip: 'Apply Discount',
                        ),
                        TextButton.icon(
                          onPressed: onScanDiscount,
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: const Text('Scan Discount'),
                        ),
                      ],
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: items.isEmpty ? null : onPark,
                      icon: const Icon(Icons.pause_circle_outline),
                      tooltip: 'Park Order',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: items.isEmpty ? null : onCheckout,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Checkout',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
