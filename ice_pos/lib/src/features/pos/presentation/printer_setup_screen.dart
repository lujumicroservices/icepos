import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/features/pos/presentation/controllers/receipt_printer_controller.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiptPrinterProvider.notifier).loadBondedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiptPrinterProvider);
    final notifier = ref.read(receiptPrinterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Impresora de tickets',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.lastError!,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (state.selectedPrinter != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.print),
                title: Text(
                  state.selectedPrinter!.name ?? 'Impresora',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Impresora seleccionada'),
                trailing: TextButton(
                  onPressed: () => notifier.selectPrinter(null),
                  child: const Text('Quitar'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.isLoading ? null : () => notifier.loadBondedDevices(),
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth),
            label: Text(state.isLoading ? 'Cargando...' : 'Actualizar lista de impresoras'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'La app muestra impresoras VINCULADAS (emparejadas) en Ajustes → Bluetooth. '
              'No hace falta que estén "conectadas": solo vinculadas. Al imprimir, la app se conecta sola.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Si acabas de vincular la impresora, pulsa "Actualizar lista". Ticket en papel 58mm (JP-58H).',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          if (state.lastError != null && state.lastError!.contains('permiso'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await permission_handler.openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Abrir ajustes de la app'),
              ),
            ),
          if (state.printers.isEmpty && !state.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No se encontraron dispositivos vinculados. Vincula la impresora en Ajustes del sistema → Bluetooth y pulsa "Actualizar lista". Si ya está vinculada, revisa el permiso de Bluetooth de la app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          if (state.printers.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Dispositivos emparejados',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...state.printers.map((BluetoothDevice p) {
              final isSelected = state.selectedPrinter?.address == p.address;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.print,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    p.name ?? p.address ?? 'Impresora',
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    p.address ?? '',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: FilledButton(
                    onPressed: () => notifier.selectPrinter(p),
                    child: Text(isSelected ? 'Seleccionada' : 'Seleccionar'),
                  ),
                ),
              );
            }),
          ],
          if (state.selectedPrinter != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                if (!context.mounted) return;
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => PopScope(
                    canPop: false,
                    child: AlertDialog(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'Imprimiendo...',
                            style: GoogleFonts.inter(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                final err = await notifier.printTest();
                if (context.mounted) Navigator.of(context).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err != null ? 'Error: $err' : 'Ticket de prueba enviado'),
                      backgroundColor: err != null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primaryContainer,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Imprimir ticket de prueba'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
