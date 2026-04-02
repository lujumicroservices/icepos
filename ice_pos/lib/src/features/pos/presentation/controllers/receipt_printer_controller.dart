import 'dart:typed_data';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/features/pos/data/receipt_ticket_builder.dart';
import 'package:ice_pos/src/features/pos/domain/receipt_print_data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSavedPrinterAddress = 'receipt_printer_address';

final receiptPrinterProvider =
    NotifierProvider<ReceiptPrinterNotifier, ReceiptPrinterState>(
  ReceiptPrinterNotifier.new,
);

class ReceiptPrinterNotifier extends Notifier<ReceiptPrinterState> {
  static BlueThermalPrinter get _bt => BlueThermalPrinter.instance;

  @override
  ReceiptPrinterState build() {
    return const ReceiptPrinterState(
      printers: [],
      selectedPrinter: null,
      isLoading: false,
      lastError: null,
    );
  }

  /// Load bonded (paired) Bluetooth devices. Uses Android's list of VINCULADOS/emparejados
  /// (no need for device to be "connected" — the app will connect when printing).
  Future<void> loadBondedDevices() async {
    if (kIsWeb) {
      state = state.copyWith(isLoading: false, lastError: null);
      return;
    }
    state = state.copyWith(isLoading: true, lastError: null);
    try {
      // Android 12+ needs BLUETOOTH_CONNECT to read bonded devices; older may use bluetooth.
      var granted = await Permission.bluetoothConnect.isGranted;
      if (!granted) {
        final status = await Permission.bluetoothConnect.request();
        granted = status.isGranted;
      }
      if (!granted) {
        final legacy = await Permission.bluetooth.request();
        granted = legacy.isGranted;
      }
      if (!granted) {
        state = state.copyWith(
          isLoading: false,
          lastError: 'Se necesita permiso de Bluetooth para ver dispositivos vinculados. '
              'Concede el permiso en Ajustes de la app y vuelve a intentar.',
        );
        return;
      }
      final list = await _bt.getBondedDevices();
      BluetoothDevice? restored;
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedAddress = prefs.getString(_kSavedPrinterAddress);
        if (savedAddress != null && savedAddress.isNotEmpty) {
          for (final d in list) {
            if (d.address == savedAddress) {
              restored = d;
              break;
            }
          }
        }
      } catch (_) {}
      state = state.copyWith(
        printers: list,
        isLoading: false,
        lastError: null,
        selectedPrinter: restored ?? state.selectedPrinter,
      );
    } catch (e, st) {
      debugPrint('Load bonded devices error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        lastError: e.toString().replaceFirst(RegExp(r'^[^:]+: '), ''),
      );
    }
  }

  Future<void> selectPrinter(BluetoothDevice? printer) async {
    state = state.copyWith(selectedPrinter: printer);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (printer != null) {
        await prefs.setString(_kSavedPrinterAddress, printer.address ?? '');
      } else {
        await prefs.remove(_kSavedPrinterAddress);
      }
    } catch (_) {}
  }

  /// Print a receipt. Connects to selected device, sends bytes, then disconnects.
  /// Retries up to [maxRetries] times with increasing delay (some printers are flaky over Bluetooth).
  Future<String?> printReceipt(ReceiptPrintData data, {int maxRetries = 5}) async {
    final device = state.selectedPrinter;
    if (device == null) {
      return 'Selecciona una impresora primero (menú → Impresora).';
    }
    final bytes = await ReceiptTicketBuilder.build(data);
    // Pausa antes del primer intento (algunas tablets necesitan más tiempo).
    await Future<void>.delayed(const Duration(milliseconds: 800));
    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _bt.connect(device);
        try {
          await _bt.writeBytes(Uint8List.fromList(bytes));
          // Esperar antes de desconectar: en algunas tablets cerrar el socket
          // demasiado pronto corta el envío; dar tiempo a que la impresora reciba todo.
          await Future<void>.delayed(const Duration(milliseconds: 700));
          state = state.copyWith(lastError: null);
          return null;
        } finally {
          await _bt.disconnect();
        }
      } catch (e, st) {
        debugPrint('Print attempt $attempt/$maxRetries failed: $e\n$st');
        lastError = e;
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }
    final err = _userFriendlyPrintError(lastError);
    state = state.copyWith(lastError: err);
    return err;
  }

  static String _userFriendlyPrintError(Object? e) {
    if (e == null) return 'Error al imprimir.';
    final s = e.toString();
    if (s.contains('socket') || s.contains('timeout') || s.contains('connect')) {
      return 'No se pudo conectar. Comprueba que la impresora esté encendida, cerca y vuelve a intentar.';
    }
    if (s.length > 80) return 'Error al imprimir. Revisa la impresora.';
    return s.replaceFirst(RegExp(r'^[^:]+: '), '');
  }

  Future<String?> printTest() async {
    final data = ReceiptPrintData(
      lines: [
        const ReceiptPrintLine(description: 'Ticket de prueba', quantity: 1, amount: 0),
      ],
      total: 0,
      storeName: 'Reyes Nieves',
      storeTagline: 'Nieves · Baguettes · Bebidas',
    );
    return printReceipt(data);
  }
}

class ReceiptPrinterState {
  const ReceiptPrinterState({
    required this.printers,
    this.selectedPrinter,
    required this.isLoading,
    this.lastError,
  });

  final List<BluetoothDevice> printers;
  final BluetoothDevice? selectedPrinter;
  final bool isLoading;
  final String? lastError;

  static const _keep = _Keep();

  ReceiptPrinterState copyWith({
    List<BluetoothDevice>? printers,
    Object? selectedPrinter = _keep,
    bool? isLoading,
    Object? lastError = _keep,
  }) {
    return ReceiptPrinterState(
      printers: printers ?? this.printers,
      selectedPrinter: identical(selectedPrinter, _keep) ? this.selectedPrinter : selectedPrinter as BluetoothDevice?,
      isLoading: isLoading ?? this.isLoading,
      lastError: identical(lastError, _keep) ? this.lastError : lastError as String?,
    );
  }
}

class _Keep {
  const _Keep();
}
