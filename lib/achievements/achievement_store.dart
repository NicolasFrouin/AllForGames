import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../skins/card_backs.dart';
import '../stats/game_record.dart';
import 'achievements.dart';

/// Keeps the unlock date of each achievement, one storage key per
/// achievement.
///
/// Unlocks are permanent: an achievement stays unlocked when the statistics
/// that reached it are cleared.
class AchievementStore extends ChangeNotifier {
  AchievementStore._(this._prefs, this._unlockedAt);

  static const keyPrefix = 'achievements.';

  static String keyOf(String id) => '$keyPrefix$id';

  final SharedPreferencesAsync _prefs;
  final Map<String, DateTime> _unlockedAt;
  final _announcements = <Achievement>[];

  static Future<AchievementStore> load([SharedPreferencesAsync? prefs]) async {
    prefs ??= SharedPreferencesAsync();
    final unlockedAt = <String, DateTime>{};
    try {
      for (final MapEntry(:key, :value) in (await prefs.getAll()).entries) {
        if (!key.startsWith(keyPrefix)) continue;
        final date = value is String ? DateTime.tryParse(value) : null;
        if (date == null) {
          // Skipped, not deleted: a newer app version may still read it.
          debugPrint('AchievementStore: cannot read $key: $value');
          continue;
        }
        unlockedAt[key.substring(keyPrefix.length)] = date;
      }
    } on Object catch (error) {
      // Storage can be blocked (for example site data off in the browser).
      // The app still works, it only keeps this session in memory.
      debugPrint('AchievementStore: cannot read achievements: $error');
    }
    return AchievementStore._(prefs, unlockedAt);
  }

  bool isUnlocked(String id) => _unlockedAt.containsKey(id);

  DateTime? unlockedAt(String id) => _unlockedAt[id];

  /// Unlocks every achievement reached in [records] (of every game) and
  /// returns the newly unlocked ones. With [announce], they also wait in
  /// [takeAnnouncements].
  ///
  /// They are unlocked in memory right away, so the caller can show them.
  /// Listeners are told after the write, never during the call: a game screen
  /// may check while the framework unmounts it, when no widget can rebuild.
  List<Achievement> check(List<GameRecord> records, {bool announce = true}) {
    final unlocked = [
      for (final achievement in achievements)
        if (!isUnlocked(achievement.id) && achievement.isReached(records))
          achievement,
    ];
    if (unlocked.isEmpty) return const [];
    final now = DateTime.now();
    for (final achievement in unlocked) {
      _unlockedAt[achievement.id] = now;
    }
    if (announce) _announcements.addAll(unlocked);
    unawaited(_save(unlocked, now));
    return unlocked;
  }

  /// The achievements unlocked by [check] since the last call, oldest first.
  List<Achievement> takeAnnouncements() {
    final taken = [..._announcements];
    _announcements.clear();
    return taken;
  }

  Future<void> _save(List<Achievement> unlocked, DateTime date) async {
    final value = date.toUtc().toIso8601String();
    for (final achievement in unlocked) {
      // A full or blocked storage must not break the game.
      try {
        await _prefs.setString(keyOf(achievement.id), value);
      } on Object catch (error) {
        debugPrint('AchievementStore: cannot save ${achievement.id}: $error');
      }
    }
    notifyListeners();
  }
}

bool isCardBackUnlocked(CardBackSkin skin, AchievementStore store) {
  final id = skin.unlockedBy;
  return id == null || store.isUnlocked(id);
}
