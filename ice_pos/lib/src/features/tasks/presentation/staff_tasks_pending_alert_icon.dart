import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/staff_tasks_cloud_service.dart';
import 'package:ice_pos/src/features/tasks/data/staff_tasks_providers.dart';

/// Icono de aviso de tareas vencidas. Al tocarlo abre el popup invasivo.
class StaffTasksPendingAlertIcon extends ConsumerStatefulWidget {
  const StaffTasksPendingAlertIcon({super.key, this.compact = true});

  /// AppBar: botón compacto. POS: botón flotante más grande.
  final bool compact;

  @override
  ConsumerState<StaffTasksPendingAlertIcon> createState() =>
      _StaffTasksPendingAlertIconState();
}

class _StaffTasksPendingAlertIconState extends ConsumerState<StaffTasksPendingAlertIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!StaffTasksCloudService.isEnabled) return const SizedBox.shrink();
    if (kIsWeb && ref.watch(userRoleProvider) == UserRole.admin) {
      return const SizedBox.shrink();
    }

    ref.watch(staffTasksRefreshProvider);
    ref.watch(staffTasksDueRefreshProvider);
    final due = ref.watch(dueStaffTasksCountProvider);
    final count = due.asData?.value ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    final l10n = ref.watch(appLocalizationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final size = widget.compact ? 40.0 : 52.0;
    final iconSize = widget.compact ? 22.0 : 28.0;

    return Tooltip(
      message: l10n.staffTaskPendingAlertTooltip(count),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          final glow = 4 + t * 6;
          return Container(
            margin: widget.compact
                ? const EdgeInsets.only(right: 4)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.error.withValues(alpha: 0.35 + t * 0.25),
                  blurRadius: glow,
                  spreadRadius: t * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Material(
          color: scheme.error,
          elevation: widget.compact ? 2 : 6,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openStaffTasksInvasivePopup(ref),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: math.sin(_pulse.value * math.pi * 2) * 0.08,
                    child: Icon(
                      Icons.assignment_late,
                      color: scheme.onError,
                      size: iconSize,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: widget.compact ? 2 : 4,
                      right: widget.compact ? 2 : 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scheme.error, width: 1.5),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: TextStyle(
                            fontSize: widget.compact ? 10 : 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.error,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón flotante de tareas pendientes (esquina superior derecha del POS).
class StaffTasksPendingFloatingAlert extends ConsumerWidget {
  const StaffTasksPendingFloatingAlert({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!StaffTasksCloudService.isEnabled) return const SizedBox.shrink();
    if (kIsWeb && ref.watch(userRoleProvider) == UserRole.admin) {
      return const SizedBox.shrink();
    }

    ref.watch(staffTasksDueRefreshProvider);
    final due = ref.watch(dueStaffTasksCountProvider);
    final count = due.asData?.value ?? 0;
    if (count <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: StaffTasksPendingAlertIcon(compact: false),
    );
  }
}
