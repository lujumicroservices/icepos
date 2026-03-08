import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

const _kLocaleKey = 'app_locale';

/// Supported locales: Spanish (default), English.
Locale localeFromLanguageCode(String code) {
  switch (code) {
    case 'en':
      return const Locale('en');
    case 'es':
    default:
      return const Locale('es');
  }
}

String languageCodeFromLocale(Locale locale) {
  return locale.languageCode == 'en' ? 'en' : 'es';
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// Exposes [AppLocalizations] for the current [Locale]. Use in UI: ref.watch(appLocalizationsProvider).
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider);
  return AppLocalizations(locale);
});

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return const Locale('es');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null && (code == 'es' || code == 'en')) {
      state = localeFromLanguageCode(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, languageCodeFromLocale(locale));
  }
}
