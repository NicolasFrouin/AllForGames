import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// The player's settings, one storage key per setting.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs, this._locale);

  static const localeKey = 'settings.locale';

  final SharedPreferencesAsync _prefs;
  Locale? _locale;

  static Future<SettingsStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    Locale? locale;
    try {
      locale = _supportedLocale(await prefs.getString(localeKey));
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps the settings of this session.
      debugPrint('SettingsStore: cannot read settings: $error');
    }
    return SettingsStore._(prefs, locale);
  }

  /// The language chosen by the player. Null follows the device language.
  Locale? get locale => _locale;

  /// Listeners are told after the write, never during the call, like the
  /// other stores.
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    await _guard(
      'save the language',
      () => locale == null
          ? _prefs.remove(localeKey)
          : _prefs.setString(localeKey, locale.languageCode),
    );
    notifyListeners();
  }

  /// Null for a language the app does not have (for example saved by a newer
  /// app version).
  static Locale? _supportedLocale(String? languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }

  /// A full or blocked storage must not break the app.
  static Future<void> _guard(String action, Future<void> Function() io) async {
    try {
      await io();
    } on Object catch (error) {
      debugPrint('SettingsStore: cannot $action: $error');
    }
  }
}
