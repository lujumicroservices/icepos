import 'package:ice_pos/src/core/database/app_database.dart';

/// Serializable representation of a modifier option for JSON (e.g. Park Order).
/// Mirrors the Drift ModifierOption structure for round-trip serialization.
class ModifierOptionDto {
  const ModifierOptionDto({
    required this.id,
    required this.modifierGroupId,
    required this.supplyId,
    required this.quantityDeducted,
    required this.priceExtra,
  });

  final int id;
  final int modifierGroupId;
  final int supplyId;
  final double quantityDeducted;
  final double priceExtra;

  factory ModifierOptionDto.fromJson(Map<String, dynamic> json) {
    return ModifierOptionDto(
      id: _readInt(json, 'id'),
      modifierGroupId: _readInt(json, 'modifierGroupId'),
      supplyId: _readInt(json, 'supplyId'),
      quantityDeducted: _readDouble(json, 'quantityDeducted'),
      priceExtra: _readDouble(json, 'priceExtra'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'modifierGroupId': modifierGroupId,
      'supplyId': supplyId,
      'quantityDeducted': quantityDeducted,
      'priceExtra': priceExtra,
    };
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

  /// Converts to Drift ModifierOption for use in cart/processSale.
  ModifierOption toModifierOption() {
    return ModifierOption(
      id: id,
      modifierGroupId: modifierGroupId,
      supplyId: supplyId,
      quantityDeducted: quantityDeducted,
      priceExtra: priceExtra,
    );
  }

  /// Creates from Drift ModifierOption for serialization.
  factory ModifierOptionDto.fromModifierOption(ModifierOption m) {
    return ModifierOptionDto(
      id: m.id,
      modifierGroupId: m.modifierGroupId,
      supplyId: m.supplyId,
      quantityDeducted: m.quantityDeducted,
      priceExtra: m.priceExtra,
    );
  }
}
