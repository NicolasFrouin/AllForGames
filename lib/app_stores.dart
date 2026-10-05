import 'dart:async';

import 'saves/game_save_store.dart';
import 'settings/settings_store.dart';
import 'stats/stats_store.dart';

/// The stores of the app, loaded once at start and given to the screens.
class AppStores {
  const AppStores({
    required this.stats,
    required this.saves,
    required this.settings,
  });

  final StatsStore stats;
  final GameSaveStore saves;
  final SettingsStore settings;

  static Future<AppStores> load() async {
    final (stats, saves, settings) = await (
      StatsStore.load(),
      GameSaveStore.load(),
      SettingsStore.load(),
    ).wait;
    return AppStores(stats: stats, saves: saves, settings: settings);
  }
}
