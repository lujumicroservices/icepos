import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/database/app_database.dart' hide Category;
import 'package:ice_pos/src/features/pos/data/pos_repository.dart' hide CartItem;
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/cart_state.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_line.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_print_data.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/cart_controller.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/category_navigation_controller.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/receipt_printer_controller.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/pos/presentation/checkout_dialog.dart';
import 'package:ice_pos/src/features/pos/presentation/product_modifier_dialog.dart';
import 'package:ice_pos/src/features/pos/presentation/qr_scanner_screen.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/utils/error_logger.dart';

final _parkedOrdersStreamProvider = StreamProvider<List<ParkedOrder>>((ref) {
  return ref.watch(posRepositoryProvider).watchParkedOrders();
});

/// Child categories for current navigation (root categories when at home).
final _childCategoriesProvider =
    FutureProvider<List<Category>>((ref) async {
  ref.watch(posCategoriesRefreshProvider); // refetch when categories change (e.g. from Category Management)
  final nav = ref.watch(categoryNavigationControllerProvider);
  final repo = ref.read(posRepositoryProvider);
  if (nav.currentCategoryId == null) {
    return repo.getCategories();
  }
  return repo.getCategories(parentId: nav.currentCategoryId);
});

/// Products to show when current category has no children (leaf) or at root with no categories.
final _gridProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(posCategoriesRefreshProvider); // refetch when categories change
  final nav = ref.watch(categoryNavigationControllerProvider);
  final repo = ref.read(posRepositoryProvider);
  final childCats = await ref.read(_childCategoriesProvider.future);
  if (childCats.isNotEmpty) return []; // Showing categories (and direct products via _directCategoryProductsProvider)
  if (nav.currentCategoryId == null) {
    return repo.getProducts();
  }
  return repo.getProductsByCategory(nav.currentCategoryId!);
});

