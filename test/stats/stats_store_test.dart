import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_stores.dart';

GameRecord game(
  String gameId, {
  int seed = 1,
  int endMinute = 10,
  GameOutcome outcome = GameOutcome.won,
  int moves = 80,
  String variant = 'draw1',
  String? difficulty,
}) => GameRecord(
  gameId: gameId,
  variant: variant,
  seed: seed,
  startedAt: DateTime.utc(2026, 1, 1, 0, seed),
  endedAt: DateTime.utc(2026, 1, 1, 1, endMinute),
  playTime: const Duration(minutes: 10),
  outcome: outcome,
  moves: moves,
  undos: 0,
  score: 400,
  difficulty: difficulty,
);

List<int> seeds(Iterable<GameRecord> records) => [
  for (final r in records) r.seed,
];

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

    expect(seeds(await storedRecords()), [2, 1]);
  });

  test('the same game added twice (two tabs) is stored once', () async {
    final tabA = await createTestStatsStore();
    final tabB = await StatsStore.load();
    await tabA.add(game('klondike', moves: 90));
    await tabB.add(game('klondike', moves: 91));

    final saved = await storedRecords();
    expect(saved, hasLength(1));
    expect(saved.single.moves, 91);
  });

  test('two stores on the same storage (two tabs) keep both games', () async {
    final tabA = await createTestStatsStore();
    final tabB = await StatsStore.load();

    await tabB.add(game('klondike', seed: 1));
    await tabA.add(game('klondike', seed: 2));

    expect(seeds(await storedRecords()), unorderedEquals([1, 2]));
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
    expect(seeds(await storedRecords()), [5, 6]);
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
      expect(seeds(await storedRecords()), [3]);
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
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final store = await StatsStore.load();
    expect(store.records, isEmpty);

    await store.add(game('klondike'));
    expect(store.statsFor('klondike').played, 1);
    await store.clear('klondike');
    expect(store.records, isEmpty);
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

  test('recordsFor filters by difficulty, with the variant too', () async {
    final store = await createTestStatsStore(
      savedData([
        game('klondike', seed: 1, difficulty: 'hard'),
        game('klondike', seed: 2, difficulty: 'hard', variant: 'draw3'),
        game('klondike', seed: 3, difficulty: 'easy'),
        game('klondike', seed: 4),
        game('mahjong', seed: 5, difficulty: 'hard'),
      ]),
    );
    expect(seeds(store.recordsFor('klondike', difficulty: 'hard')), [1, 2]);
    expect(
      seeds(store.recordsFor('klondike', variant: 'draw3', difficulty: 'hard')),
      [2],
    );
    expect(seeds(store.recordsFor('klondike', difficulty: 'medium')), isEmpty);
    expect(store.statsFor('klondike', difficulty: 'easy').played, 1);
    expect(store.statsFor('klondike').played, 4);
  });
}
