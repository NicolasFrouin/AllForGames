import 'dart:convert';

import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/spider/spider_controller.dart';
import 'package:all_for_games/games/spider/spider_deals.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'spider_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = SpiderController.gameId;

/// Ten columns of one card each, and a stock of one deal.
final dealBoard = board(
  columns: [
    for (var i = 0; i < 10; i++) [card('${i + 2}H')],
  ],
  stock: [for (var i = 0; i < 10; i++) card('KC', up: false, deck: i)],
  difficulty: SpiderDifficulty.hard,
);

void main() {
  late StatsStore stats;
  late GameSaveStore saves;
  late DateTime now;

  setUp(() async {
    final stores = await createTestStores();
    stats = stores.stats;
    saves = stores.saves;
    now = DateTime.utc(2026, 1, 1, 12);
  });

  SpiderController controller([SpiderState? state]) => SpiderController(
    stats: stats,
    saves: saves,
    seed: 1,
    initialState: state,
    clock: () => now,
  );

  SpiderController restore(Map<String, Object?> json) =>
      SpiderController.restore(
        json,
        stats: stats,
        saves: saves,
        clock: () => now,
      );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Starts a new game, so [game] counts as abandoned, and returns its record.
  GameRecord abandon(SpiderController game) {
    game.newGame();
    return stats.records.last;
  }

  test('a move counts a move, its input and the run it moved', () {
    final game = controller(
      board(
        columns: [
          [card('3C', up: false), ...run(Suit.hearts, 9, 7)],
          [card('10S')],
          [card('9H')],
        ],
      ),
    );
    expect(game.score, 500);

    expect(game.move(0, 3, 1), isTrue);
    expect(game.moves, 1);
    expect(game.score, 499);
    expect(game.lastAction, SpiderAction.move);
    expect(game.lastMovedCardIds, ['hearts-9', 'hearts-8', 'hearts-7']);
    expect(game.tap(1, 2), isTrue, reason: 'the 8 and 7 onto the 9');
    expect(game.state.columns[2], hasLength(3));

    final record = abandon(game);
    expect(record.moves, 2);
    expect(record.variant, 'suits1');
    expect(record.difficulty, isNull);
    expect(record.details[SpiderStatKeys.dragMoves], 1);
    expect(record.details[SpiderStatKeys.tapMoves], 1);
    expect(record.details[SpiderStatKeys.longestRunMoved], 3);
    expect(record.details[SpiderStatKeys.cardsRevealed], 1);
    expect(record.details[SpiderStatKeys.emptyColumnUses], isNull);
    expect(record.details[SpiderStatKeys.runsCompleted], 0);
  });

  test('an illegal move or tap returns false and changes nothing', () async {
    final game = controller(
      board(
        columns: [
          [card('9H')],
          [card('9D')],
        ],
      ),
    );
    final before = game.state;
    var notified = 0;
    game.addListener(() => notified++);

    expect(game.move(0, 1, 1), isFalse);
    expect(game.tap(0, 1), isFalse, reason: 'no 10 and no empty column');
    expect(game.dealStock(), isFalse, reason: 'no stock');

    expect(game.state, same(before));
    expect(game.moves, 0);
    expect(game.canUndo, isFalse);
    expect(notified, 0);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('a move to an empty column is counted', () {
    final game = controller(
      board(
        columns: [
          [card('2C', up: false), card('6H')],
          [],
        ],
      ),
    );
    expect(game.tap(0, 1), isTrue);
    expect(game.state.columns[1], [card('6H')]);
    expect(abandon(game).details[SpiderStatKeys.emptyColumnUses], 1);
  });

  test('a stock deal gives a card to each column, from the first', () {
    final game = controller(dealBoard);
    expect(game.canDeal, isTrue);

    expect(game.dealStock(), isTrue);
    expect(game.lastAction, SpiderAction.stockDeal);
    expect(game.lastMovedCardIds, [
      for (var i = 9; i >= 0; i--) 'clubs-13${i == 0 ? '' : '-$i'}',
    ]);
    expect(game.state.stock, isEmpty);
    expect(game.score, 499);

    expect(abandon(game).details[SpiderStatKeys.stockDeals], 1);
  });

  test('undo takes back a stock deal; it costs a point', () {
    final game = controller(dealBoard);
    game.dealStock();

    game.undo();
    expect(game.state.encode(), dealBoard.encode());
    expect(game.lastAction, SpiderAction.undo);
    expect(game.lastMovedCardIds, hasLength(10));
    expect(game.undos, 1);
    expect(game.moves, 1);
    expect(game.score, 498);
    expect(game.canUndo, isFalse);
  });

  test('a completed run scores 100, and undo takes it back', () {
    final game = controller(
      board(
        columns: [
          [card('5D', up: false), ...run(Suit.spades, 13, 4)],
          [card('2H'), ...run(Suit.spades, 3, 1, deck: 1)],
        ],
      ),
    );
    expect(game.move(1, 3, 0), isTrue);
    expect(game.state.runs, hasLength(1));
    expect(game.score, 599);
    final completed = game.lastCompletedRuns.single;
    expect(completed.column, 0);
    expect(completed.cards.first, card('KS'));
    expect(completed.cards.last, card('AS', deck: 1));
    expect(completed.revealedId, 'diamonds-5');

    game.undo();
    expect(game.state.runs, isEmpty);
    expect(game.score, 498);
    expect(game.lastCompletedRuns, isEmpty);
    expect(abandon(game).details[SpiderStatKeys.runsCompleted], 0);
  });

  test(
    'the last run wins: result, stopped timer, a won record, no save',
    () async {
      final game = controller(nearWon());
      wait(30);
      expect(game.move(1, 1, 0), isTrue);

      final record = game.result!;
      expect(record.outcome, GameOutcome.won);
      expect(record.variant, 'suits1');
      expect(record.moves, 1);
      expect(record.score, 1299);
      expect(record.playTime, const Duration(seconds: 30));
      expect(record.details[SpiderStatKeys.runsCompleted], 8);
      expect(record.details[SpiderStatKeys.timeToFirstMoveMs], 30000);
      expect(game.canUndo, isFalse);
      expect(game.move(0, 1, 1), isFalse);
      wait(30);
      expect(game.playTime, const Duration(seconds: 30));
      await flush();
      expect(stats.records.single.outcome, GameOutcome.won);
      expect(await storedSave(gameId), isNull);

      game.newGame();
      expect(
        stats.records,
        hasLength(1),
        reason: 'a won game is not abandoned',
      );
    },
  );

  test('a new game without a move records nothing', () {
    final game = controller();
    game.newGame();
    expect(stats.records, isEmpty);
  });

  test('thinking times: before the first move and the longest one', () {
    final game = controller(dealBoard);
    wait(4);
    game.dealStock();
    wait(10);
    game.undo();
    wait(2);
    game.dealStock();

    final details = abandon(game).details;
    expect(details[SpiderStatKeys.timeToFirstMoveMs], 4000);
    expect(details[SpiderStatKeys.longestThinkMs], 10000);
  });

  group('saves', () {
    test('every action saves the game, which continues as it was', () async {
      final game = controller(SpiderState.deal(9, SpiderDifficulty.medium));
      wait(5);
      // Deals, then undoes the first deal: the history has one deal left.
      game.dealStock();
      game.dealStock();
      game.undo();
      await flush();

      final saved = (await storedSave(gameId))!;
      expect(saved.moves, 2);
      expect(saved.playTime, const Duration(seconds: 5));
      // Through JSON, as in storage.
      final json = jsonDecode(jsonEncode(saved.data)) as Map<String, Object?>;
      final restored = restore(json);
      expect(restored.state.encode(), game.state.encode());
      expect(restored.difficulty, SpiderDifficulty.medium);
      expect(restored.seed, 1);
      expect(restored.moves, 2);
      expect(restored.undos, 1);
      expect(restored.score, game.score);
      expect(restored.playTime, const Duration(seconds: 5));
      expect(restored.lastAction, SpiderAction.none);

      // The same cards come back with undo.
      restored.undo();
      game.undo();
      expect(restored.state.encode(), game.state.encode());
      expect(restored.canUndo, isFalse);
    });

    test('a save that does not replay is refused', () {
      final game = controller(dealBoard)..dealStock();
      final json = game.toJson();
      for (final broken in <Map<String, Object?>>[
        {...json, 'version': 2},
        {...json, 'actions': []},
        {
          ...json,
          'actions': [
            [0, 1, 1],
          ],
        },
        {...json, 'difficulty': 'extreme'},
        {...json, 'initial': 'nope'},
        {...json, 'moves': null},
      ]) {
        expect(() => restore(broken), throwsFormatException, reason: '$broken');
      }
    });

    test('pause saves the play time', () async {
      final game = controller(dealBoard);
      wait(7);
      game.pause();
      wait(60);
      await flush();
      expect((await storedSave(gameId))!.playTime, const Duration(seconds: 7));
      game.resume();
      wait(3);
      expect(game.playTime, const Duration(seconds: 10));
    });
  });

  group('new games', () {
    SpiderController fresh(SpiderDifficulty difficulty) => SpiderController(
      stats: stats,
      saves: saves,
      difficulty: difficulty,
      clock: () => now,
    );

    test('deal a proven seed of the level', () {
      for (final difficulty in SpiderDifficulty.values) {
        final game = fresh(difficulty);
        expect(spiderDeals[difficulty.name], contains(game.seed));
        expect(game.difficulty, difficulty);
        expect(
          game.state.encode(),
          SpiderState.deal(game.seed, difficulty).encode(),
        );
        expect(game.lastAction, SpiderAction.deal);
      }
    });

    test('keep the level and never deal the same seed again', () {
      final game = fresh(SpiderDifficulty.hard);
      for (var i = 0; i < 20; i++) {
        final seed = game.seed;
        game.newGame();
        expect(game.seed, isNot(seed));
        expect(game.difficulty, SpiderDifficulty.hard);
      }
      game.newGame(difficulty: SpiderDifficulty.easy);
      expect(spiderDeals['easy'], contains(game.seed));
    });

    test('skip the seeds of the records of the level', () async {
      final easy = spiderDeals['easy']!;
      await Future.wait([
        for (final seed in easy.skip(1))
          stats.add(
            GameRecord(
              gameId: gameId,
              variant: 'suits1',
              seed: seed,
              startedAt: DateTime.utc(2026),
              endedAt: DateTime.utc(2026),
              playTime: Duration.zero,
              outcome: GameOutcome.won,
              moves: 1,
              undos: 0,
              score: 0,
            ),
          ),
      ]);
      expect(fresh(SpiderDifficulty.easy).seed, easy.first);
    });
  });
}
