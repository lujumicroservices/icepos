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
  /// Column widths for row(): left (desc), right (amount). Same for items and total so prices align.
  static const int _colLeft = 6, _colRight = 6;

  /// Returns ESC/POS bytes for the given receipt.
  static Future<List<int>> build(
    ReceiptPrintData data, {
    String? customStoreName,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paper58mm ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);
    final name = customStoreName ?? data.storeName;
    final lines = <int>[];

    // ----- Encabezado -----
    lines.addAll(generator.text(
      name,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 0,
    ));
    if (data.storeTagline != null && data.storeTagline!.isNotEmpty) {
      lines.addAll(generator.text(
        data.storeTagline!,
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 0,
      ));
    }
    lines.addAll(generator.hr(ch: '=', linesAfter: 0));
    lines.addAll(generator.text(
      'Fecha: ${_formatDate(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 0,
    ));
    if (data.storeAddress != null && data.storeAddress!.isNotEmpty) {
      lines.addAll(generator.text(
        data.storeAddress!,
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 0,
      ));
    }
    if (data.storePhone != null && data.storePhone!.isNotEmpty) {
      lines.addAll(generator.text(
        data.storePhone!,
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 0,
      ));
    }
    lines.addAll(generator.hr(linesAfter: 0));

    // ----- Detalle (precio alineado a la derecha con el total) -----
    lines.addAll(generator.text(
      'DETALLE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
      linesAfter: 0,
    ));
    lines.addAll(generator.hr(ch: '-', linesAfter: 0));

    for (final line in data.lines) {
      final desc = line.description;
      final qty = line.quantity > 1 ? ' x${line.quantity}' : '';
      final amountStr = '\$${line.amount.toStringAsFixed(2)}';
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
        lines.addAll(generator.text(left, linesAfter: 0));
        lines.addAll(generator.row([
          PosColumn(text: '', width: _colLeft),
          PosColumn(
            text: amountStr,
            width: _colRight,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      }
    }

    lines.addAll(generator.hr(linesAfter: 0));

    // ----- Total (misma columna derecha que los productos) -----
    lines.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: _colLeft, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '\$${data.total.toStringAsFixed(2)}',
        width: _colRight,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    // ----- Pago -----
    if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) {
      lines.addAll(generator.text(
        'Forma de pago: ${data.paymentMethodLabel}',
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 0,
      ));
      if (data.amountTendered != null && data.amountTendered! > 0) {
        lines.addAll(generator.text(
          'Recibido: \$${data.amountTendered!.toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.center),
          linesAfter: 0,
        ));
      }
      if (data.changeGiven != null && data.changeGiven! > 0) {
        lines.addAll(generator.text(
          'Cambio: \$${data.changeGiven!.toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.center, bold: true),
          linesAfter: 0,
        ));
      }
    }

    // ----- Pie -----
    lines.addAll(generator.hr(ch: '=', linesAfter: 0));
    lines.addAll(generator.text(
      'Gracias por tu visita,',
      styles: const PosStyles(align: PosAlign.center, bold: true),
      linesAfter: 0,
    ));
    lines.addAll(generator.text(
      'recuerda que siempre hay espacio para otra nieve',
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 1,
    ));
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
