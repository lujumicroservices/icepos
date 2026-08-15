import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:ice_pos/src/core/auth/auth_session_provider.dart';
import 'package:ice_pos/src/core/auth/user_role_provider.dart';
import 'package:ice_pos/src/core/l10n/locale_provider.dart';
import 'package:ice_pos/src/core/services/fcm_push_service.dart';
import 'package:ice_pos/src/features/auth/presentation/login_screen.dart';

/// Muestra login si no hay sesión; si hay sesión sincroniza el rol y muestra [child].
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      loading: () => MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $err', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
      data: (role) {
        if (role != null) {
          final r = role;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(userRoleProvider.notifier).setRoleFromAuth(r);
            unawaited(FcmPushService.instance.registerTokenForCurrentUser());
          });
        }
        if (role == null) {
          return MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
              useMaterial3: true,
            ),
            locale: ref.watch(localeProvider),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const LoginScreen(),
          );
        }
        return widget.child;
      },
    );
  }
}
