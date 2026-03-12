import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ice_pos/src/core/auth/auth_repository.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';

/// Estado de sesión: null = no autenticado, [UserRole] = autenticado con ese rol.
final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, UserRole?>(AuthSessionNotifier.new);

class AuthSessionNotifier extends AsyncNotifier<UserRole?> {
  @override
  Future<UserRole?> build() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.createDefaultAdminIfNeeded();
    return repo.getCurrentUserRole();
  }

  Future<bool> login(String username, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final role = await repo.login(username, password);
    if (role == null) return false;
    state = AsyncData(role);
    ref.read(userRoleProvider.notifier).setRoleFromAuth(role);
    return true;
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
    ref.read(userRoleProvider.notifier).lockAsEmployee();
  }
}
