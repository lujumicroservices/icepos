/// Discount code types. Extensible for future types.
abstract final class DiscountType {
  static const String percentage = 'percentage';
  static const String employee = 'employee';

  static const List<String> all = [percentage, employee];

  static bool isValid(String type) => all.contains(type);

  static bool isEmployee(String? type) => type == employee;
}
