import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/constants/supply_units.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/l10n/app_localizations.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/utils/number_utils.dart';
import 'package:ice_pos/src/core/widgets/list_search_bar.dart';
import 'package:ice_pos/src/features/inventory/domain/inventory_qualitative.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsReconciliationSupplyId = 'inventory_reconciliation_supply_id';

typedef _SupplyGroup = ({String name, List<Supply> supplies});

/// Lista fresca tras cada guardado (evita condiciones de carrera con streams).
final _reconciliationGroupsProvider =
    FutureProvider.autoDispose<List<_SupplyGroup>>((ref) async {
  return ref.read(posRepositoryProvider).getSuppliesGroupedByCategory();
});

final _reconciliationSearchQueryProvider = StateProvider<String>((ref) => '');

/// Coincidencias globales: nombre de insumo, grupo o categoría del insumo.
List<({String groupName, Supply supply})> _globalSearchMatches(
  List<_SupplyGroup> groups,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final out = <({String groupName, Supply supply})>[];
  for (final g in groups) {
    for (final s in g.supplies) {
      if (s.name.toLowerCase().contains(q)) {
        out.add((groupName: g.name, supply: s));
        continue;
      }
      if (g.name.toLowerCase().contains(q)) {
        out.add((groupName: g.name, supply: s));
        continue;
      }
      final cat = s.category?.trim().toLowerCase();
      if (cat != null && cat.isNotEmpty && cat.contains(q)) {
        out.add((groupName: g.name, supply: s));
      }
    }
  }
  return out;
}

class InventoryReconciliationScreen extends ConsumerStatefulWidget {
  const InventoryReconciliationScreen({super.key});

  @override
  ConsumerState<InventoryReconciliationScreen> createState() =>
      _InventoryReconciliationScreenState();
}

