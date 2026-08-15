import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/cloud_sync_service.dart';
import 'package:ice_pos/src/core/services/offline_write_policy.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/voice_assistant/domain/create_movement_payload.dart';

/// Registers a movement using the same paths as the manual Movements dialog.
Future<String?> submitMovement({
  required WidgetRef ref,
  required CreateMovementPayload payload,
  void Function()? onCloudRefresh,
}) async {
  final repo = ref.read(posRepositoryProvider);
  final role = ref.read(userRoleProvider);
  final l10n = ref.read(appLocalizationsProvider);

  try {
    if (repo != null && role == UserRole.employee) {
      final resolved = await repo.resolveMovementShiftForInsert(
        account: payload.account,
        pickedLocalShiftId: payload.account == 'CAJA' ? null : null,
        pickedCloudShiftId: payload.account == 'CAJA' ? null : null,
      );
      await repo.enqueuePendingMovement(
        type: payload.type,
        account: payload.account,
        amount: payload.amount,
        reason: payload.reason,
        shiftId: resolved.localShiftId,
        cloudShiftId: resolved.cloudShiftIdForSync,
      );
      return l10n.pendingApprovalQueued;
    }
    if (repo != null) {
      final resolved = await repo.resolveMovementShiftForInsert(
        account: payload.account,
        pickedLocalShiftId: null,
        pickedCloudShiftId: null,
      );
      await repo.insertMovement(
        type: payload.type,
        account: payload.account,
        amount: payload.amount,
        reason: payload.reason,
        shiftId: resolved.localShiftId,
        cloudShiftIdForSync: resolved.cloudShiftIdForSync,
      );
    } else {
      int? cloudShiftId;
      if (payload.account == 'CAJA' && CloudSyncService.isEnabled) {
        final open = await CloudSyncService.fetchOpenShiftsForActiveStore();
        if (open.isNotEmpty) cloudShiftId = open.first.id;
      }
      final (err, _) = await CloudSyncService.insertMovementToCloud(
        type: payload.type,
        account: payload.account,
        amount: payload.amount,
        reason: payload.reason,
        shiftId: cloudShiftId,
      );
      if (err != null) return err;
      onCloudRefresh?.call();
    }
  } on OfflineMasterWriteException catch (e) {
    return e.message;
  } catch (e) {
    return e.toString();
  }

  return payload.type == 'ENTRADA'
      ? '${l10n.entry} registrada'
      : '${l10n.exit} registrada';
}

/// Shows snackbar for movement submit result (null = success message in return).
void showMovementSubmitFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
