import 'dart:async';

import 'saves/game_save_store.dart';
import 'stats/stats_store.dart';

/// The stores of the app, loaded once at start and given to the screens.
class AppStores {
  const AppStores({required this.stats, required this.saves});

  final StatsStore stats;
  final GameSaveStore saves;

  static Future<AppStores> load() async {
    final (stats, saves) = await (StatsStore.load(), GameSaveStore.load()).wait;
    return AppStores(stats: stats, saves: saves);
  }
}
