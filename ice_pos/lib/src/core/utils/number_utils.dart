/// Parses a decimal string (accepts comma or dot as decimal separator).
/// Returns null if the text is null, empty, or not a valid number.
double? parseDecimal(String? text) {
  if (text == null) return null;
  final normalized = text.trim().replaceFirst(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
