import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/database/app_database.dart';
import 'package:ice_pos/src/core/database/app_database_provider.dart';
import 'package:ice_pos/src/core/services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(appDatabaseProvider));
});

const _kSessionUserIdKey = 'auth_user_id';
const _kAuthLogName = 'ice_pos.auth';

void _authLog(String message) {
  developer.log(message, name: _kAuthLogName);
}

/// Repositorio de autenticación. Si Supabase está configurado, la fuente de verdad es la nube (Auth + profiles).
/// Si no, se usan usuarios locales en Drift.
class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase? _db;

  bool get _useCloud => SupabaseService.isInitialized;

  /// Último detalle de error (p. ej. mensaje de Supabase). Solo para diagnóstico / UI tras login fallido.
  String? lastLoginError;

  void _setLoginError(String message) {
    lastLoginError = message;
    _authLog('LOGIN_ERROR: $message');
  }

  static String _hashPassword(String password) {
    const salt = 'ice_pos_v1';
    final bytes = utf8.encode('$salt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Inicia sesión. [usernameOrEmail]: usuario (local) o correo (nube). Devuelve rol o null.
  Future<UserRole?> login(String usernameOrEmail, String password) async {
    lastLoginError = null;
    final input = usernameOrEmail.trim();
    if (input.isEmpty || password.isEmpty) return null;

    _authLog(
      'login start: useCloud=$_useCloud supabaseHost=${SupabaseService.debugHost ?? "(not initialized)"}',
    );

    if (_useCloud) {
      final cloud = await _loginCloud(input, password);
      if (cloud != null) {
        _authLog('login OK: cloud role=$cloud');
        return cloud;
      }
      _authLog('cloud login failed or no session; trying local fallback');
      // Proyecto sin usuarios en Auth, registro desactivado, o primera instalación:
      // la nube falla pero ya existen admin/cajero en SQLite (createDefaultAdminIfNeeded).
      await createDefaultAdminIfNeeded();
      final local = await _loginLocal(input, password);
      if (local == null) {
        _setLoginError(
          lastLoginError ??
              'Nube: sin sesión; local: usuario/contraseña no coinciden con admin/cajero.',
        );
      } else {
        _authLog('login OK: local fallback role=$local');
      }
      return local;
    }
    await createDefaultAdminIfNeeded();
    final localOnly = await _loginLocal(input, password);
    if (localOnly == null) {
      _setLoginError(lastLoginError ?? 'Usuario o contraseña local incorrectos.');
    } else {
      _authLog('login OK: local-only role=$localOnly');
    }
    return localOnly;
  }

  Future<UserRole?> _loginCloud(String email, String password) async {
    try {
      final trimmed = email.trim();
      final emailStr = trimmed.contains('@')
          ? trimmed.toLowerCase()
          : '${trimmed.toLowerCase()}@pos.local';

      _authLog('cloud: resolved email for Auth="$emailStr" (input contained @: ${trimmed.contains('@')})');

      dynamic res;
      try {
        res = await SupabaseService.instance.client.auth.signInWithPassword(
          email: emailStr,
          password: password,
        );
      } on AuthException catch (e, st) {
        _setLoginError(
          'Supabase Auth: ${e.message} (code=${e.code}, status=${e.statusCode})',
        );
        developer.log(
          'signInWithPassword AuthException',
          name: _kAuthLogName,
          error: e,
          stackTrace: st,
        );
        res = null;
      } catch (e, st) {
        _setLoginError('signInWithPassword: $e');
        developer.log(
          'signInWithPassword unexpected',
          name: _kAuthLogName,
          error: e,
          stackTrace: st,
        );
        res = null;
      }

      // Algunas versiones devuelven respuesta sin lanzar pero sin sesión.
      var session = res?.session;
      var userId = res?.user?.id as String?;
      _authLog(
        'cloud: after signInWithPassword session=${session != null} userId=${userId != null}',
      );

      Future<void> tryBootstrapSignUp() async {
        if (emailStr != 'admin@pos.local' || password != 'admin') return;
        try {
          _authLog('cloud: attempting bootstrap signUp admin@pos.local');
          res = await SupabaseService.instance.client.auth.signUp(
            email: emailStr,
            password: password,
            data: {'role': 'admin'},
          );
          session = res.session;
          userId = res.user?.id as String?;
          _authLog(
            'cloud: after signUp session=${session != null} userId=${userId != null}',
          );
        } catch (e, st) {
          _authLog('cloud: signUp failed: $e');
          developer.log('signUp', name: _kAuthLogName, error: e, stackTrace: st);
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
            _authLog('cloud: second signIn for admin@pos.local');
            res = await SupabaseService.instance.client.auth.signInWithPassword(
              email: emailStr,
              password: password,
            );
            session = res.session;
            userId = res.user?.id as String?;
          } on AuthException catch (e) {
            _setLoginError(
              'Supabase Auth (retry): ${e.message} (code=${e.code})',
            );
          } catch (e) {
            _setLoginError('signIn retry: $e');
          }
        }
      }

      if (session == null) {
        if (lastLoginError == null) {
          _setLoginError(
            'Sin sesión tras intentar login en Supabase (revisa email confirmado, URL del proyecto y registro email habilitado).',
          );
        }
        return null;
      }
      final resolvedUserId = userId;
      if (resolvedUserId == null) {
        _setLoginError('Sesión sin user id.');
        return null;
      }
      final role = await _fetchCloudRole(resolvedUserId);
      _authLog('cloud: profile role resolved=$role');
      return role;
    } catch (e, st) {
      _setLoginError('_loginCloud: $e');
      developer.log('_loginCloud', name: _kAuthLogName, error: e, stackTrace: st);
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
      if (res == null) {
        _authLog(
          'profiles: no row for user id (RLS o falta trigger); defaulting to cajero',
        );
      }
      if (role == 'admin') return UserRole.admin;
      if (role == 'cajero') return UserRole.employee;
      return UserRole.employee;
    } catch (e, st) {
      _authLog('profiles query failed: $e (using cajero)');
      developer.log('_fetchCloudRole', name: _kAuthLogName, error: e, stackTrace: st);
      return UserRole.employee;
    }
  }

  Future<UserRole?> _loginLocal(String username, String password) async {
    final db = _db;
    if (db == null) {
      _authLog('local: no database');
      return null;
    }
    final clean = username.toLowerCase();
    final hash = _hashPassword(password);
    final row = await (db.select(db.appUsers)
          ..where((u) => u.username.equals(clean)))
        .getSingleOrNull();
    if (row == null) {
      _authLog('local: no user row for username="$clean"');
      return null;
    }
    if (row.passwordHash != hash) {
      _authLog('local: password mismatch for username="$clean"');
      return null;
    }
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
      final db = _db;
      if (db == null) return null;
      final row = await (db.select(db.appUsers)..where((u) => u.id.equals(localId))).getSingleOrNull();
      if (row == null) return null;
      return row.role == 'admin' ? UserRole.admin : UserRole.employee;
    }
    final id = await getCurrentUserId();
    if (id == null) return null;
    final db = _db;
    if (db == null) return null;
    final row = await (db.select(db.appUsers)..where((u) => u.id.equals(id as int))).getSingleOrNull();
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
        final db = _db;
        if (db == null) return null;
        final row = await (db.select(db.appUsers)..where((u) => u.id.equals(id))).getSingleOrNull();
        return row?.username;
      }
      return null;
    }
    final id = await getCurrentUserId();
    if (id == null) return null;
    final db = _db;
    if (db == null) return null;
    final row = await (db.select(db.appUsers)..where((u) => u.id.equals(id as int))).getSingleOrNull();
    return row?.username;
  }

  /// Crea admin/cajero en SQLite si la tabla está vacía (también con nube: respaldo offline).
  Future<void> createDefaultAdminIfNeeded() async {
    final db = _db;
    if (db == null) return;
    final count = db.selectOnly(db.appUsers)..addColumns([db.appUsers.id.count()]);
    final result = await count.getSingle();
    final total = result.read(db.appUsers.id.count()) ?? 0;
    if (total > 0) return;
    await db.into(db.appUsers).insert(AppUsersCompanion.insert(
          username: 'admin',
          passwordHash: _hashPassword('admin'),
          role: 'admin',
        ));
    await db.into(db.appUsers).insert(AppUsersCompanion.insert(
          username: 'cajero',
          passwordHash: _hashPassword('cajero'),
          role: 'cajero',
        ));
  }
}
