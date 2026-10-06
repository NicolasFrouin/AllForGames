import 'dart:async';

import 'package:all_for_games/achievements/achievement_store.dart';
import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_stores.dart';

const firstWin = 'klondike.firstWin';
const wins10 = 'klondike.wins10';
const draw3Win = 'klondike.draw3Win';

/// A slow Klondike Draw 1 game with an undo: as a win, it reaches only
/// [firstWin].
GameRecord game(
  int seed, {
  String variant = 'draw1',
  GameOutcome outcome = GameOutcome.won,
  String? difficulty,
}) => GameRecord(
  gameId: 'klondike',
  variant: variant,
  seed: seed,
  startedAt: DateTime.utc(2026, 1, 1, seed),
  endedAt: DateTime.utc(2026, 1, 1, seed, 30),
  playTime: const Duration(minutes: 10),
  outcome: outcome,
  moves: 100,
  undos: 1,
  score: 500,
  difficulty: difficulty,
);

/// [count] wins, each after an abandoned game, so they never make a streak.
List<GameRecord> wins(int count) => [
  for (var i = 0; i < count; i++) ...[
    game(2 * i, outcome: GameOutcome.abandoned),
    game(2 * i + 1),
  ],
];

List<String> ids(Iterable<Achievement> list) => [for (final a in list) a.id];

Future<AchievementStore> createStore([Map<String, Object> data = const {}]) {
  useTestStorage(data);
  return AchievementStore.load();
}

/// Completes when [notifier] next tells its listeners.
Future<void> nextNotification(ChangeNotifier notifier) {
  final notified = Completer<void>();
  void listener() {
    notifier.removeListener(listener);
    notified.complete();
  }

  notifier.addListener(listener);
  return notified.future;
}

/// Storage whose writes wait until [open] is called.
final class SlowPrefs extends InMemorySharedPreferencesAsync {
  SlowPrefs() : super.empty();

  final _gate = Completer<void>();

  void open() => _gate.complete();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    await _gate.future;
    return super.setString(key, value, options);
  }
}

void main() {
  test(
    'check unlocks reached achievements and keeps them after a reload',
    () async {
      final store = await createStore();
      expect(store.isUnlocked(firstWin), isFalse);
      expect(store.unlockedAt(firstWin), isNull);

      final saved = nextNotification(store);
      final unlocked = store.check([game(1)]);
      expect(ids(unlocked), [firstWin]);
      expect(store.isUnlocked(firstWin), isTrue, reason: 'unlocked right away');
      final date = store.unlockedAt(firstWin)!;
      await saved;

      final stored = await SharedPreferencesAsync().getString(
        AchievementStore.keyOf(firstWin),
      );
      expect(DateTime.parse(stored!).isAtSameMomentAs(date), isTrue);
      final reloaded = await AchievementStore.load();
      expect(reloaded.isUnlocked(firstWin), isTrue);
      expect(reloaded.unlockedAt(firstWin)!.isAtSameMomentAs(date), isTrue);
      expect(reloaded.isUnlocked(wins10), isFalse);
    },
  );

  test('check unlocks several achievements at once', () async {
    final store = await createStore();
    final unlocked = store.check([...wins(9), game(99, variant: 'draw3')]);
    expect(ids(unlocked), unorderedEquals([firstWin, wins10, draw3Win]));
    expect(ids(store.takeAnnouncements()), ids(unlocked));
  });

  test('checking twice never unlocks or announces twice', () async {
    final store = await createStore();
    final first = store.check(wins(1));
    final again = store.check(wins(2));
    expect(ids(first), [firstWin]);
    expect(again, isEmpty);
    expect(ids(store.takeAnnouncements()), [firstWin]);

    await pumpEventQueue();
    final reloaded = await AchievementStore.load();
    expect(reloaded.check(wins(3)), isEmpty);
    expect(reloaded.takeAnnouncements(), isEmpty);
  });

  test('announcements wait until taken, only with announce', () async {
    final store = await createStore();
    store.check(wins(1));
    expect(ids(store.takeAnnouncements()), [firstWin]);
    expect(store.takeAnnouncements(), isEmpty, reason: 'take clears them');

    final silent = store.check(wins(10), announce: false);
    expect(ids(silent), [wins10]);
    expect(store.isUnlocked(wins10), isTrue);
    expect(store.takeAnnouncements(), isEmpty);
  });

  test('unlocks survive the records being cleared', () async {
    final store = await createStore();
    store.check(wins(1));
    expect(store.check([]), isEmpty);
    expect(store.isUnlocked(firstWin), isTrue);

    await pumpEventQueue();
    final reloaded = await AchievementStore.load();
    reloaded.check([]);
    expect(reloaded.isUnlocked(firstWin), isTrue);
  });

  test('an unreadable value is skipped and never deleted', () async {
    final badKey = AchievementStore.keyOf(firstWin);
    final store = await createStore({
      badKey: 'not a date',
      AchievementStore.keyOf(wins10): 42,
      AchievementStore.keyOf(draw3Win): '2026-03-04T05:06:07.000Z',
      'other.app.key': 'not a date',
    });
    expect(store.isUnlocked(firstWin), isFalse);
    expect(store.isUnlocked(wins10), isFalse);
    expect(store.unlockedAt(draw3Win), DateTime.utc(2026, 3, 4, 5, 6, 7));
    expect(await SharedPreferencesAsync().getString(badKey), 'not a date');
  });

  test('blocked storage still gives a working store', () async {
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final store = await AchievementStore.load();
    expect(store.isUnlocked(firstWin), isFalse);

    final saved = nextNotification(store);
    expect(ids(store.check(wins(1))), [firstWin]);
    expect(store.isUnlocked(firstWin), isTrue);
    await saved;
  });

  test('listeners are told after the write, not during check', () async {
    final prefs = SlowPrefs();
    SharedPreferencesAsyncPlatform.instance = prefs;
    final store = await AchievementStore.load();
    var notified = 0;
    store.addListener(() => notified++);

    store.check(wins(1));
    expect(notified, 0, reason: 'a screen can check while it is unmounted');
    await pumpEventQueue();
    expect(notified, 0, reason: 'the write is not done yet');

    prefs.open();
    await pumpEventQueue();
    expect(notified, 1);

    store.check(wins(1));
    await pumpEventQueue();
    expect(notified, 1, reason: 'nothing new to tell');
  });

  test('a card back is unlocked when free or by its achievement', () async {
    final store = await createStore();
    final crimson = cardBackById('crimson');
    expect(store.isUnlockedBy(classicCardBack.unlockedBy), isTrue);
    expect(store.isUnlockedBy(crimson.unlockedBy), isFalse);

    store.check(wins(1));
    expect(store.isUnlockedBy(crimson.unlockedBy), isTrue);
    expect(store.isUnlockedBy(cardBackById('gold').unlockedBy), isFalse);
  });

  test('a Hard win unlocks Expert and the obsidian card back', () async {
    final store = await createStore();
    final obsidian = cardBackById('obsidian');
    expect(obsidian.unlockedBy, 'klondike.hardWin');

    store.check([
      game(1, difficulty: 'medium'),
      game(2, difficulty: 'hard', outcome: GameOutcome.abandoned),
    ]);
    expect(store.isUnlockedBy(obsidian.unlockedBy), isFalse);

    expect(ids(store.check([game(3, difficulty: 'hard')])), [
      'klondike.hardWin',
    ]);
    expect(store.isUnlockedBy(obsidian.unlockedBy), isTrue);
  });
}
