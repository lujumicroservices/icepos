import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(appDatabaseProvider));
});

const _kSessionUserIdKey = 'auth_user_id';

/// Repositorio de autenticación. Si Supabase está configurado, la fuente de verdad es la nube (Auth + profiles).
/// Si no, se usan usuarios locales en Drift.
class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  bool get _useCloud => SupabaseService.isInitialized;

  static String _hashPassword(String password) {
    const salt = 'ice_pos_v1';
    final bytes = utf8.encode('$salt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Inicia sesión. [usernameOrEmail]: usuario (local) o correo (nube). Devuelve rol o null.
  Future<UserRole?> login(String usernameOrEmail, String password) async {
    final input = usernameOrEmail.trim();
    if (input.isEmpty || password.isEmpty) return null;

    if (_useCloud) {
      final cloud = await _loginCloud(input, password);
      if (cloud != null) return cloud;
      // Proyecto sin usuarios en Auth, registro desactivado, o primera instalación:
      // la nube falla pero ya existen admin/cajero en SQLite (createDefaultAdminIfNeeded).
      await createDefaultAdminIfNeeded();
      return _loginLocal(input, password);
    }
    await createDefaultAdminIfNeeded();
    return _loginLocal(input, password);
  }

  Future<UserRole?> _loginCloud(String email, String password) async {
    try {
      final trimmed = email.trim();
      final emailStr = trimmed.contains('@')
          ? trimmed.toLowerCase()
          : '${trimmed.toLowerCase()}@pos.local';

      dynamic res;
      try {
        res = await SupabaseService.instance.client.auth.signInWithPassword(
          email: emailStr,
          password: password,
        );
      } catch (_) {
        res = null;
      }

      // Algunas versiones devuelven respuesta sin lanzar pero sin sesión.
      var session = res?.session;
      var userId = res?.user?.id as String?;

      Future<void> tryBootstrapSignUp() async {
        if (emailStr != 'admin@pos.local' || password != 'admin') return;
        try {
          res = await SupabaseService.instance.client.auth.signUp(
            email: emailStr,
            password: password,
            data: {'role': 'admin'},
          );
          session = res.session;
          userId = res.user?.id as String?;
        } catch (_) {
          // Usuario ya existe con otra clave, signUp deshabilitado, etc.
        }
      }

      if (session == null || userId == null) {
        await tryBootstrapSignUp();
        session = res?.session;
        userId = res?.user?.id as String?;
      }

      // Tras signUp con "confirmar email" desactivado, a veces hace falta un segundo signIn.
      if (session == null || userId == null) {
        if (emailStr == 'admin@pos.local' && password == 'admin') {
          try {
            res = await SupabaseService.instance.client.auth.signInWithPassword(
              email: emailStr,
              password: password,
            );
            session = res.session;
            userId = res.user?.id as String?;
          } catch (_) {}
        }
      }

      if (session == null) return null;
      final resolvedUserId = userId;
      if (resolvedUserId == null) return null;
      return _fetchCloudRole(resolvedUserId);
    } catch (_) {
      return null;
    }
  }

  Future<UserRole?> _fetchCloudRole(String userId) async {
    try {
      final res = await SupabaseService.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = res?['role'] as String?;
      if (role == 'admin') return UserRole.admin;
      if (role == 'cajero') return UserRole.employee;
      return UserRole.employee;
    } catch (_) {
      return UserRole.employee;
    }
  }

  Future<UserRole?> _loginLocal(String username, String password) async {
    final clean = username.toLowerCase();
    final hash = _hashPassword(password);
    final row = await (_db.select(_db.appUsers)
          ..where((u) => u.username.equals(clean)))
        .getSingleOrNull();
    if (row == null || row.passwordHash != hash) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSessionUserIdKey, row.id);
    return row.role == 'admin' ? UserRole.admin : UserRole.employee;
  }

  /// Cierra sesión.
  Future<void> logout() async {
    if (_useCloud) {
      try {
        await SupabaseService.instance.client.auth.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionUserIdKey);
  }

  /// Id del usuario actual (null si no hay sesión). En nube es el uuid del Auth.
  Future<Object?> getCurrentUserId() async {
    if (_useCloud) {
      final session = SupabaseService.instance.client.auth.currentSession;
      final uid = session?.user.id;
      if (uid != null) return uid;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kSessionUserIdKey);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSessionUserIdKey);
  }

  /// Rol del usuario actual. Null si no hay sesión.
  Future<UserRole?> getCurrentUserRole() async {
    if (_useCloud) {
      final session = SupabaseService.instance.client.auth.currentSession;
      final userId = session?.user.id;
      if (userId != null) {
        return _fetchCloudRole(userId);
      }
      final prefs = await SharedPreferences.getInstance();
      final localId = prefs.getInt(_kSessionUserIdKey);
      if (localId == null) return null;
      final row = await (_db.select(_db.appUsers)..where((u) => u.id.equals(localId))).getSingleOrNull();
      if (row == null) return null;
      return row.role == 'admin' ? UserRole.admin : UserRole.employee;
    }
    final id = await getCurrentUserId();
    if (id == null) return null;
    final row = await (_db.select(_db.appUsers)..where((u) => u.id.equals(id as int))).getSingleOrNull();
    if (row == null) return null;
    return row.role == 'admin' ? UserRole.admin : UserRole.employee;
  }

  /// Nombre del usuario actual (para UI). En nube es el email.
  Future<String?> getCurrentUsername() async {
    if (_useCloud) {
      final session = SupabaseService.instance.client.auth.currentSession;
      final email = session?.user.email ?? session?.user.userMetadata?['name']?.toString();
      if (email != null && email.isNotEmpty) return email;
      final id = await getCurrentUserId();
      if (id is int) {
        final row = await (_db.select(_db.appUsers)..where((u) => u.id.equals(id))).getSingleOrNull();
        return row?.username;
      }
      return null;
    }
    final id = await getCurrentUserId();
    if (id == null) return null;
    final row = await (_db.select(_db.appUsers)..where((u) => u.id.equals(id as int))).getSingleOrNull();
    return row?.username;
  }

  /// Crea admin/cajero en SQLite si la tabla está vacía (también con nube: respaldo offline).
  Future<void> createDefaultAdminIfNeeded() async {
    final count = _db.selectOnly(_db.appUsers)..addColumns([_db.appUsers.id.count()]);
    final result = await count.getSingle();
    final total = result.read(_db.appUsers.id.count()) ?? 0;
    if (total > 0) return;
    await _db.into(_db.appUsers).insert(AppUsersCompanion.insert(
          username: 'admin',
          passwordHash: _hashPassword('admin'),
          role: 'admin',
        ));
    await _db.into(_db.appUsers).insert(AppUsersCompanion.insert(
          username: 'cajero',
          passwordHash: _hashPassword('cajero'),
          role: 'cajero',
        ));
  }
}
