import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A game in progress, saved so the player can continue it later.
class SavedGame {
  const SavedGame({
    required this.gameId,
    required this.moves,
    required this.playTime,
    required this.savedAt,
    required this.data,
  });

  factory SavedGame.fromJson(Map<String, Object?> json) => SavedGame(
    gameId: json['gameId'] as String,
    moves: json['moves'] as int,
    playTime: Duration(milliseconds: json['playTimeMs'] as int),
    savedAt: DateTime.parse(json['savedAt'] as String),
    data: json['data'] as Map<String, Object?>,
  );

  final String gameId;

  /// [moves] and [playTime] let the hub show the game without reading [data].
  final int moves;
  final Duration playTime;
  final DateTime savedAt;

  /// Game-specific JSON: everything the game needs to continue.
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'moves': moves,
    'playTimeMs': playTime.inMilliseconds,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'data': data,
  };
}

/// Keeps the game in progress of each game type, one storage key per game type.
///
/// Games save themselves after each action and when the player leaves them,
/// and remove their save when they end. Finished games are in `StatsStore`.
class GameSaveStore extends ChangeNotifier {
  GameSaveStore._(this._prefs, this._saves);

  static const keyPrefix = 'save.';

  static String keyOf(String gameId) => '$keyPrefix$gameId';

  final SharedPreferencesAsync _prefs;
  final Map<String, SavedGame> _saves;

  static Future<GameSaveStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    final saves = <String, SavedGame>{};
    try {
      for (final MapEntry(:key, :value) in (await prefs.getAll()).entries) {
        if (!key.startsWith(keyPrefix) || value is! String) continue;
        if (_decode(key, value) case final save?) saves[save.gameId] = save;
      }
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps this session in memory.
      debugPrint('GameSaveStore: cannot read saved games: $error');
    }
    return GameSaveStore._(prefs, saves);
  }

  SavedGame? operator [](String gameId) => _saves[gameId];

  /// Replaces the saved game of [game]'s game type.
  ///
  /// Listeners are told after the write, never during the call: a game screen
  /// saves while the framework unmounts it, when no widget can rebuild.
  Future<void> save(SavedGame game) async {
    _saves[game.gameId] = game;
    await _guard(
      'save ${game.gameId}',
      () => _prefs.setString(keyOf(game.gameId), jsonEncode(game.toJson())),
    );
    notifyListeners();
  }

  Future<void> remove(String gameId) async {
    _saves.remove(gameId);
    await _guard('remove $gameId', () => _prefs.remove(keyOf(gameId)));
    notifyListeners();
  }

  /// A full or blocked storage must not break the game.
  static Future<void> _guard(String action, Future<void> Function() io) async {
    try {
      await io();
    } on Object catch (error) {
      debugPrint('GameSaveStore: cannot $action: $error');
    }
  }

  static SavedGame? _decode(String key, String raw) {
    try {
      return SavedGame.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (error) {
      // Skipped, not deleted: a newer app version may still read it.
      debugPrint('GameSaveStore: cannot read $key: $error');
      return null;
    }
  }
}
