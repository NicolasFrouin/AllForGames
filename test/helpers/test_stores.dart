import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Uses in-memory preferences, optionally with saved data, for the stores
/// loaded from now on.
void useTestStorage([Map<String, Object> data = const {}]) =>
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(data);

/// The app stores on in-memory preferences, optionally with saved data.
Future<AppStores> createTestStores([Map<String, Object> data = const {}]) {
  useTestStorage(data);
  return AppStores.load();
}

/// A [StatsStore] on in-memory preferences, optionally with saved data.
Future<StatsStore> createTestStatsStore([Map<String, Object> data = const {}]) {
  useTestStorage(data);
  return StatsStore.load();
}

/// Saved data that holds [records], as [StatsStore] writes it.
Map<String, Object> savedData(Iterable<GameRecord> records) => {
  for (final record in records)
    StatsStore.keyOf(record): jsonEncode(record.toJson()),
};

/// Saved data that holds [games] in progress, as [GameSaveStore] writes it.
Map<String, Object> savedGameData(Iterable<SavedGame> games) => {
  for (final game in games)
    GameSaveStore.keyOf(game.gameId): jsonEncode(game.toJson()),
};

/// The records in storage now, as a fresh app start would read them.
Future<List<GameRecord>> storedRecords() async =>
    (await StatsStore.load()).records;

/// The saved game in storage now, as a fresh app start would read it.
Future<SavedGame?> storedSave(String gameId) async =>
    (await GameSaveStore.load())[gameId];

/// The language in storage now, as a fresh app start would read it.
Future<Locale?> storedLocale() async => (await SettingsStore.load()).locale;

/// Storage where every read and write fails, like a blocked localStorage.
final class BrokenPrefs extends InMemorySharedPreferencesAsync {
  BrokenPrefs() : super.empty();

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      throw StateError('storage blocked');

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');
}
