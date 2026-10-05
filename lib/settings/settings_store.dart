import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/klondike/klondike_difficulty.dart';
import '../games/mahjong/mahjong_difficulty.dart';
import '../l10n/app_localizations.dart';
import '../skins/card_backs.dart';

/// The player's settings, one storage key per setting.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(
    this._prefs,
    this._locale,
    this._cardBackId,
    this._klondikeDrawCount,
    this._klondikeDifficulty,
    this._mahjongDifficulty,
  );

  static const localeKey = 'settings.locale';
  static const cardBackKey = 'settings.cardBack';
  static const klondikeDrawCountKey = 'settings.klondike.drawCount';
  static const klondikeDifficultyKey = 'settings.klondike.difficulty';
  static const mahjongDifficultyKey = 'settings.mahjong.difficulty';

  static const _defaultDrawCount = 1;
  static const _defaultDifficulty = KlondikeDifficulty.medium;

  final SharedPreferencesAsync _prefs;
  Locale? _locale;
  String _cardBackId;
  int _klondikeDrawCount;
  KlondikeDifficulty _klondikeDifficulty;
  MahjongDifficulty _mahjongDifficulty;

  static Future<SettingsStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    Locale? locale;
    var cardBackId = classicCardBack.id;
    var drawCount = _defaultDrawCount;
    var difficulty = _defaultDifficulty;
    var mahjongDifficulty = MahjongDifficulty.medium;
    try {
      locale = _supportedLocale(await prefs.getString(localeKey));
      cardBackId = _knownCardBack(await prefs.getString(cardBackKey));
      drawCount = _knownDrawCount(await prefs.getInt(klondikeDrawCountKey));
      difficulty = _knownDifficulty(
        await prefs.getString(klondikeDifficultyKey),
      );
      mahjongDifficulty =
          MahjongDifficulty.values.asNameMap()[await prefs.getString(
            mahjongDifficultyKey,
          )] ??
          MahjongDifficulty.medium;
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps the settings of this session.
      debugPrint('SettingsStore: cannot read settings: $error');
    }
    return SettingsStore._(
      prefs,
      locale,
      cardBackId,
      drawCount,
      difficulty,
      mahjongDifficulty,
    );
  }

  /// The language chosen by the player. Null follows the device language.
  Locale? get locale => _locale;

  /// Id of the card back the games draw face-down cards with.
  String get cardBackId => _cardBackId;

  /// Options of the last new Klondike game the player dealt, for the next
  /// one: 1 or 3 cards drawn at a time, and the difficulty.
  int get klondikeDrawCount => _klondikeDrawCount;
  KlondikeDifficulty get klondikeDifficulty => _klondikeDifficulty;

  /// Difficulty of the last new Mahjong game the player dealt, for the next
  /// one.
  MahjongDifficulty get mahjongDifficulty => _mahjongDifficulty;

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

  /// Keeps the options of a new Klondike game ([drawCount] 1 when it is not
  /// 1 or 3).
  Future<void> setKlondikeNewGame({
    required int drawCount,
    required KlondikeDifficulty difficulty,
  }) async {
    _klondikeDrawCount = _knownDrawCount(drawCount);
    _klondikeDifficulty = difficulty;
    await _guard('save the Klondike options', () async {
      await _prefs.setInt(klondikeDrawCountKey, _klondikeDrawCount);
      await _prefs.setString(klondikeDifficultyKey, difficulty.name);
    });
    notifyListeners();
  }

  Future<void> setMahjongDifficulty(MahjongDifficulty difficulty) async {
    _mahjongDifficulty = difficulty;
    await _guard(
      'save the Mahjong difficulty',
      () => _prefs.setString(mahjongDifficultyKey, difficulty.name),
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

  static int _knownDrawCount(int? drawCount) =>
      drawCount == 3 ? 3 : _defaultDrawCount;

  /// Medium for a difficulty the app does not have.
  static KlondikeDifficulty _knownDifficulty(String? name) =>
      KlondikeDifficulty.values.asNameMap()[name] ?? _defaultDifficulty;

  /// A full or blocked storage must not break the app.
  static Future<void> _guard(String action, Future<void> Function() io) async {
    try {
      await io();
    } on Object catch (error) {
      debugPrint('SettingsStore: cannot $action: $error');
    }
  }
}
