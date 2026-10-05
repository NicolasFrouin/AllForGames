import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../helpers/test_stats_store.dart';

GameRecord game(
  String gameId, {
  int seed = 1,
  int endMinute = 10,
  GameOutcome outcome = GameOutcome.won,
  int moves = 80,
}) => GameRecord(
  gameId: gameId,
  variant: 'draw1',
  seed: seed,
  startedAt: DateTime.utc(2026, 1, 1, 0, seed),
  endedAt: DateTime.utc(2026, 1, 1, 1, endMinute),
  playTime: const Duration(minutes: 10),
  outcome: outcome,
  moves: moves,
  undos: 0,
  score: 400,
);

List<int> seeds(Iterable<GameRecord> records) => [
  for (final r in records) r.seed,
];

/// Storage where every read and write fails, like a blocked localStorage.
final class _BrokenPrefs extends InMemorySharedPreferencesAsync {
  _BrokenPrefs() : super.empty();

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => throw StateError('storage blocked');
}

void main() {
  test('starts empty without saved data', () async {
    final store = await createTestStatsStore();
    expect(store.records, isEmpty);
    expect(store.overall.played, 0);
  });

  test('keeps added records after a reload, oldest first', () async {
    final store = await createTestStatsStore();
    await store.add(game('klondike', seed: 1, endMinute: 30));
    await store.add(game('other', seed: 2, endMinute: 20));

    expect(seeds(await savedGames()), [2, 1]);
  });

  test(
    'a game in progress is saved but listed only from the next start',
    () async {
      final store = await createTestStatsStore();
      await store.saveInProgress(
        game('klondike', seed: 7, outcome: GameOutcome.abandoned),
      );

      expect(store.records, isEmpty);
      final saved = await savedGames();
      expect(seeds(saved), [7]);
      expect(saved.single.outcome, GameOutcome.abandoned);
    },
  );

  test('the final record replaces the in-progress save of the game', () async {
    final store = await createTestStatsStore();
    await store.saveInProgress(
      game('klondike', outcome: GameOutcome.abandoned, moves: 3),
    );
    await store.add(game('klondike', moves: 90));

    final saved = await savedGames();
    expect(saved, hasLength(1));
    expect(saved.single.won, isTrue);
    expect(saved.single.moves, 90);
  });

  test('two stores on the same storage (two tabs) keep both games', () async {
    final tabA = await createTestStatsStore();
    final tabB = await StatsStore.load();

    await tabB.add(game('klondike', seed: 1));
    await tabA.add(game('klondike', seed: 2));

    expect(seeds(await savedGames()), unorderedEquals([1, 2]));
  });

  test('an unreadable entry is skipped and never deleted', () async {
    const badKey = '${StatsStore.keyPrefix}klondike-future';
    final store = await createTestStatsStore({
      ...savedData([game('klondike', seed: 5)]),
      badKey: '{"seed": "x"}',
      'other.app.key': 'not json',
    });
    expect(seeds(store.records), [5]);

    await store.add(game('klondike', seed: 6));
    expect(seeds(await savedGames()), [5, 6]);
    expect(await SharedPreferencesAsync().getString(badKey), '{"seed": "x"}');
  });

  test(
    'clear removes one game type, also games saved by another tab',
    () async {
      final tabA = await createTestStatsStore();
      final tabB = await StatsStore.load();
      await tabA.add(game('klondike', seed: 1));
      await tabB.add(game('klondike', seed: 2));
      await tabA.add(game('mahjong', seed: 3));

      await tabA.clear('klondike');

      expect(tabA.recordsFor('klondike'), isEmpty);
      expect(seeds(await savedGames()), [3]);
    },
  );

  test('listeners are told after the save, not during the call', () async {
    final store = await createTestStatsStore();
    var notified = 0;
    store.addListener(() => notified++);

    final adding = store.add(game('klondike'));
    expect(notified, 0, reason: 'a screen can add while it is unmounted');
    expect(store.records, hasLength(1));
    await adding;
    expect(notified, 1);

    await store.clear('klondike');
    expect(notified, 2);
  });

  test('blocked storage still gives a working store', () async {
    SharedPreferencesAsyncPlatform.instance = _BrokenPrefs();
    final store = await StatsStore.load();
    expect(store.records, isEmpty);

    await store.add(game('klondike'));
    await store.saveInProgress(game('klondike', seed: 2));
    expect(store.statsFor('klondike').played, 1);
  });

  test('statsFor filters by game and variant', () async {
    final store = await createTestStatsStore(
      savedData([
        game('klondike', seed: 1),
        game('klondike', seed: 2, outcome: GameOutcome.abandoned),
        game('mahjong', seed: 3),
      ]),
    );
    expect(store.statsFor('klondike').played, 2);
    expect(store.statsFor('klondike').won, 1);
    expect(store.statsFor('klondike', variant: 'draw3').played, 0);
    expect(store.overall.played, 3);
  });
}
