/// Parses amounts from Spanish transcripts (digits + common words).
class SpanishAmountParser {
  const SpanishAmountParser._();

  static double? parse(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[,$]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final digitMatches = RegExp(r'(\d+(?:[.,]\d+)*)').allMatches(normalized);
    double? best;
    for (final m in digitMatches) {
      var raw = m.group(1)!;
      if (raw.contains(',') && raw.contains('.')) {
        raw = raw.replaceAll(',', '');
      } else if (RegExp(r',\d{3}').hasMatch(raw)) {
        raw = raw.replaceAll(',', '');
      } else if (RegExp(r'\.\d{3}').hasMatch(raw) && !RegExp(r'\.\d{1,2}$').hasMatch(raw)) {
        raw = raw.replaceAll('.', '');
      } else if (raw.contains(',')) {
        final parts = raw.split(',');
        raw = parts.length == 2 && parts[1].length <= 2
            ? '${parts[0]}.${parts[1]}'
            : raw.replaceAll(',', '');
      }
      final v = double.tryParse(raw);
      if (v != null && v > 0 && (best == null || v > best)) best = v;
    }
    if (best != null) return best;

    return _parseWords(normalized);
  }

  static double? _parseWords(String text) {
    const units = <String, int>{
      'un': 1,
      'uno': 1,
      'una': 1,
      'dos': 2,
      'tres': 3,
      'cuatro': 4,
      'cinco': 5,
      'seis': 6,
      'siete': 7,
      'ocho': 8,
      'nueve': 9,
      'diez': 10,
      'once': 11,
      'doce': 12,
      'trece': 13,
      'catorce': 14,
      'quince': 15,
      'veinte': 20,
      'treinta': 30,
      'cuarenta': 40,
      'cincuenta': 50,
      'sesenta': 60,
      'setenta': 70,
      'ochenta': 80,
      'noventa': 90,
      'cien': 100,
      'ciento': 100,
      'doscientos': 200,
      'trescientos': 300,
      'cuatrocientos': 400,
      'quinientos': 500,
      'seiscientos': 600,
      'setecientos': 700,
      'ochocientos': 800,
      'novecientos': 900,
    };

    final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    var total = 0.0;
    var found = false;

    for (final token in tokens) {
      if (token == 'mil') {
        found = true;
        total = total == 0 ? 1000 : total * 1000;
        continue;
      }
      final v = units[token];
      if (v != null) {
        found = true;
        total += v;
      }
    }

    return found && total > 0 ? total : null;
  }
}
