import 'dart:async';

import 'achievements/achievement_store.dart';
import 'saves/game_save_store.dart';
import 'settings/settings_store.dart';
import 'stats/stats_store.dart';

/// The stores of the app, loaded once at start and given to the screens.
class AppStores {
  /// Keeps [achievements] in sync with [stats]: every change of the records
  /// checks them again, and queues the new ones for the game screen to show.
  AppStores({
    required this.stats,
    required this.saves,
    required this.settings,
    required this.achievements,
  }) {
    // Games won before the achievements existed unlock them silently: no
    // game screen is there to show them.
    achievements.check(stats.records, announce: false);
    stats.addListener(() => achievements.check(stats.records));
  }

  final StatsStore stats;
  final GameSaveStore saves;
  final SettingsStore settings;
  final AchievementStore achievements;

  static Future<AppStores> load() async {
    final (stats, saves, settings, achievements) = await (
      StatsStore.load(),
      GameSaveStore.load(),
      SettingsStore.load(),
      AchievementStore.load(),
    ).wait;
    return AppStores(
      stats: stats,
      saves: saves,
      settings: settings,
      achievements: achievements,
    );
  }
}
