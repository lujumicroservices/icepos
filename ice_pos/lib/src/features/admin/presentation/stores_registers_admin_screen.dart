import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/connectivity_service.dart';

/// Admin: CRUD de tiendas ([stores]) y cajones ([pos_registers]) en Supabase.
class StoresRegistersAdminScreen extends ConsumerStatefulWidget {
  const StoresRegistersAdminScreen({super.key});

  @override
  ConsumerState<StoresRegistersAdminScreen> createState() => _StoresRegistersAdminScreenState();
}

class _StoresRegistersAdminScreenState extends ConsumerState<StoresRegistersAdminScreen> {
  List<CloudStoreRecord> _stores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!ConnectivityService.instance.isConnected) {
      final offlineMsg = ref.read(appLocalizationsProvider).offlineRequiresInternet;
      setState(() {
        _loading = false;
        _error = offlineMsg;
      });
      return;
    }
    final list = await CloudSyncService.fetchStoresFromCloud();
    if (!mounted) return;
    setState(() {
      _stores = list;
      _loading = false;
    });
  }

  Future<void> _addStore(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storesAdminAddStoreTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.storesAdminStoreNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final (err, _) = await CloudSyncService.insertStoreToCloud(name);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storesAdminSaved)));
      await _load();
    }
  }

  Future<void> _editStore(CloudStoreRecord s, AppLocalizations l10n) async {
    final controller = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storesAdminEditStoreTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.storesAdminStoreNameLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final err = await CloudSyncService.updateStoreToCloud(id: s.id, name: name);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storesAdminSaved)));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storesRegistersAdminTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _addStore(l10n),
        icon: const Icon(Icons.add),
        label: Text(l10n.storesAdminAddStoreTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              : _stores.isEmpty
                  ? Center(child: Text(l10n.storesAdminEmpty))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _stores.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final s = _stores[i];
                        return Card(
                          child: ListTile(
                            title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text(l10n.storesAdminStoreIdLine(s.id)),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editStore(s, l10n),
                            ),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StoreRegistersDetailScreen(store: s),
                              ),
                            ).then((_) => _load()),
                          ),
                        );
                      },
                    ),
    );
  }
}

/// Cajones de una tienda.
class StoreRegistersDetailScreen extends ConsumerStatefulWidget {
  const StoreRegistersDetailScreen({super.key, required this.store});

  final CloudStoreRecord store;

  @override
  ConsumerState<StoreRegistersDetailScreen> createState() => _StoreRegistersDetailScreenState();
}

class _StoreRegistersDetailScreenState extends ConsumerState<StoreRegistersDetailScreen> {
  List<CloudPosRegisterRecord> _registers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await CloudSyncService.fetchRegistersForStore(widget.store.id, activeOnly: false);
    if (!mounted) return;
    setState(() {
      _registers = list;
      _loading = false;
    });
  }

  Future<void> _addRegister(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storesAdminAddRegisterTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.storesAdminRegisterLabelHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    final nextOrder = _registers.isEmpty ? 0 : _registers.map((r) => r.displayOrder).reduce((a, b) => a > b ? a : b) + 1;
    final (err, _) = await CloudSyncService.insertRegisterToCloud(
      storeId: widget.store.id,
      label: label,
      displayOrder: nextOrder,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storesAdminSaved)));
      await _load();
    }
  }

  Future<void> _editRegister(CloudPosRegisterRecord r, AppLocalizations l10n) async {
    final labelCtrl = TextEditingController(text: r.label);
    final orderCtrl = TextEditingController(text: '${r.displayOrder}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storesAdminEditRegisterTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(labelText: l10n.storesAdminRegisterLabelHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: orderCtrl,
              decoration: InputDecoration(labelText: l10n.storesAdminDisplayOrderLabel),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.apply)),
        ],
      ),
    );
    if (ok != true) return;
    final order = int.tryParse(orderCtrl.text.trim());
    final err = await CloudSyncService.updateRegisterToCloud(
      id: r.id,
      label: labelCtrl.text.trim(),
      displayOrder: order,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storesAdminSaved)));
      await _load();
    }
  }

  Future<void> _toggleActive(CloudPosRegisterRecord r, AppLocalizations l10n) async {
    final err = await CloudSyncService.updateRegisterToCloud(id: r.id, active: !r.active);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.store.name} · ${l10n.storesAdminRegistersSubtitle}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _addRegister(l10n),
        icon: const Icon(Icons.add),
        label: Text(l10n.storesAdminAddRegisterTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _registers.isEmpty
              ? Center(child: Text(l10n.storesAdminNoRegisters))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _registers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _registers[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${l10n.storesAdminRegisterIdLine(r.id)} · ${l10n.storesAdminOrderLabel} ${r.displayOrder} · '
                          '${r.active ? l10n.storesAdminActive : l10n.storesAdminInactive}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(r.active ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => _toggleActive(r, l10n),
                              tooltip: r.active ? l10n.storesAdminDeactivate : l10n.storesAdminActivate,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editRegister(r, l10n),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
