import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';
import 'package:ice_pos/src/features/pos/domain/product_discount_rule.dart';

/// Cart state including items, optional code discount, and product-based discounts.
class CartState {
  const CartState({
    this.items = const [],
    this.appliedDiscount,
    this.productDiscounts = const [],
  });

  final List<CartItem> items;
  final Discount? appliedDiscount;
  final List<ProductDiscountRule> productDiscounts;

  CartState copyWith({
    List<CartItem>? items,
    Discount? appliedDiscount,
    bool clearDiscount = false,
    List<ProductDiscountRule>? productDiscounts,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedDiscount: clearDiscount ? null : (appliedDiscount ?? this.appliedDiscount),
      productDiscounts: productDiscounts ?? this.productDiscounts,
    );
  }
}
