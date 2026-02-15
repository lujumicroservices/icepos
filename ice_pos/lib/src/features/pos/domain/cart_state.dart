import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/cart_item.dart';

/// Cart state including items and optional applied discount.
class CartState {
  const CartState({
    this.items = const [],
    this.appliedDiscount,
  });

  final List<CartItem> items;
  final Discount? appliedDiscount;

  CartState copyWith({
    List<CartItem>? items,
    Discount? appliedDiscount,
    bool clearDiscount = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedDiscount: clearDiscount ? null : (appliedDiscount ?? this.appliedDiscount),
    );
  }
}