class _InventoryReconciliationScreenState
    extends ConsumerState<InventoryReconciliationScreen> {
  int _groupIndex = 0;
  int _indexInGroup = 0;
  bool _progressRestored = false;

  int _totalSupplies(List<_SupplyGroup> groups) {
    var n = 0;
    for (final g in groups) {
      n += g.supplies.length;
    }
    return n;
  }

  /// Índice global 0..total-1 del insumo actual.
  int _flatIndex(List<_SupplyGroup> groups, int g, int i) {
    var sum = 0;
    for (var j = 0; j < g; j++) {
      sum += groups[j].supplies.length;
    }
    return sum + i;
  }

  void _syncIndicesIfNeeded(List<_SupplyGroup> groups) {
    if (groups.isEmpty) return;
    final g = _groupIndex.clamp(0, groups.length - 1);
    final supplies = groups[g].supplies;
    if (supplies.isEmpty) return;
    final i = _indexInGroup.clamp(0, supplies.length - 1);
    if (g != _groupIndex || i != _indexInGroup) {
      setState(() {
        _groupIndex = g;
        _indexInGroup = i;
      });
    }
  }

  Future<void> _persistCurrentSupplyId(int supplyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefsReconciliationSupplyId, supplyId);
    } catch (_) {}
  }

  Future<void> _clearSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsReconciliationSupplyId);
    } catch (_) {}
  }

  Future<void> _restoreProgress(List<_SupplyGroup> groups) async {
    if (groups.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = prefs.getInt(_kPrefsReconciliationSupplyId);
      if (sid == null) {
        final first = groups.first.supplies.isNotEmpty
            ? groups.first.supplies.first
            : null;
        if (first != null) await _persistCurrentSupplyId(first.id);
        return;
      }
      for (var g = 0; g < groups.length; g++) {
        final list = groups[g].supplies;
        final idx = list.indexWhere((s) => s.id == sid);
        if (idx >= 0) {
          if (!mounted) return;
          setState(() {
            _groupIndex = g;
            _indexInGroup = idx;
          });
          return;
        }
      }
    } catch (_) {}
  }

  void _jumpToSupply(List<_SupplyGroup> groups, int supplyId) {
    for (var g = 0; g < groups.length; g++) {
      final list = groups[g].supplies;
      final idx = list.indexWhere((s) => s.id == supplyId);
      if (idx >= 0) {
        setState(() {
          _groupIndex = g;
          _indexInGroup = idx;
        });
        _persistCurrentSupplyId(supplyId);
        ref.read(_reconciliationSearchQueryProvider.notifier).state = '';
        return;
      }
    }
  }

  void _goToGroup(List<_SupplyGroup> groups, int newGroupIndex) {
    if (newGroupIndex < 0 || newGroupIndex >= groups.length) return;
    final supplies = groups[newGroupIndex].supplies;
    if (supplies.isEmpty) return;
    setState(() {
      _groupIndex = newGroupIndex;
      _indexInGroup = 0;
    });
    _persistCurrentSupplyId(supplies.first.id);
  }

  void _nextSupplyOrGroup(List<_SupplyGroup> groups) {
    final gi = _groupIndex.clamp(0, groups.length - 1);
    final supplies = groups[gi].supplies;
    if (_indexInGroup + 1 < supplies.length) {
      setState(() => _indexInGroup++);
      _persistCurrentSupplyId(supplies[_indexInGroup].id);
      return;
    }
    if (gi + 1 < groups.length) {
      final next = groups[gi + 1].supplies;
      if (next.isEmpty) return;
      setState(() {
        _groupIndex = gi + 1;
        _indexInGroup = 0;
      });
      _persistCurrentSupplyId(next.first.id);
    }
  }

  void _previousSupplyOrGroup(List<_SupplyGroup> groups) {
    final gi = _groupIndex.clamp(0, groups.length - 1);
    final supplies = groups[gi].supplies;
    if (_indexInGroup > 0) {
      setState(() => _indexInGroup--);
      _persistCurrentSupplyId(supplies[_indexInGroup].id);
      return;
    }
    if (gi > 0) {
      final prev = groups[gi - 1].supplies;
      if (prev.isEmpty) return;
      setState(() {
        _groupIndex = gi - 1;
        _indexInGroup = prev.length - 1;
      });
      _persistCurrentSupplyId(prev[_indexInGroup].id);
    }
  }

  Future<void> _confirmRestart(AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.reconcileRestartConfirmTitle),
        content: Text(l10n.reconcileRestartConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.reconcileRestart),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _clearSavedProgress();
    if (!mounted) return;
    setState(() {
      _groupIndex = 0;
      _indexInGroup = 0;
    });
    ref.read(_reconciliationGroupsProvider).when(
          data: (groups) {
            if (groups.isEmpty) return;
            final first = groups.first.supplies;
            if (first.isNotEmpty) {
              _persistCurrentSupplyId(first.first.id);
            }
          },
          loading: () {},
          error: (_, _) {},
        );
  }

  void _showGroupPicker(List<_SupplyGroup> groups, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.reconcileSelectGroup,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final g = groups[index];
                  return ListTile(
                    title: Text(g.name),
                    subtitle: Text('${g.supplies.length}'),
                    selected: index == _groupIndex,
                    onTap: () {
                      Navigator.pop(ctx);
                      _goToGroup(groups, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(_reconciliationGroupsProvider);
    final searchQ = ref.watch(_reconciliationSearchQueryProvider);

    ref.listen(_reconciliationGroupsProvider, (prev, next) {
      next.whenData((groups) {
        if (!mounted || groups.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncIndicesIfNeeded(groups);
        });
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.inventoryReconciliation,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'restart') _confirmRestart(l10n);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'restart',
                child: Text(l10n.reconcileRestart),
              ),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (groups) {
          if (!_progressRestored) {
            _progressRestored = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _restoreProgress(groups);
              if (mounted) _syncIndicesIfNeeded(groups);
            });
          }

          if (groups.isEmpty) {
            return Center(
              child: Text(
                l10n.reconcileEmpty,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final gi = _groupIndex.clamp(0, groups.length - 1);
          final section = groups[gi];
          final supplies = section.supplies;
          if (supplies.isEmpty) {
            return Center(child: Text(l10n.reconcileEmpty));
          }
          final ii = _indexInGroup.clamp(0, supplies.length - 1);
          final supply = supplies[ii];
          final total = _totalSupplies(groups);
          final flat = _flatIndex(groups, gi, ii);
          final atEnd = gi + 1 >= groups.length && ii + 1 >= supplies.length;
          final searchMatches = _globalSearchMatches(groups, searchQ);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListSearchBar(
                queryProvider: _reconciliationSearchQueryProvider,
                hintText: l10n.reconcileSearchHint,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              ),
              if (searchQ.trim().isNotEmpty) ...[
                if (searchMatches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      l10n.reconcileSearchNoResults,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: searchMatches.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = searchMatches[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                m.supply.name,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                m.groupName,
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              onTap: () => _jumpToSupply(groups, m.supply.id),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.reconcilePreviousGroup,
                      onPressed: gi > 0 ? () => _goToGroup(groups, gi - 1) : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showGroupPicker(groups, l10n),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.reconcileGroupLabel(section.name),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.reconcileGroupsCounter(gi + 1, groups.length),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.reconcileNextGroup,
                      onPressed: gi < groups.length - 1
                          ? () => _goToGroup(groups, gi + 1)
                          : null,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total > 0 ? (flat + 1) / total : 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.reconcileOverallCounter(flat + 1, total),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          l10n.reconcileInGroupCounter(ii + 1, supplies.length),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _ReconciliationStep(
                    key: ValueKey(supply.id),
                    supply: supply,
                    l10n: l10n,
                    onContinue: () {
                      _nextSupplyOrGroup(groups);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        ref.invalidate(_reconciliationGroupsProvider);
                      });
                    },
                    onSkip: () => _nextSupplyOrGroup(groups),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: gi == 0 && ii == 0
                          ? null
                          : () => _previousSupplyOrGroup(groups),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.goBack),
                    ),
                    const Spacer(),
                    if (atEnd)
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.check),
                        label: Text(l10n.reconcileDone),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReconciliationStep extends ConsumerStatefulWidget {
  const _ReconciliationStep({
    super.key,
    required this.supply,
    required this.l10n,
    required this.onContinue,
    required this.onSkip,
  });

  final Supply supply;
  final AppLocalizations l10n;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  ConsumerState<_ReconciliationStep> createState() =>
      _ReconciliationStepState();
}

class _ReconciliationStepState extends ConsumerState<_ReconciliationStep> {
  late final TextEditingController _qtyController;
  late String _selectedUnit;
  String? _selectedLevel;
  bool _saving = false;

  /// Chips vs cantidad: unidad [qual], o insumo cualitativo sin cambiar la unidad aún.
  bool get _useQualitativeUi =>
      _selectedUnit == kQualitativeUnitMarker ||
      (widget.supply.stockCountMode == StockCountMode.qualitative &&
          _selectedUnit == widget.supply.unit);

  @override
  void initState() {
    super.initState();
    final s = widget.supply;
    var u = s.unit.trim();
    if (u.isEmpty) u = kSupplyUnitOptions.first;
    final unitChoices = supplyUnitDropdownItems(s.unit);
    _selectedUnit = unitChoices.contains(u) ? u : unitChoices.first;

    if (_useQualitativeUi) {
      final stored = s.qualitativeLevel;
      if (stored == QualitativeLevel.resurtir) {
        _selectedLevel = QualitativeLevel.critico;
      } else if (QualitativeLevel.isValid(stored)) {
        _selectedLevel = stored;
      } else {
        _selectedLevel = QualitativeLevel.medio;
      }
      _qtyController = TextEditingController();
    } else {
      _selectedLevel = null;
      _qtyController = TextEditingController(
        text: _formatQty(s.currentStock),
      );
    }
  }

  @override
  void didUpdateWidget(_ReconciliationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.supply.id != oldWidget.supply.id) return;
    if (_useQualitativeUi) return;
    if (widget.supply.currentStock != oldWidget.supply.currentStock) {
      _qtyController.text = _formatQty(widget.supply.currentStock);
    }
  }

  String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  /// Garantiza que el valor del [DropdownButton] exista entre las opciones.
  String get _unitDropdownValue {
    final choices = supplyUnitDropdownItems(widget.supply.unit);
    if (choices.contains(_selectedUnit)) return _selectedUnit;
    return choices.first;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  String _levelLabel(String code) {
    final l10n = widget.l10n;
    switch (code) {
      case QualitativeLevel.alto:
        return l10n.qualitativeLevelAlto;
      case QualitativeLevel.medio:
        return l10n.qualitativeLevelMedio;
      case QualitativeLevel.bajo:
        return l10n.qualitativeLevelBajo;
      case QualitativeLevel.critico:
      case QualitativeLevel.resurtir:
        return l10n.qualitativeLevelCritico;
      default:
        return code;
    }
  }

  Widget _unitMenuItemLabel(String u) {
    if (u == kQualitativeUnitMarker) {
      return Text(widget.l10n.qualitativeUnitOption);
    }
    return Text(u);
  }

  Future<void> _save() async {
    final l10n = widget.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final useQual = _selectedUnit == kQualitativeUnitMarker ||
        (widget.supply.stockCountMode == StockCountMode.qualitative &&
            _selectedUnit == widget.supply.unit);

    setState(() => _saving = true);
    try {
      String? cloudErr;
      if (useQual) {
        final level = _selectedLevel;
        if (level == null || !QualitativeLevel.isValid(level)) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.reconcileSelectLevel)),
          );
          return;
        }
        cloudErr = await ref.read(posRepositoryProvider).reconcileSupply(
              supplyId: widget.supply.id,
              qualitativeLevel: level,
              newUnit: _selectedUnit,
              useQualitativeEntry: true,
            );
      } else {
        final parsed = parseDecimal(_qtyController.text);
        if (parsed == null || parsed < 0) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.validAmount)));
          return;
        }
        cloudErr = await ref.read(posRepositoryProvider).reconcileSupply(
              supplyId: widget.supply.id,
              newQuantity: parsed,
              newUnit: _selectedUnit,
              useQualitativeEntry: false,
            );
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.reconcileSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (cloudErr != null && cloudErr.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${l10n.reconcileCloudSyncFailed}$cloudErr'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
      widget.onContinue();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final s = widget.supply;
    final isQual = _useQualitativeUi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.name,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isQual
              ? l10n.reconcileModeQualitativeHint
              : l10n.reconcileModeQuantityHint,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.reconcileUnitLabel,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _unitDropdownValue,
              isExpanded: true,
              items: supplyUnitDropdownItems(s.unit)
                  .map(
                    (u) => DropdownMenuItem<String>(
                      value: u,
                      child: _unitMenuItemLabel(u),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _selectedUnit = v ?? _selectedUnit;
                        if (_useQualitativeUi) {
                          _selectedLevel ??= QualitativeLevel.medio;
                        } else {
                          _qtyController.text =
                              _formatQty(widget.supply.currentStock);
                        }
                      });
                    },
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!isQual) ...[
          Text(
            l10n.reconcileCurrentStock(
              _formatQty(s.currentStock),
              s.unit,
            ),
            style: GoogleFonts.inter(fontSize: 15),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.reconcileCountedQuantity,
              border: const OutlineInputBorder(),
              suffixText: _selectedUnit,
            ),
          ),
        ] else ...[
          Text(
            l10n.reconcileCurrentLevel(
              s.qualitativeLevel != null
                  ? _levelLabel(s.qualitativeLevel!)
                  : '—',
            ),
            style: GoogleFonts.inter(fontSize: 15),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.reconcileSelectLevel,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QualitativeLevel.all.map((code) {
              final selected = _selectedLevel == code;
              return ChoiceChip(
                label: Text(_levelLabel(code)),
                selected: selected,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _selectedLevel = code),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : widget.onSkip,
                child: Text(l10n.reconcileSkip),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.reconcileSaveAndContinue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
