import 'dart:convert';

import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A [StatsStore] backed by in-memory preferences, optionally with saved data.
Future<StatsStore> createTestStatsStore([Map<String, Object> data = const {}]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
  return StatsStore.load();
}

/// Saved data that holds [records], as [StatsStore] writes it.
Map<String, Object> savedData(Iterable<GameRecord> records) => {
  for (final record in records)
    StatsStore.keyOf(record): jsonEncode(record.toJson()),
};

/// The games in storage now, as a fresh app start would read them.
Future<List<GameRecord>> savedGames() async =>
    (await StatsStore.load()).records;
