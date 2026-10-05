import 'package:all_for_games/achievements/achievement_store.dart';
import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_stores.dart';

const firstWin = 'klondike.firstWin';

/// A slow Klondike Draw 1 game with an undo: as a win, it reaches only
/// [firstWin].
GameRecord game({GameOutcome outcome = GameOutcome.won}) => GameRecord(
  gameId: 'klondike',
  variant: 'draw1',
  seed: 1,
  startedAt: DateTime.utc(2026, 1, 1, 10),
  endedAt: DateTime.utc(2026, 1, 1, 10, 30),
  playTime: const Duration(minutes: 10),
  outcome: outcome,
  moves: 100,
  undos: 1,
  score: 500,
);

List<String> ids(Iterable<Achievement> list) => [for (final a in list) a.id];

void main() {
  test(
    'a win added to the stats unlocks its achievement and queues it',
    () async {
      final stores = await createTestStores();
      final achievements = stores.achievements;

      await stores.stats.add(game(outcome: GameOutcome.abandoned));
      expect(achievements.isUnlocked(firstWin), isFalse);

      await stores.stats.add(game());
      expect(achievements.isUnlocked(firstWin), isTrue);
      expect(ids(achievements.takeAnnouncements()), [firstWin]);

      await pumpEventQueue();
      expect((await AchievementStore.load()).isUnlocked(firstWin), isTrue);
    },
  );

  test('records saved before the start unlock silently', () async {
    final stores = await createTestStores(savedData([game()]));
    final achievements = stores.achievements;

    expect(achievements.isUnlocked(firstWin), isTrue);
    expect(achievements.takeAnnouncements(), isEmpty);

    await pumpEventQueue();
    expect((await AchievementStore.load()).isUnlocked(firstWin), isTrue);
  });
}
