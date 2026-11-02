import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/temperature_alert_settings_service.dart';

final tempAlertSettingsProvider =
    FutureProvider.autoDispose<List<TemperatureAlertSetting>>((ref) async {
  return TemperatureAlertSettingsService.fetchAll();
});

/// Admin UI to edit per-freezer temperature alert thresholds.
class TemperatureAlertSettingsScreen extends ConsumerStatefulWidget {
  const TemperatureAlertSettingsScreen({super.key});

  @override
  ConsumerState<TemperatureAlertSettingsScreen> createState() =>
      _TemperatureAlertSettingsScreenState();
}

class _TemperatureAlertSettingsScreenState
    extends ConsumerState<TemperatureAlertSettingsScreen> {
  bool _saving = false;

  Future<void> _save(TemperatureAlertSetting setting) async {
    final l10n = ref.read(appLocalizationsProvider);
    setState(() => _saving = true);
    try {
      await TemperatureAlertSettingsService.upsert(setting);
      ref.invalidate(tempAlertSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.temperatureAlertSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocalizationsProvider);
    final async = ref.watch(tempAlertSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.temperatureAlertSettings)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.temperatureAlertSettingsEmpty,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              final title = s.freezerKey == 'freezer1'
                  ? l10n.temperatureFreezer1
                  : s.freezerKey == 'freezer2'
                      ? l10n.temperatureFreezer2
                      : s.freezerKey;
              return _SettingCard(
                key: ValueKey('${s.freezerKey}-${s.updatedStamp}'),
                setting: s,
                title: title,
                saving: _saving,
                onSave: _save,
              );
            },
          );
        },
      ),
    );
  }
}

extension on TemperatureAlertSetting {
  String get updatedStamp =>
      '${minC}_${maxC}_${staleMinutes}_${enabled}_$notifyCooldownMinutes';
}

class _SettingCard extends StatefulWidget {
  const _SettingCard({
    super.key,
    required this.setting,
    required this.title,
    required this.saving,
    required this.onSave,
  });

  final TemperatureAlertSetting setting;
  final String title;
  final bool saving;
  final Future<void> Function(TemperatureAlertSetting) onSave;

  @override
  State<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<_SettingCard> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _stale;
  late final TextEditingController _cooldown;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: widget.setting.minC.toString());
    _max = TextEditingController(text: widget.setting.maxC.toString());
    _stale = TextEditingController(text: '${widget.setting.staleMinutes}');
    _cooldown =
        TextEditingController(text: '${widget.setting.notifyCooldownMinutes}');
    _enabled = widget.setting.enabled;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _stale.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alertas activas'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Mín °C'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Máx °C'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stale,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stale (min)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cooldown,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cooldown (min)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.saving
                  ? null
                  : () async {
                      final minC = double.tryParse(_min.text.trim());
                      final maxC = double.tryParse(_max.text.trim());
                      final stale = int.tryParse(_stale.text.trim());
                      final cooldown = int.tryParse(_cooldown.text.trim());
                      if (minC == null ||
                          maxC == null ||
                          stale == null ||
                          cooldown == null ||
                          minC >= maxC) {
                        return;
                      }
                      await widget.onSave(
                        widget.setting.copyWith(
                          minC: minC,
                          maxC: maxC,
                          staleMinutes: stale,
                          notifyCooldownMinutes: cooldown,
                          enabled: _enabled,
                        ),
                      );
                    },
              child: Text(widget.saving ? '…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
