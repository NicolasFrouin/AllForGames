import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_record.dart';
import 'game_stats.dart';

/// Keeps every game of every game type on the device, one storage key per game.
///
/// With one key per game, a second browser tab or an unreadable entry can
/// never remove other games. The game in progress is saved under its key after
/// each move: if the app closes before the game ends (for example a closed
/// browser tab), the next start finds it as an abandoned game.
class StatsStore extends ChangeNotifier {
  StatsStore._(this._prefs, this._records);

  static const keyPrefix = 'stats.game.';

  static String keyOf(GameRecord record) => '$keyPrefix${record.id}';

  final SharedPreferencesAsync _prefs;
  final List<GameRecord> _records;

  static Future<StatsStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    final records = <GameRecord>[];
    try {
      for (final MapEntry(:key, :value) in (await prefs.getAll()).entries) {
        if (!key.startsWith(keyPrefix) || value is! String) continue;
        if (_decode(key, value) case final record?) records.add(record);
      }
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps this session in memory.
      debugPrint('StatsStore: cannot read saved games: $error');
    }
    // Storage keys have no order.
    records.sort((a, b) => a.endedAt.compareTo(b.endedAt));
    return StatsStore._(prefs, records);
  }

  List<GameRecord> get records => List.unmodifiable(_records);

  List<GameRecord> recordsFor(String gameId, {String? variant}) => [
    for (final record in _records)
      if (record.gameId == gameId &&
          (variant == null || record.variant == variant))
        record,
  ];

  GameStats statsFor(String gameId, {String? variant}) =>
      GameStats.from(recordsFor(gameId, variant: variant));

  GameStats get overall => GameStats.from(_records);

  /// Saves a finished game. It replaces the in-progress save of that game.
  ///
  /// Listeners are told after the save, never during the call: a game screen
  /// may add its record while the framework unmounts it, when no widget can
  /// rebuild.
  Future<void> add(GameRecord record) async {
    _records.add(record);
    await _write(record);
    notifyListeners();
  }

  /// Saves the game in progress. It is not in [records] until [add].
  Future<void> saveInProgress(GameRecord record) => _write(record);

  Future<void> clear(String gameId) async {
    _records.removeWhere((record) => record.gameId == gameId);
    // Also removes games saved by other tabs, which this store does not list.
    final prefix = '$keyPrefix$gameId-';
    await _guard('clear games', () async {
      final keys = {
        for (final key in await _prefs.getKeys())
          if (key.startsWith(prefix)) key,
      };
      if (keys.isNotEmpty) await _prefs.clear(allowList: keys);
    });
    notifyListeners();
  }

  Future<void> _write(GameRecord record) => _guard(
    'save a game',
    () => _prefs.setString(keyOf(record), jsonEncode(record.toJson())),
  );

  /// A full or blocked storage must not break the game.
  static Future<void> _guard(String action, Future<void> Function() io) async {
    try {
      await io();
    } on Object catch (error) {
      debugPrint('StatsStore: cannot $action: $error');
    }
  }

  static GameRecord? _decode(String key, String raw) {
    try {
      return GameRecord.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object catch (error) {
      // Skipped, not deleted: a newer app version may still read it.
      debugPrint('StatsStore: cannot read $key: $error');
      return null;
    }
  }
}
