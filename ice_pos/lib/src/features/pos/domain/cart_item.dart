import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_display.dart';
import 'package:ice_pos/src/features/pos/domain/modifier_option.dart';

/// Domain model for an item in the cart.
class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.selectedModifiers = const [],
    this.modifierLabels = const [],
  });

  final Product product;
  final double quantity;
  final List<ModifierOption> selectedModifiers;
  /// Etiquetas legibles alineadas con [selectedModifiers] (sabor, tipo, etc.).
  final List<String> modifierLabels;

  /// Serializes for JSON (e.g. Park Order). Preserves product (id, name, price)
  /// and selected modifiers for exact reconstruction.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product': <String, dynamic>{
        'id': product.id,
        'name': product.name,
        'price': product.price,
        if (product.employeePrice != null) 'employeePrice': product.employeePrice,
        if (product.imageUrl != null) 'imageUrl': product.imageUrl,
        'isActive': product.isActive,
        if (product.categoryId != null) 'categoryId': product.categoryId,
      },
      'quantity': quantity,
      'selectedModifiers': selectedModifiers
          .map((m) => ModifierOptionDto.fromModifierOption(m).toJson())
          .toList(),
      if (modifierLabels.isNotEmpty) 'modifierLabels': modifierLabels,
    };
  }

  /// Deserializes from JSON. Reconstructs Product and ModifierOption list.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>?;
    if (productJson == null) {
      throw FormatException('CartItem JSON missing required "product"');
    }
    final empRaw = productJson['employeePrice'];
    final product = Product(
      id: _readInt(productJson, 'id'),
      name: _readString(productJson, 'name'),
      price: _readDouble(productJson, 'price'),
      employeePrice: empRaw == null
          ? null
          : (empRaw is num ? empRaw.toDouble() : double.tryParse(empRaw.toString())),
      imageUrl: productJson['imageUrl'] as String?,
      isActive: productJson['isActive'] as bool? ?? true,
      categoryId: productJson['categoryId'] is int
          ? productJson['categoryId'] as int
          : (productJson['categoryId'] != null
              ? int.tryParse(productJson['categoryId'].toString())
              : null),
    );
    final quantity = _readDouble(json, 'quantity');
    final modifiersJson = json['selectedModifiers'] as List<dynamic>? ?? [];
    final selectedModifiers = modifiersJson
        .map((e) => ModifierOptionDto.fromJson(e as Map<String, dynamic>))
        .map((dto) => dto.toModifierOption())
        .toList();
    final labelsJson = json['modifierLabels'] as List<dynamic>? ?? [];
    final modifierLabels = labelsJson.map((e) => e.toString()).toList();
    return CartItem(
      product: product,
      quantity: quantity,
      selectedModifiers: selectedModifiers,
      modifierLabels: modifierLabels,
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

  /// Base unit price (regular or employee special).
  double basePrice({bool useEmployeePrice = false}) {
    if (useEmployeePrice) {
      return product.employeePrice ?? product.price;
    }
    return product.price;
  }

  /// Pricing: (1) No modifiers: quantity * price.
  /// (2) Boli-style (each modifier = one piece): quantity == selectedModifiers.length → sum over modifiers of (base + priceExtra).
  /// (3) Nieves-style (modifiers = flavor choices for one item): e.g. 3 sabores for 1 Cono Chico → quantity * price (no per-scoop charge).
  double getSubtotal({bool useEmployeePrice = false}) {
    final price = basePrice(useEmployeePrice: useEmployeePrice);
    if (selectedModifiers.isEmpty) {
      return quantity * price;
    }
    final q = quantity;
    final n = selectedModifiers.length;
    if (q > 0 && n == q) {
      // Each modifier is one piece (Boli: 2 flavors = 2 pieces).
      return selectedModifiers.fold<double>(
        0.0,
        (sum, m) => sum + price + m.priceExtra,
      );
    }
    // Modifiers are choices for the item(s), not extra units (Nieves: 3 sabores = 1 cono at 49).
    return q * price +
        selectedModifiers.fold<double>(0.0, (sum, m) => sum + m.priceExtra);
  }

  /// Sum of [priceExtra] for [count] units consumed FIFO from this line when
  /// bundling, after [alreadyBundledUnits] were already allocated to combos.
  static double modifierExtraForConsumedUnits(
    CartItem item,
    double alreadyBundledUnits,
    double count,
  ) {
    if (count <= 0 || item.selectedModifiers.isEmpty) return 0;

    final q = item.quantity;
    final n = item.selectedModifiers.length;
    if (q > 0 && n == q.round()) {
      var sum = 0.0;
      final start = alreadyBundledUnits.floor();
      final end = (alreadyBundledUnits + count).round();
      for (var i = start; i < end && i < n; i++) {
        sum += item.selectedModifiers[i].priceExtra;
      }
      return sum;
    }

    if (q <= 0) return 0;
    final totalExtra =
        item.selectedModifiers.fold<double>(0.0, (s, m) => s + m.priceExtra);
    return totalExtra * (count / q);
  }

  double get subtotal => getSubtotal();

  CartItem copyWith({
    Product? product,
    double? quantity,
    List<ModifierOption>? selectedModifiers,
    List<String>? modifierLabels,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      modifierLabels: modifierLabels ?? this.modifierLabels,
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

/// Etiquetas legibles de modificadores para carrito y ticket.
List<String> cartItemModifierLabels(
  CartItem item, {
  Map<int, String> supplyIdToName = const {},
}) {
  if (item.selectedModifiers.isEmpty) return const [];
  return [
    for (var i = 0; i < item.selectedModifiers.length; i++)
      _modifierLabelAt(item, i, supplyIdToName),
  ];
}

String _modifierLabelAt(CartItem item, int index, Map<int, String> supplyIdToName) {
  if (index < item.modifierLabels.length && item.modifierLabels[index].trim().isNotEmpty) {
    return item.modifierLabels[index].trim();
  }
  final modifier = item.selectedModifiers[index];
  final raw = supplyIdToName[modifier.supplyId] ?? '';
  if (raw.isEmpty) return 'Opción ${modifier.id}';
  return ModifierDisplay.ticketLabel(raw);
}
