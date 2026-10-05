import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../skins/card_backs.dart';

/// The player's settings, one storage key per setting.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs, this._locale, this._cardBackId);

  static const localeKey = 'settings.locale';
  static const cardBackKey = 'settings.cardBack';

  final SharedPreferencesAsync _prefs;
  Locale? _locale;
  String _cardBackId;

  static Future<SettingsStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    Locale? locale;
    var cardBackId = classicCardBack.id;
    try {
      locale = _supportedLocale(await prefs.getString(localeKey));
      cardBackId = _knownCardBack(await prefs.getString(cardBackKey));
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps the settings of this session.
      debugPrint('SettingsStore: cannot read settings: $error');
    }
    return SettingsStore._(prefs, locale, cardBackId);
  }

  /// The language chosen by the player. Null follows the device language.
  Locale? get locale => _locale;

  /// Id of the card back the games draw face-down cards with.
  String get cardBackId => _cardBackId;

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

  /// Selects the card back [id] (classic for an unknown id). The caller
  /// checks that the player has unlocked it.
  Future<void> setCardBack(String id) async {
    _cardBackId = _knownCardBack(id);
    await _guard(
      'save the card back',
      () => _prefs.setString(cardBackKey, _cardBackId),
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

  /// Classic for a card back the app does not have.
  static String _knownCardBack(String? id) => cardBackById(id ?? '').id;

  /// A full or blocked storage must not break the app.
  static Future<void> _guard(String action, Future<void> Function() io) async {
    try {
      await io();
    } on Object catch (error) {
      debugPrint('SettingsStore: cannot $action: $error');
    }
  }
}
