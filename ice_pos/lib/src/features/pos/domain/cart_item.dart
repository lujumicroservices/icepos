import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';

/// Domain model for an item in the cart.
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.selectedModifiers = const [],
  });

  final Product product;
  final double quantity;
  final List<ModifierOption> selectedModifiers;

  /// Serializes for JSON (e.g. Park Order). Preserves product (id, name, price)
  /// and selected modifiers for exact reconstruction.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product': <String, dynamic>{
        'id': product.id,
        'name': product.name,
        'price': product.price,
        if (product.imageUrl != null) 'imageUrl': product.imageUrl,
        'isActive': product.isActive,
      },
      'quantity': quantity,
      'selectedModifiers': selectedModifiers
          .map((m) => ModifierOptionDto.fromModifierOption(m).toJson())
          .toList(),
    };
  }

  /// Deserializes from JSON. Reconstructs Product and ModifierOption list.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;
    if (productJson == null) {
      throw FormatException('CartItem JSON missing required "product"');
    }
    final product = Product(
      id: _readInt(productJson, 'id'),
      name: _readString(productJson, 'name'),
      price: _readDouble(productJson, 'price'),
      imageUrl: productJson['imageUrl'] as String?,
      isActive: productJson['isActive'] as bool? ?? true,
    );
    final quantity = _readDouble(json, 'quantity');
    final modifiersJson = json['selectedModifiers'] as List<dynamic>? ?? [];
    final selectedModifiers = modifiersJson
        .map((e) => ModifierOptionDto.fromJson(e as Map<String, dynamic>))
        .map((dto) => dto.toModifierOption())
        .toList();
    return CartItem(
      product: product,
      quantity: quantity,
      selectedModifiers: selectedModifiers,
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) throw FormatException('Missing required key: $key');
    return (v is int) ? v : int.parse(v.toString());
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) throw FormatException('Missing required key: $key');
    return (v is num) ? v.toDouble() : double.parse(v.toString());
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) throw FormatException('Missing required key: $key');
    return v is String ? v : v.toString();
  }

  double get subtotal =>
      quantity *
      (product.price +
          selectedModifiers.fold(0.0, (sum, m) => sum + m.priceExtra));

  CartItem copyWith({
    Product? product,
    double? quantity,
    List<ModifierOption>? selectedModifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product.id == other.product.id &&
          _modifiersEqual(selectedModifiers, other.selectedModifiers);

  bool _modifiersEqual(
    List<ModifierOption> a,
    List<ModifierOption> b,
  ) {
    if (a.length != b.length) return false;
    final aIds = a.map((m) => m.id).toList()..sort();
    final bIds = b.map((m) => m.id).toList()..sort();
    for (var i = 0; i < aIds.length; i++) {
      if (aIds[i] != bIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(product.id, Object.hashAll(selectedModifiers.map((m) => m.id)));
}
