import 'package:esc_pos_utils_updated/esc_pos_utils_updated.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_print_data.dart';

/// Builds ESC/POS ticket bytes for Bluetooth thermal printers.
/// Default: 58mm paper (e.g. JP-58H). Use [paper58mm: false] for 80mm.
class ReceiptTicketBuilder {
  ReceiptTicketBuilder({this.storeName = 'Reyes Nieves'});

  final String storeName;

  /// [paper58mm] true = 58mm (JP-58H, ~24 chars/line), false = 80mm (~32 chars/line).
  static const bool paper58mm = true;
  static int get _charsPerLine => paper58mm ? 24 : 32;

  /// Column widths for row(): left (desc), right (amount).
  static const int _colLeft = 6, _colRight = 6;

  /// Strip chars that break cheap 58mm ESC/POS printers.
  static String _safe(String s) {
    var out = s
        .replaceAll('·', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N');
    final buf = StringBuffer();
    for (final rune in out.runes) {
      if (rune >= 32 && rune <= 126) {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  /// Returns ESC/POS bytes for the given receipt.
  static Future<List<int>> build(
    ReceiptPrintData data, {
    String? customStoreName,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paper58mm ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);
    final name = _safe(customStoreName ?? data.storeName);
    final lines = <int>[];

    lines.addAll(generator.reset());

    // ----- Encabezado -----
    lines.addAll(generator.text(
      name,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    if (data.storeTagline != null && data.storeTagline!.isNotEmpty) {
      lines.addAll(generator.text(
        _safe(data.storeTagline!),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    lines.addAll(generator.hr(ch: '='));
    lines.addAll(generator.text(
      'Fecha: ${_formatDate(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    if (data.storeAddress != null && data.storeAddress!.isNotEmpty) {
      lines.addAll(generator.text(
        _safe(data.storeAddress!),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    if (data.storePhone != null && data.storePhone!.isNotEmpty) {
      lines.addAll(generator.text(
        _safe(data.storePhone!),
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    lines.addAll(generator.hr());

    // ----- Detalle -----
    lines.addAll(generator.text(
      'DETALLE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    lines.addAll(generator.hr(ch: '-'));

    for (final line in data.lines) {
      final desc = _safe(line.description);
      final qty = line.quantity > 1 ? ' x${line.quantity}' : '';
      final amountStr = _money(line.amount);
      final left = '$desc$qty';
      if (left.length <= _charsPerLine - amountStr.length - 1) {
        lines.addAll(generator.row([
          PosColumn(text: left, width: _colLeft),
          PosColumn(
            text: amountStr,
            width: _colRight,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      } else {
        lines.addAll(generator.text(left));
        lines.addAll(generator.row([
          PosColumn(text: '', width: _colLeft),
          PosColumn(
            text: amountStr,
            width: _colRight,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      }
      for (final detail in line.modifierDetails) {
        final mod = _safe(detail);
        if (mod.isEmpty) continue;
        lines.addAll(generator.text('  > $mod'));
      }
    }

    lines.addAll(generator.hr());

    // ----- Total -----
    lines.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: _colLeft, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _money(data.total),
        width: _colRight,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    // ----- Pago y cambio -----
    if (data.isSplitPayment && data.splitPayments.isNotEmpty) {
      lines.addAll(generator.text(
        'Pago dividido',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
      for (final p in data.splitPayments) {
        lines.addAll(generator.text(
          '${_safe(p.label)}: ${_money(p.amount)}',
          styles: const PosStyles(align: PosAlign.center),
        ));
        if (p.amountTendered != null && p.amountTendered! > 0) {
          lines.addAll(generator.text(
            '  Recibido: ${_money(p.amountTendered!)}',
            styles: const PosStyles(align: PosAlign.center),
          ));
        }
        if (p.changeGiven != null && p.changeGiven! > 0) {
          lines.addAll(generator.text(
            '  CAMBIO: ${_money(p.changeGiven!)}',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ));
        }
      }
    } else if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) {
      lines.addAll(generator.text(
        'Pago: ${_safe(data.paymentMethodLabel)}',
        styles: const PosStyles(align: PosAlign.center),
      ));
      if (data.paymentMethod == 'CASH') {
        if (data.amountTendered != null && data.amountTendered! > 0) {
          lines.addAll(generator.text(
            'Recibido: ${_money(data.amountTendered!)}',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ));
        }
        final change = data.changeGiven ?? 0.0;
        lines.addAll(generator.text(
          'CAMBIO: ${_money(change)}',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ));
      }
    }

    // ----- Pie -----
    lines.addAll(generator.hr(ch: '='));
    lines.addAll(generator.text(
      'Gracias por tu visita,',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    lines.addAll(generator.text(
      'recuerda que siempre hay espacio',
      styles: const PosStyles(align: PosAlign.center),
    ));
    lines.addAll(generator.text(
      'para otra nieve',
      styles: const PosStyles(align: PosAlign.center),
    ));
    lines.addAll(generator.feed(2));
    lines.addAll(generator.cut());

    return lines;
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day/$m/$y  $h:$min';
  }
}