/// Products that belong directly to the current category (e.g. Nieve 1/2 L, Paquetes under Nieves de Garrafa).
/// Used when the category also has subcategories, so we show these products above the subcategory cards.
final _directCategoryProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(posCategoriesRefreshProvider); // refetch when categories change
  final nav = ref.watch(categoryNavigationControllerProvider);
  if (nav.currentCategoryId == null) return [];
  return ref.read(posRepositoryProvider).getProductsByCategory(nav.currentCategoryId!);
});

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);
    final parkedOrdersAsync = ref.watch(_parkedOrdersStreamProvider);
    final navState = ref.watch(categoryNavigationControllerProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      body: Column(
        children: [
          _CategoryBreadcrumbsBar(
            breadcrumbs: navState.breadcrumbs,
            onHomeTap: () =>
                ref.read(categoryNavigationControllerProvider.notifier).goHome(),
            onBreadcrumbTap: (index) => ref
                .read(categoryNavigationControllerProvider.notifier)
                .goToBreadcrumbIndex(index),
            onBackTap: navState.breadcrumbs.isEmpty
                ? null
                : () =>
                    ref.read(categoryNavigationControllerProvider.notifier).goBack(),
            parkedCount: parkedOrdersAsync.when(
              data: (orders) => orders.length,
              loading: () => 0,
              error: (_, __) => 0,
            ),
            onRetrieveTap: () => _showRetrieveBottomSheet(context, ref),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
                final isNarrow = constraints.maxWidth < 500;
                final useVerticalLayout = isPortrait || isNarrow;

                if (useVerticalLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CategoryOrProductsGrid(
                          onProductTap: (context, product) async {
                            // Prefer product that has modifiers when multiple share the same name (e.g. Boli)
                            final byName = await ref
                                .read(posRepositoryProvider)
                                .getProductWithModifiersByName(
                                  product.name.trim(),
                                  categoryId: product.categoryId,
                                );
                            var productToUse = product;
                            var groups = byName != null
                                ? byName.groups
                                : await ref
                                    .read(posRepositoryProvider)
                                    .getModifierGroupsForProduct(product.id);
                            if (byName != null) productToUse = byName.product;
                            if (!context.mounted) return;
                            if (groups.isEmpty) {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .addToCart(productToUse);
                            } else {
                              final result = await showModalBottomSheet<
                                  ModifierDialogResult>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => ProductModifierDialog(
                                  product: productToUse,
                                  modifierGroups: groups,
                                ),
                              );
                              if (result != null && context.mounted) {
                                ref.read(cartControllerProvider.notifier).addToCart(
                                      productToUse,
                                      selectedModifiers: result.modifiers,
                                      quantity: result.quantity,
                                    );
                              }
                            }
                          },
                          onCategoryTap: (category) => ref
                              .read(categoryNavigationControllerProvider.notifier)
                              .pushCategory(category),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: () {
                          final maxH = constraints.maxHeight * 0.45;
                          return BoxConstraints(
                            minHeight: maxH < 200 ? maxH : 200,
                            maxHeight: maxH,
                          );
                        }(),
                        child: _CartSummaryPanel(
                          l10n: l10n,
                          cartState: cartState,
                          receiptAsync: ref.watch(currentReceiptProvider),
                          onRemoveItem: (item) => ref.read(cartControllerProvider.notifier).removeFromCart(item),
                          onCheckout: () async {
                            final receipt = await ref.read(currentReceiptProvider.future);
                            if (receipt.lines.isEmpty) return;
                            if (!context.mounted) return;
                            final paymentData = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (_) => CheckoutDialog(cartTotal: receipt.total, l10n: l10n),
                            );
                            if (paymentData != null && context.mounted) {
                              showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => PopScope(
                                  canPop: false,
                                  child: AlertDialog(
                                    content: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 20),
                                        Text(
                                          l10n.processingSale,
                                          style: GoogleFonts.inter(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              try {
                                await ref.read(cartControllerProvider.notifier).completeSale(paymentData);
                                if (context.mounted) Navigator.of(context).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.saleComplete),
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  final printData = _receiptPrintDataFromReceipt(receipt, paymentData);
                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => PopScope(
                                      canPop: false,
                                      child: AlertDialog(
                                        content: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 20),
                                            Text(
                                              l10n.printingTicket,
                                              style: GoogleFonts.inter(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  String? printErr;
                                  try {
                                    printErr = await ref.read(receiptPrinterProvider.notifier).printReceipt(printData);
                                  } catch (_) {
                                    printErr = l10n.printError;
                                  }
                                  if (context.mounted) Navigator.of(context).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          printErr != null
                                              ? '${l10n.saleCompletePrintError}: $printErr'
                                              : l10n.ticketSent,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      backgroundColor: printErr != null
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context).colorScheme.primaryContainer,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            } catch (e, st) {
                                logErrorToConsole(e, st);
                                if (context.mounted) Navigator.of(context).pop();
                                if (context.mounted) {
                                  final msg = e is StateError
                                      ? e.message
                                      : e.toString().replaceFirst(RegExp(r'^[^:]+: '), '');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        msg,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          onPark: () => _showParkDialog(context, ref),
                          onDiscountTap: () => _showDiscountDialog(context, ref),
                          onScanDiscount: () => _scanAndApplyDiscount(context, ref),
                          onRemoveDiscount: () => ref
                              .read(cartControllerProvider.notifier)
                              .removeDiscount(),
                          onRemoveProductDiscountAt: (i) => ref
                              .read(cartControllerProvider.notifier)
                              .removeProductDiscountAt(i),
                          scrollable: true,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _CategoryOrProductsGrid(
                        onProductTap: (context, product) async {
                          // Prefer product that has modifiers when multiple share the same name (e.g. Boli)
                          final byName = await ref
                              .read(posRepositoryProvider)
                              .getProductWithModifiersByName(
                                product.name.trim(),
                                categoryId: product.categoryId,
                              );
                          var productToUse = product;
                          var groups = byName != null
                              ? byName.groups
                              : await ref
                                  .read(posRepositoryProvider)
                                  .getModifierGroupsForProduct(product.id);
                          if (byName != null) productToUse = byName.product;
                          if (!context.mounted) return;
                          if (groups.isEmpty) {
                            ref
                                .read(cartControllerProvider.notifier)
                                .addToCart(productToUse);
                          } else {
                            final result = await showModalBottomSheet<
                                ModifierDialogResult>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => ProductModifierDialog(
                                product: productToUse,
                                modifierGroups: groups,
                              ),
                            );
                            if (result != null && context.mounted) {
                              ref.read(cartControllerProvider.notifier).addToCart(
                                    productToUse,
                                    selectedModifiers: result.modifiers,
                                    quantity: result.quantity,
                                  );
                            }
                          }
                        },
                        onCategoryTap: (category) => ref
                            .read(categoryNavigationControllerProvider.notifier)
                            .pushCategory(category),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _CartSummaryPanel(
                        l10n: l10n,
                        cartState: cartState,
                        receiptAsync: ref.watch(currentReceiptProvider),
                        onRemoveItem: (item) => ref.read(cartControllerProvider.notifier).removeFromCart(item),
                        onCheckout: () async {
                          final receipt = await ref.read(currentReceiptProvider.future);
                          if (receipt.lines.isEmpty) return;
                          if (!context.mounted) return;
                          final paymentData = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (_) => CheckoutDialog(cartTotal: receipt.total, l10n: l10n),
                          );
                          if (paymentData != null && context.mounted) {
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => PopScope(
                                canPop: false,
                                child: AlertDialog(
                                  content: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 20),
                                      Text(
                                        l10n.processingSale,
                                        style: GoogleFonts.inter(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            try {
                              await ref.read(cartControllerProvider.notifier).completeSale(paymentData);
                              if (context.mounted) Navigator.of(context).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.saleComplete),
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                final printData = _receiptPrintDataFromReceipt(receipt, paymentData);
                                showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => PopScope(
                                    canPop: false,
                                    child: AlertDialog(
                                      content: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                          const SizedBox(width: 20),
                                          Text(
                                            l10n.printingTicket,
                                            style: GoogleFonts.inter(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                String? printErr;
                                try {
                                  printErr = await ref.read(receiptPrinterProvider.notifier).printReceipt(printData);
                                } catch (_) {
                                  printErr = l10n.printError;
                                }
                                if (context.mounted) Navigator.of(context).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        printErr != null
                                            ? '${l10n.saleCompletePrintError}: $printErr'
                                            : l10n.ticketSent,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                      backgroundColor: printErr != null
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context).colorScheme.primaryContainer,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            } catch (e, st) {
                              logErrorToConsole(e, st);
                              if (context.mounted) Navigator.of(context).pop();
                              if (context.mounted) {
                                final msg = e is StateError
                                    ? e.message
                                    : e.toString().replaceFirst(RegExp(r'^[^:]+: '), '');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      msg,
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        onPark: () => _showParkDialog(context, ref),
                        onDiscountTap: () => _showDiscountDialog(context, ref),
                        onScanDiscount: () => _scanAndApplyDiscount(context, ref),
                        onRemoveDiscount: () => ref
                            .read(cartControllerProvider.notifier)
                            .removeDiscount(),
                        onRemoveProductDiscountAt: (i) => ref
                            .read(cartControllerProvider.notifier)
                            .removeProductDiscountAt(i),
                        scrollable: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


ReceiptPrintData _receiptPrintDataFromReceipt(
  ReceiptResult receipt,
  Map<String, dynamic> paymentData,
) {
  final method = paymentData['method'] as String? ?? 'cash';
  final amountTendered = (paymentData['amountTendered'] as num?)?.toDouble() ?? 0.0;
  final cardType = paymentData['cardType'] as String?;
  String paymentMethod;
  switch (method) {
    case 'cash':
      paymentMethod = 'CASH';
      break;
    case 'card':
      paymentMethod = cardType == 'credit' ? 'CARD_CREDIT' : 'CARD_DEBIT';
      break;
    case 'transfer':
      paymentMethod = 'TRANSFER';
      break;
    default:
      paymentMethod = 'CASH';
  }
  final changeGiven = method == 'cash' && amountTendered > receipt.total
      ? (amountTendered - receipt.total)
      : 0.0;

  return ReceiptPrintData(
    lines: receipt.lines
        .map((l) => ReceiptPrintLine(
              description: l.description,
              quantity: l.quantity,
              amount: l.amount,
            ))
        .toList(),
    total: receipt.total,
    paymentMethod: paymentMethod,
    amountTendered: amountTendered > 0 ? amountTendered : null,
    changeGiven: changeGiven > 0 ? changeGiven : null,
    storeName: 'Reyes Nieves',
    storeTagline: 'Nieves · Baguettes · Bebidas',
    // storeAddress: 'Tu dirección aquí',
    // storePhone: 'Tel: 123 456 7890',
  );
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
  final codeController = TextEditingController();
  final pctController = TextEditingController();
  final nameContainsController = TextEditingController();
  final labelController = TextEditingController();

  final result = await showDialog<Object>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Descuentos'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Por código',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Código de descuento',
                hintText: 'ej. SCHOOL_CAMPO_VERDE',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final code = await Navigator.push<String>(
                  ctx,
                  MaterialPageRoute<String>(
                    builder: (_) => const QrScannerScreen(),
                  ),
                );
                if (code != null && code.isNotEmpty && ctx.mounted) {
                  codeController.text = code;
                }
              },
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Escanear QR'),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Descuento en producto',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pctController,
              decoration: const InputDecoration(
                labelText: 'Porcentaje (ej. 20)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameContainsController,
              decoration: const InputDecoration(
                labelText: 'Aplicar a productos que contengan',
                hintText: 'ej. nieve',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Etiqueta (opcional, ej. Día de la mujer)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
        OutlinedButton(
          onPressed: () {
            final code = codeController.text.trim();
            if (code.isNotEmpty) Navigator.pop(ctx, _DiscountResultCode(code));
          },
          child: const Text('Aplicar código'),
        ),
        FilledButton(
          onPressed: () {
            final pctStr = pctController.text.trim();
            final nameContains = nameContainsController.text.trim();
            if (nameContains.isEmpty) return;
            final pct = double.tryParse(pctStr);
            if (pct == null || pct <= 0 || pct > 100) return;
            Navigator.pop(ctx, _DiscountResultProduct(
              percentage: pct / 100,
              nameContains: nameContains,
              label: labelController.text.trim().isEmpty
                  ? null
                  : labelController.text.trim(),
            ));
          },
          child: const Text('Descuento en producto'),
        ),
      ],
    ),
  );

  if (!context.mounted) return;
  if (result == null) return;

  if (result is _DiscountResultCode) {
    final ok = await ref.read(cartControllerProvider.notifier).applyDiscount(result.code);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Código aplicado' : 'Código inválido'),
          backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }
  if (result is _DiscountResultProduct) {
    ref.read(cartControllerProvider.notifier).applyProductDiscount(
      nameContains: result.nameContains,
      percentage: result.percentage,
      label: result.label,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Descuento ${(result.percentage * 100).toStringAsFixed(0)}% aplicado a productos que contengan "${result.nameContains}"',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DiscountResultCode {
  const _DiscountResultCode(this.code);
  final String code;
}

class _DiscountResultProduct {
  const _DiscountResultProduct({
    required this.percentage,
    required this.nameContains,
    this.label,
  });
  final double percentage;
  final String nameContains;
  final String? label;
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

class _CategoryBreadcrumbsBar extends StatelessWidget {
  const _CategoryBreadcrumbsBar({
    required this.breadcrumbs,
    required this.onHomeTap,
    required this.onBreadcrumbTap,
    this.onBackTap,
    this.parkedCount = 0,
    this.onRetrieveTap,
  });

  final List<Category> breadcrumbs;
  final VoidCallback onHomeTap;
  final void Function(int index) onBreadcrumbTap;
  final VoidCallback? onBackTap;
  final int parkedCount;
  final VoidCallback? onRetrieveTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (onBackTap != null)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: onBackTap,
                tooltip: 'Back',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onHomeTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '🏠 Home',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    ...breadcrumbs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              ' > ',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onBreadcrumbTap(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                category.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            if (onRetrieveTap != null)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, size: 22),
                    onPressed: onRetrieveTap,
                    tooltip: 'Recuperar ventas pausadas',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                  if (parkedCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                        child: Text(
                          parkedCount > 99 ? '99+' : '$parkedCount',
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

class _CategoryOrProductsGrid extends ConsumerWidget {
  const _CategoryOrProductsGrid({
    required this.onProductTap,
    required this.onCategoryTap,
  });

  final Future<void> Function(BuildContext context, Product product) onProductTap;
  final void Function(Category category) onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childCategoriesAsync = ref.watch(_childCategoriesProvider);
    final productsAsync = ref.watch(_gridProductsProvider);
    final directProductsAsync = ref.watch(_directCategoryProductsProvider);

    return childCategoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (childCategories) {
        if (childCategories.isNotEmpty) {
          return directProductsAsync.when(
            loading: () => _CategoriesGrid(
              categories: childCategories,
              onCategoryTap: onCategoryTap,
            ),
            error: (_, __) => _CategoriesGrid(
              categories: childCategories,
              onCategoryTap: onCategoryTap,
            ),
            data: (directProducts) {
              if (directProducts.isEmpty) {
                return _CategoriesGrid(
                  categories: childCategories,
                  onCategoryTap: onCategoryTap,
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: directProducts.length,
                        itemBuilder: (context, index) => ProductCard(
                          product: directProducts[index],
                          onTap: () => onProductTap(context, directProducts[index]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Opciones',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: childCategories.length,
                        itemBuilder: (context, index) => _CategoryCard(
                          category: childCategories[index],
                          onTap: () => onCategoryTap(childCategories[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
        return productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (products) => _ProductsGrid(
            productsAsync: AsyncValue.data(products),
            onProductTap: onProductTap,
          ),
        );
      },
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({
    required this.categories,
    required this.onCategoryTap,
  });

  final List<Category> categories;
  final void Function(Category category) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.9,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryCard(
            category: category,
            onTap: () => onCategoryTap(category),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  static const _placeholderAsset = 'assets/images/category_placeholder.png';

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = category.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Image.asset(
                          _placeholderAsset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Image.asset(
                        _placeholderAsset,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Text(
                category.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  final c = hex.replaceFirst('#', '');
  if (c.length == 6) {
    return Color(int.parse('FF$c', radix: 16));
  }
  return const Color(0xFF6200EE);
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
    required this.l10n,
    required this.cartState,
    required this.receiptAsync,
    required this.onRemoveItem,
    required this.onCheckout,
    required this.onPark,
    required this.onDiscountTap,
    required this.onScanDiscount,
    required this.onRemoveDiscount,
    required this.onRemoveProductDiscountAt,
    this.scrollable = false,
  });

  final AppLocalizations l10n;
  final CartState cartState;
  final AsyncValue<ReceiptResult> receiptAsync;
  final void Function(CartItem item) onRemoveItem;
  final VoidCallback onCheckout;
  final VoidCallback onPark;
  final VoidCallback onDiscountTap;
  final VoidCallback onScanDiscount;
  final VoidCallback onRemoveDiscount;
  final void Function(int index) onRemoveProductDiscountAt;
  final bool scrollable;

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

    final borderSide = BorderSide(
      color: Theme.of(context).dividerColor,
      width: 1,
    );
    final decoration = BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(
        left: scrollable ? BorderSide.none : borderSide,
        top: scrollable ? borderSide : BorderSide.none,
      ),
    );

    Widget panelContent = Column(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            l10n.cart,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (scrollable)
          receiptAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  l10n.errorLoading,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            data: (_) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      l10n.cartEmpty,
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _buildCartItemTile(
                    context,
                    items[index],
                    onRemove: () => onRemoveItem(items[index]),
                  ),
                ),
              );
            },
          )
        else
          Expanded(
            child: receiptAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              error: (_, __) => Center(
                child: Text(
                  l10n.errorLoading,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
              data: (_) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.cartEmpty,
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _buildCartItemTile(
                    context,
                    items[index],
                    onRemove: () => onRemoveItem(items[index]),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TotalsRow(label: l10n.bundles, value: '\$${bundleTotal.toStringAsFixed(2)}'),
                _TotalsRow(
                  label: l10n.subtotalOther,
                  value: '\$${standaloneSubtotal.toStringAsFixed(2)}',
                ),
                if (cartState.appliedDiscount != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.discountPercent} (${(cartState.appliedDiscount!.percentage * 100).toStringAsFixed(0)}%)',
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
                        tooltip: l10n.removeDiscount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                ...List.generate(cartState.productDiscounts.length, (index) {
                  final rule = cartState.productDiscounts[index];
                  final label = rule.label?.isNotEmpty == true
                      ? '${rule.label}'
                      : "'${rule.nameContains}'";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${(rule.percentage * 100).toStringAsFixed(0)}% ${l10n.productDiscountLabel} $label',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => onRemoveProductDiscountAt(index),
                          tooltip: l10n.removeDiscount,
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.total,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.confirmation_number_outlined),
                          onPressed: onDiscountTap,
                          tooltip: l10n.applyDiscount,
                        ),
                        TextButton.icon(
                          onPressed: onScanDiscount,
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: Text(l10n.scanDiscount),
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
                      tooltip: l10n.park,
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
                          l10n.checkout,
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
      );

    return Container(
      decoration: decoration,
      child: scrollable
          ? SingleChildScrollView(
              child: panelContent,
            )
          : panelContent,
    );
  }

  Widget _buildCartItemTile(
    BuildContext context,
    CartItem item, {
    required VoidCallback onRemove,
  }) {
    final qty = item.quantity;
    final subtotal = item.subtotal;
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.product.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (qty != 1)
            Text(
              '${qty.toStringAsFixed(qty == qty.truncateToDouble() ? 0 : 1)}x',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: item.selectedModifiers.isNotEmpty
          ? Text(
              'Con modificadores',
                              style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: Theme.of(context).colorScheme.error,
            onPressed: onRemove,
            tooltip: 'Quitar del carrito',
          ),
        ],
      ),
    );
  }

}
