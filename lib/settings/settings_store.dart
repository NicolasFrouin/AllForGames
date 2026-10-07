import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/freecell/freecell_difficulty.dart';
import '../games/klondike/klondike_difficulty.dart';
import '../games/mahjong/mahjong_difficulty.dart';
import '../games/minesweeper/minesweeper_difficulty.dart';
import '../games/spider/spider_difficulty.dart';
import '../games/tripeaks/tripeaks_difficulty.dart';
import '../l10n/app_localizations.dart';
import '../skins/card_backs.dart';
import '../skins/minesweeper_themes.dart';
import '../skins/tile_styles.dart';

/// The player's settings, one storage key per setting.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(
    this._prefs,
    this._locale,
    this._cardBackId,
    this._tileStyleId,
    this._klondikeDrawCount,
    this._klondikeDifficulty,
    this._mahjongDifficulty,
    this._mahjongMode,
    this._freecellDifficulty,
    this._spiderDifficulty,
    this._tripeaksDifficulty,
    this._minesweeperDifficulty,
    this._minesweeperThemeId,
    this._minesweeperFlagHoldMs,
    this._minesweeperVibrate,
    this._mahjongTraySide,
    this._pinnedGames,
    this._mahjongShape,
  );

  static const localeKey = 'settings.locale';
  static const pinnedGamesKey = 'settings.pinnedGames';
  static const cardBackKey = 'settings.cardBack';
  static const tileStyleKey = 'settings.tileStyle';
  static const klondikeDrawCountKey = 'settings.klondike.drawCount';
  static const klondikeDifficultyKey = 'settings.klondike.difficulty';
  static const mahjongDifficultyKey = 'settings.mahjong.difficulty';
  static const mahjongModeKey = 'settings.mahjong.mode';
  static const mahjongTraySideKey = 'settings.mahjong.traySide';
  static const mahjongShapeKey = 'settings.mahjong.shape';
  static const freecellDifficultyKey = 'settings.freecell.difficulty';
  static const spiderDifficultyKey = 'settings.spider.difficulty';
  static const tripeaksDifficultyKey = 'settings.tripeaks.difficulty';
  static const minesweeperDifficultyKey = 'settings.minesweeper.difficulty';
  static const minesweeperThemeKey = 'settings.minesweeperTheme';
  static const minesweeperFlagHoldKey = 'settings.minesweeper.flagHoldMs';
  static const minesweeperVibrateKey = 'settings.minesweeper.vibrate';

  /// How long a finger holds a Minesweeper cell to flag it, in ms. Flutter's
  /// usual long press (500 ms) felt slow.
  static const defaultFlagHoldMs = 300;
  static const minFlagHoldMs = 150;
  static const maxFlagHoldMs = 750;

  static const _defaultDrawCount = 1;
  static const _defaultDifficulty = KlondikeDifficulty.medium;

  final SharedPreferencesAsync _prefs;
  Locale? _locale;
  String _cardBackId;
  String _tileStyleId;
  int _klondikeDrawCount;
  KlondikeDifficulty _klondikeDifficulty;
  MahjongDifficulty _mahjongDifficulty;
  MahjongMode _mahjongMode;
  FreeCellDifficulty _freecellDifficulty;
  SpiderDifficulty _spiderDifficulty;
  TriPeaksDifficulty _tripeaksDifficulty;
  MinesweeperDifficulty _minesweeperDifficulty;
  String _minesweeperThemeId;
  int _minesweeperFlagHoldMs;
  bool _minesweeperVibrate;
  MahjongTraySide _mahjongTraySide;
  List<String> _pinnedGames;
  MahjongShape _mahjongShape;

  static Future<SettingsStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    Locale? locale;
    var cardBackId = classicCardBack.id;
    var tileStyleId = classicTileStyle.id;
    var drawCount = _defaultDrawCount;
    var difficulty = _defaultDifficulty;
    var mahjongDifficulty = MahjongDifficulty.medium;
    var mahjongMode = MahjongMode.tray;
    var freecellDifficulty = FreeCellDifficulty.medium;
    var spiderDifficulty = SpiderDifficulty.medium;
    var tripeaksDifficulty = TriPeaksDifficulty.medium;
    var minesweeperDifficulty = MinesweeperDifficulty.medium;
    var minesweeperThemeId = classicMinesweeperTheme.id;
    var minesweeperFlagHoldMs = defaultFlagHoldMs;
    var minesweeperVibrate = false;
    var mahjongTraySide = MahjongTraySide.top;
    var pinnedGames = <String>[];
    var mahjongShape = MahjongShape.generated;
    try {
      locale = _supportedLocale(await prefs.getString(localeKey));
      cardBackId = _knownCardBack(await prefs.getString(cardBackKey));
      tileStyleId = _knownTileStyle(await prefs.getString(tileStyleKey));
      drawCount = _knownDrawCount(await prefs.getInt(klondikeDrawCountKey));
      difficulty = _knownDifficulty(
        await prefs.getString(klondikeDifficultyKey),
      );
      mahjongDifficulty =
          MahjongDifficulty.values.asNameMap()[await prefs.getString(
            mahjongDifficultyKey,
          )] ??
          MahjongDifficulty.medium;
      mahjongMode =
          MahjongMode.values.asNameMap()[await prefs.getString(
            mahjongModeKey,
          )] ??
          MahjongMode.tray;
      freecellDifficulty =
          FreeCellDifficulty.values.asNameMap()[await prefs.getString(
            freecellDifficultyKey,
          )] ??
          FreeCellDifficulty.medium;
      spiderDifficulty =
          SpiderDifficulty.values.asNameMap()[await prefs.getString(
            spiderDifficultyKey,
          )] ??
          SpiderDifficulty.medium;
      tripeaksDifficulty =
          TriPeaksDifficulty.values.asNameMap()[await prefs.getString(
            tripeaksDifficultyKey,
          )] ??
          TriPeaksDifficulty.medium;
      minesweeperDifficulty =
          MinesweeperDifficulty.values.asNameMap()[await prefs.getString(
            minesweeperDifficultyKey,
          )] ??
          MinesweeperDifficulty.medium;
      minesweeperThemeId = _knownMinesweeperTheme(
        await prefs.getString(minesweeperThemeKey),
      );
      minesweeperFlagHoldMs = _knownFlagHold(
        await prefs.getInt(minesweeperFlagHoldKey),
      );
      minesweeperVibrate = await prefs.getBool(minesweeperVibrateKey) ?? false;
      mahjongTraySide =
          MahjongTraySide.values.asNameMap()[await prefs.getString(
            mahjongTraySideKey,
          )] ??
          MahjongTraySide.top;
      pinnedGames = {...?await prefs.getStringList(pinnedGamesKey)}.toList();
      mahjongShape =
          MahjongShape.values.asNameMap()[await prefs.getString(
            mahjongShapeKey,
          )] ??
          MahjongShape.generated;
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps the settings of this session.
      debugPrint('SettingsStore: cannot read settings: $error');
    }
    return SettingsStore._(
      prefs,
      locale,
      cardBackId,
      tileStyleId,
      drawCount,
      difficulty,
      mahjongDifficulty,
      mahjongMode,
      freecellDifficulty,
      spiderDifficulty,
      tripeaksDifficulty,
      minesweeperDifficulty,
      minesweeperThemeId,
      minesweeperFlagHoldMs,
      minesweeperVibrate,
      mahjongTraySide,
      pinnedGames,
      mahjongShape,
    );
  }

  /// The language chosen by the player. Null follows the device language.
  Locale? get locale => _locale;

  /// Ids of the games pinned to the top of the hub, the last pinned first.
  /// An id the app does not have (yet) stays: the hub skips it.
  List<String> get pinnedGames => _pinnedGames;

  /// Id of the card back the games draw face-down cards with.
  String get cardBackId => _cardBackId;

  /// Id of the style Mahjong draws its tiles with.
  String get tileStyleId => _tileStyleId;

  /// Options of the last new Klondike game the player dealt, for the next
  /// one: 1 or 3 cards drawn at a time, and the difficulty.
  int get klondikeDrawCount => _klondikeDrawCount;
  KlondikeDifficulty get klondikeDifficulty => _klondikeDifficulty;

  /// Difficulty of the last new Mahjong game the player dealt, for the next
  /// one.
  MahjongDifficulty get mahjongDifficulty => _mahjongDifficulty;

  /// Mode of the last new Mahjong game the player dealt (classic or tray),
  /// for the next one.
  MahjongMode get mahjongMode => _mahjongMode;

  /// Shape of the last new Mahjong game the player dealt (a generated one,
  /// or the classic layout of the level), for the next one.
  MahjongShape get mahjongShape => _mahjongShape;

  /// Where the tray of Mahjong's tray mode is, next to the board.
  MahjongTraySide get mahjongTraySide => _mahjongTraySide;

  /// Difficulty of the last new FreeCell game the player dealt, for the
  /// next one.
  FreeCellDifficulty get freecellDifficulty => _freecellDifficulty;

  /// Difficulty (number of suits) of the last new Spider game the player
  /// dealt, for the next one.
  SpiderDifficulty get spiderDifficulty => _spiderDifficulty;

  /// Difficulty of the last new TriPeaks game the player dealt, for the
  /// next one.
  TriPeaksDifficulty get tripeaksDifficulty => _tripeaksDifficulty;

  /// Level of the last new Minesweeper game the player dealt, for the next
  /// one.
  MinesweeperDifficulty get minesweeperDifficulty => _minesweeperDifficulty;

  /// Id of the theme Minesweeper draws its board with.
  String get minesweeperThemeId => _minesweeperThemeId;

  /// How long a finger holds a Minesweeper cell to flag it, in ms.
  int get minesweeperFlagHoldMs => _minesweeperFlagHoldMs;

  /// Whether the phone buzzes when a hold flags a Minesweeper cell.
  bool get minesweeperVibrate => _minesweeperVibrate;

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

  /// Pins [gameId] to the top of the hub, above the games pinned before, or
  /// unpins it.
  Future<void> togglePinned(String gameId) async {
    _pinnedGames = _pinnedGames.contains(gameId)
        ? [..._pinnedGames.where((id) => id != gameId)]
        : [gameId, ..._pinnedGames];
    await _guard(
      'save the pinned games',
      () => _prefs.setStringList(pinnedGamesKey, _pinnedGames),
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

  /// Selects the Mahjong tile style [id] (classic for an unknown id). The
  /// caller checks that the player has unlocked it.
  Future<void> setTileStyle(String id) async {
    _tileStyleId = _knownTileStyle(id);
    await _guard(
      'save the tile style',
      () => _prefs.setString(tileStyleKey, _tileStyleId),
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

  Future<void> setMahjongMode(MahjongMode mode) async {
    _mahjongMode = mode;
    await _guard(
      'save the Mahjong mode',
      () => _prefs.setString(mahjongModeKey, mode.name),
    );
    notifyListeners();
  }

  Future<void> setMahjongShape(MahjongShape shape) async {
    _mahjongShape = shape;
    await _guard(
      'save the Mahjong shape',
      () => _prefs.setString(mahjongShapeKey, shape.name),
    );
    notifyListeners();
  }

  Future<void> setMahjongTraySide(MahjongTraySide side) async {
    _mahjongTraySide = side;
    await _guard(
      'save the Mahjong tray side',
      () => _prefs.setString(mahjongTraySideKey, side.name),
    );
    notifyListeners();
  }

  Future<void> setFreecellDifficulty(FreeCellDifficulty difficulty) async {
    _freecellDifficulty = difficulty;
    await _guard(
      'save the FreeCell difficulty',
      () => _prefs.setString(freecellDifficultyKey, difficulty.name),
    );
    notifyListeners();
  }

  Future<void> setSpiderDifficulty(SpiderDifficulty difficulty) async {
    _spiderDifficulty = difficulty;
    await _guard(
      'save the Spider difficulty',
      () => _prefs.setString(spiderDifficultyKey, difficulty.name),
    );
    notifyListeners();
  }

  Future<void> setTripeaksDifficulty(TriPeaksDifficulty difficulty) async {
    _tripeaksDifficulty = difficulty;
    await _guard(
      'save the TriPeaks difficulty',
      () => _prefs.setString(tripeaksDifficultyKey, difficulty.name),
    );
    notifyListeners();
  }

  Future<void> setMinesweeperDifficulty(
    MinesweeperDifficulty difficulty,
  ) async {
    _minesweeperDifficulty = difficulty;
    await _guard(
      'save the Minesweeper level',
      () => _prefs.setString(minesweeperDifficultyKey, difficulty.name),
    );
    notifyListeners();
  }

  /// Selects the Minesweeper theme [id] (classic for an unknown id). The
  /// caller checks that the player has unlocked it.
  Future<void> setMinesweeperTheme(String id) async {
    _minesweeperThemeId = _knownMinesweeperTheme(id);
    await _guard(
      'save the Minesweeper theme',
      () => _prefs.setString(minesweeperThemeKey, _minesweeperThemeId),
    );
    notifyListeners();
  }

  /// Keeps the Minesweeper hold time ([ms] limited to [minFlagHoldMs] ..
  /// [maxFlagHoldMs]).
  Future<void> setMinesweeperFlagHold(int ms) async {
    _minesweeperFlagHoldMs = _knownFlagHold(ms);
    await _guard(
      'save the Minesweeper hold time',
      () => _prefs.setInt(minesweeperFlagHoldKey, _minesweeperFlagHoldMs),
    );
    notifyListeners();
  }

  Future<void> setMinesweeperVibrate(bool vibrate) async {
    _minesweeperVibrate = vibrate;
    await _guard(
      'save the Minesweeper vibration',
      () => _prefs.setBool(minesweeperVibrateKey, vibrate),
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

  /// Classic for a tile style the app does not have.
  static String _knownTileStyle(String? id) => tileStyleById(id ?? '').id;

  /// Classic for a Minesweeper theme the app does not have.
  static String _knownMinesweeperTheme(String? id) =>
      minesweeperThemeById(id ?? '').id;

  static int _knownFlagHold(int? ms) =>
      (ms ?? defaultFlagHoldMs).clamp(minFlagHoldMs, maxFlagHoldMs);

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
