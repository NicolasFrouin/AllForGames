import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/deal_picker.dart';
import 'package:all_for_games/games/klondike/klondike_deals.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'klondike_test_helpers.dart';

PileRef tab(int index) => PileRef.tableau(index);
PileRef fnd(Suit suit) => PileRef.foundation(suit.index);

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = KlondikeController.gameId;

const easy = KlondikeDifficulty.easy;
const medium = KlondikeDifficulty.medium;
const hard = KlondikeDifficulty.hard;

/// The seeds proven winnable for [drawCount] and [difficulty].
List<int> listOf(int drawCount, KlondikeDifficulty difficulty) =>
    klondikeDeals[drawCount]![difficulty.name]!;

/// A seed in none of the lists.
final unlistedSeed = Iterable.generate(1000, (i) => i + 1).firstWhere(
  (seed) =>
      difficultyOfSeed(1, seed) == null && difficultyOfSeed(3, seed) == null,
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

  KlondikeController controller([KlondikeState? state]) => KlondikeController(
    stats: stats,
    saves: saves,
    seed: 1,
    initialState: state,
    clock: () => now,
  );

  KlondikeController restore(SavedGame? saved) => KlondikeController.restore(
    saved!.data,
    stats: stats,
    saves: saves,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Starts a new game, so [game] counts as abandoned, and returns its record.
  GameRecord abandon(KlondikeController game) {
    game.newGame();
    return stats.records.last;
  }

  /// Many draws, taps and undos on the seed 1 deal, with time between them.
  void play(KlondikeController game) {
    for (var i = 0; i < 40; i++) {
      wait(i % 7);
      game.draw();
      game.tap(PileRef.waste, 1);
      for (var pile = 0; pile < 7; pile++) {
        game.tap(tab(pile), 1);
      }
      if (i % 5 == 0) game.undo();
    }
  }

  test('draw counts a move and a stock draw', () {
    final game = controller();
    expect(game.draw(), isTrue);
    expect(game.moves, 1);
    expect(game.state.waste, hasLength(1));

    final record = abandon(game);
    expect(record.moves, 1);
    expect(record.details[KlondikeStatKeys.stockDraws], 1);
  });

  test('an illegal move returns false and changes nothing', () async {
    final game = controller(
      board(
        tableau: [
          [card('9H')],
          [card('10D')],
        ],
      ),
    );
    final before = game.state;
    var notified = 0;
    game.addListener(() => notified++);

    expect(game.move(tab(0), 1, tab(1)), isFalse);
    expect(game.tap(tab(0), 1), isFalse);

    expect(game.state, same(before));
    expect(game.moves, 0);
    expect(game.canUndo, isFalse);
    expect(notified, 0);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('undo restores the state and score and counts an undo', () {
    final game = controller(
      board(
        waste: [card('QH')],
        tableau: [
          [card('KS')],
        ],
      ),
    );
    final before = game.state;
    expect(game.move(PileRef.waste, 1, tab(0)), isTrue);
    expect(game.score, 5);

    game.undo();
    expect(game.state, same(before));
    expect(game.score, 0);
    expect(game.undos, 1);
    expect(game.moves, 1);
    expect(game.canUndo, isFalse);
    expect(abandon(game).undos, 1);
  });

  test('score never goes below zero', () {
    final game = controller(board(waste: [card('5D'), card('AS')]));
    expect(game.move(PileRef.waste, 1, fnd(Suit.spades)), isTrue);
    expect(game.score, 10);

    expect(game.draw(), isTrue, reason: 'recycles the waste for -100');
    expect(game.score, 0);
    game.draw();
    expect(game.draw(), isTrue, reason: 'recycles again at score 0');
    expect(game.score, 0);

    game.undo();
    game.undo();
    game.undo();
    expect(game.score, 10);
    expect(abandon(game).details[KlondikeStatKeys.stockRecycles], 2);
  });

  test('tap sends a card to its foundation and counts a tap move', () {
    final game = controller(
      board(
        tableau: [
          [card('5D', up: false), card('AS')],
        ],
      ),
    );
    expect(game.tap(tab(0), 1), isTrue);
    expect(game.state.foundations[Suit.spades.index], [card('AS')]);
    expect(game.state.tableau[0], [card('5D')]);
    expect(game.score, 15);
    expect(game.lastMovedCardIds, {card('AS').id});

    final details = abandon(game).details;
    expect(details[KlondikeStatKeys.tapMoves], 1);
    expect(details[KlondikeStatKeys.dragMoves], isNull);
    expect(details[KlondikeStatKeys.cardsRevealed], 1);
    expect(details[KlondikeStatKeys.cardsToFoundation], 1);
  });

  test('an undone reveal does not count as a revealed card', () {
    final game = controller(
      board(
        tableau: [
          [card('5D', up: false), card('AS')],
        ],
      ),
    );
    for (var i = 0; i < 3; i++) {
      game.tap(tab(0), 1);
      game.undo();
    }
    game.draw();

    final details = abandon(game).details;
    expect(details[KlondikeStatKeys.cardsRevealed], 0);
    expect(details[KlondikeStatKeys.tapMoves], 3);
  });

  test('the last card wins: result, stopped timer and a won record', () async {
    final game = controller(
      board(
        foundations: foundationsUpTo([13, 13, 13, 11]),
        tableau: [
          [card('KS')],
          [card('QS')],
        ],
      ),
    );
    wait(30);
    game.move(tab(1), 1, fnd(Suit.spades));
    expect(stats.records, isEmpty);
    expect(game.result, isNull);

    wait(10);
    expect(game.tap(tab(0), 1), isTrue);
    wait(600);
    game.resume();
    wait(60);

    final result = game.result!;
    expect(result.outcome, GameOutcome.won);
    expect(result.variant, 'draw1');
    expect(result.seed, 1);
    expect(result.moves, 2);
    expect(result.score, 20);
    expect(result.playTime, const Duration(seconds: 40));
    expect(game.playTime, const Duration(seconds: 40));
    expect(result.details, {
      KlondikeStatKeys.dragMoves: 1,
      KlondikeStatKeys.tapMoves: 1,
      KlondikeStatKeys.cardsToFoundation: 52,
      KlondikeStatKeys.cardsRevealed: 0,
      KlondikeStatKeys.timeToFirstMoveMs: 30000,
      KlondikeStatKeys.longestThinkMs: 30000,
    });
    expect(game.canUndo, isFalse);
    expect(game.draw(), isFalse);

    await flush();
    expect(stats.records, [same(result)]);
    expect((await storedRecords()).map((r) => r.outcome), [GameOutcome.won]);
  });

  test('a win removes the saved game, and a won game is not saved', () async {
    final game = controller(
      board(
        foundations: foundationsUpTo([13, 13, 13, 11]),
        tableau: [
          [card('KS')],
          [card('QS')],
        ],
      ),
    );
    game.move(tab(1), 1, fnd(Suit.spades));
    await flush();
    expect((await storedSave(gameId))!.moves, 1);

    game.tap(tab(0), 1);
    expect(game.result, isNotNull);
    game.pause();
    game.save();

    expect(saves[gameId], isNull);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('autoComplete finishes the game as one move', () async {
    final game = controller(
      board(
        foundations: foundationsUpTo([10, 10, 10, 10]),
        tableau: [
          [card('KC'), card('QD'), card('JC')],
          [card('KD'), card('QC'), card('JD')],
          [card('KH'), card('QS'), card('JH')],
          [card('KS'), card('QH'), card('JS')],
        ],
      ),
    );
    expect(game.canAutoComplete, isTrue);

    game.autoComplete();
    expect(game.state.isWon, isTrue);
    expect(game.moves, 1);
    expect(game.score, 120);
    expect(game.canAutoComplete, isFalse);
    expect(game.result!.details[KlondikeStatKeys.autoCompleted], 1);
    expect(game.result!.details[KlondikeStatKeys.cardsToFoundation], 52);
    await flush();
    expect(stats.records.single.won, isTrue);
  });

  test('autoComplete lists the cards in the order they go up', () {
    final game = controller(
      board(
        foundations: foundationsUpTo([10, 10, 10, 10]),
        tableau: [
          [card('KC'), card('QD'), card('JC')],
          [card('KD'), card('QC'), card('JD')],
          [card('KH'), card('QS'), card('JH')],
          [card('KS'), card('QH'), card('JS')],
        ],
      ),
    );
    game.autoComplete();

    expect(game.lastAction, KlondikeAction.autoComplete);
    final ranks = [
      for (final id in game.lastMovedCardIds) int.parse(id.split('-').last),
    ];
    // The board sends them one by one in this order: never a card before
    // the one under it on its foundation.
    expect(ranks, [11, 11, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13]);
  });

  test('each action is seen once, with its kind', () {
    final game = controller(
      board(
        stock: [card('2S', up: false)],
        tableau: [
          [card('3H')],
        ],
      ),
    );
    expect(game.lastAction, KlondikeAction.deal);
    final dealt = game.actionSerial;

    game.draw();
    expect(game.lastAction, KlondikeAction.draw);
    expect(game.actionSerial, dealt + 1);
    game.undo();
    expect(game.lastAction, KlondikeAction.undo);
    expect(game.lastMovedCardIds, {'spades-2'});
    game.draw();
    game.move(PileRef.waste, 1, tab(0));
    expect(game.lastAction, KlondikeAction.move);
    expect(game.actionSerial, dealt + 4);

    game.newGame(seed: 1);
    expect(game.lastAction, KlondikeAction.deal);
  });

  test('a continued game starts with no action to animate', () {
    final game = controller();
    game.draw();
    final restored = KlondikeController.restore(
      game.toJson(),
      stats: stats,
      saves: saves,
    );
    expect(restored.lastAction, KlondikeAction.none);
  });

  test('autoComplete does nothing while cards are face down', () {
    final game = controller();
    game.autoComplete();
    expect(game.moves, 0);
    expect(game.state.foundationCardCount, 0);
  });

  test('every action and a pause save the game', () async {
    final game = controller(
      board(
        stock: [card('2C', up: false)],
        waste: [card('QH')],
        tableau: [
          [card('KS')],
        ],
      ),
    );
    void expectSaved() {
      final saved = saves[gameId]!;
      expect(saved.moves, game.moves);
      expect(saved.playTime, game.playTime);
      expect(saved.data, game.toJson());
    }

    wait(5);
    game.move(PileRef.waste, 1, tab(0));
    expectSaved();
    game.draw();
    expectSaved();
    game.undo();
    expectSaved();
    wait(5);
    game.pause();
    expectSaved();
    expect(saves[gameId]!.playTime, const Duration(seconds: 10));

    await flush();
    expect((await storedSave(gameId))!.data, game.toJson());
    expect(stats.records, isEmpty);
  });

  test('a restored game is the same game', () async {
    final game = controller();
    play(game);
    expect(game.state.foundationCardCount, greaterThan(0));
    await flush();

    final restored = restore(await storedSave(gameId));
    expect(restored.state.encode(), game.state.encode());
    expect(restored.state.drawCount, 1);
    expect(restored.seed, 1);
    expect(restored.score, game.score);
    expect(restored.moves, game.moves);
    expect(restored.undos, game.undos);
    expect(restored.playTime, game.playTime);
    expect(restored.canUndo, isTrue);

    // Same next action, same record: counters, start time and think times
    // all continue.
    wait(9);
    game.draw();
    restored.draw();
    final original = abandon(game);
    final continued = abandon(restored);
    expect(continued.toJson(), original.toJson());
    expect(original.details[KlondikeStatKeys.tapMoves], greaterThan(0));
  });

  test('undo goes back through the whole game after a restore', () async {
    final game = controller();
    play(game);
    final before = (state: game.state.encode(), score: game.score);
    game.draw();
    await flush();

    final restored = restore(await storedSave(gameId));
    restored.undo();
    expect((state: restored.state.encode(), score: restored.score), before);
    expect(restored.undos, game.undos + 1);

    while (restored.canUndo) {
      restored.undo();
    }
    expect(restored.state.encode(), KlondikeState.deal(1).encode());
    expect(restored.score, 0);
  });

  test('play time continues from the saved time', () async {
    final game = controller();
    wait(30);
    game.draw();
    wait(15);
    game.pause();
    await flush();
    wait(3600);

    final restored = restore(await storedSave(gameId));
    expect(restored.playTime, const Duration(seconds: 45));
    wait(10);
    expect(restored.playTime, const Duration(seconds: 55));

    restored.draw();
    final record = abandon(restored);
    expect(record.playTime, const Duration(seconds: 55));
    expect(record.details[KlondikeStatKeys.timeToFirstMoveMs], 30000);
    expect(record.details[KlondikeStatKeys.longestThinkMs], 30000);
  });

  test('restore throws a FormatException for unreadable data', () {
    final json = controller().toJson();
    final invalid = <String, Map<String, Object?>>{
      'another version': {...json, 'version': 99},
      'a missing field': {...json}..remove('score'),
      'a wrong type': {...json, 'moves': 'many'},
      'a bad board': {...json, 'state': 'AS'},
      'a bad draw count': {...json, 'drawCount': 2},
      'a bad undo entry': {
        ...json,
        'history': [
          [0],
        ],
      },
      'no data': {},
    };
    for (final MapEntry(:key, :value) in invalid.entries) {
      expect(
        () => restore(
          SavedGame(
            gameId: gameId,
            moves: 0,
            playTime: Duration.zero,
            savedAt: now,
            data: value,
          ),
        ),
        throwsFormatException,
        reason: key,
      );
    }
  });

  test(
    'newGame without a move records nothing and saves the new deal',
    () async {
      final game = controller();
      game.newGame(seed: 2);

      await flush();
      expect(stats.records, isEmpty);
      final saved = await storedSave(gameId);
      expect(saved!.moves, 0);
      expect(restore(saved).state.encode(), KlondikeState.deal(2).encode());
    },
  );

  test('a new deal is a seed of the list of its draw count and difficulty', () {
    final game = KlondikeController(stats: stats, saves: saves);
    expect(game.difficulty, medium, reason: 'the default');
    expect(listOf(1, medium), contains(game.seed));
    expect(game.state.encode(), KlondikeState.deal(game.seed).encode());

    game.newGame(drawCount: 3, difficulty: hard);
    expect((game.state.drawCount, game.difficulty), (3, hard));
    expect(listOf(3, hard), contains(game.seed));
    expect(game.state.encode(), KlondikeState.deal(game.seed).encode());

    game.newGame(drawCount: 1);
    expect(game.difficulty, hard, reason: 'kept');
    expect(listOf(1, hard), contains(game.seed));

    final easyGame = KlondikeController(
      stats: stats,
      saves: saves,
      drawCount: 3,
      difficulty: easy,
    );
    expect(listOf(3, easy), contains(easyGame.seed));
  });

  test('an explicit seed has the difficulty of its list, or none', () {
    final hardSeed = listOf(1, hard).first;
    final game = KlondikeController(stats: stats, saves: saves, seed: hardSeed);
    expect(game.difficulty, hard);

    game.newGame(seed: unlistedSeed);
    expect(game.difficulty, isNull);
    game.draw();
    expect(abandon(game).difficulty, isNull);
    expect(game.difficulty, medium, reason: 'a new deal without a level');
  });

  test('records and saves the difficulty', () async {
    final game = KlondikeController(
      stats: stats,
      saves: saves,
      difficulty: hard,
      clock: () => now,
    );
    game.draw();
    await flush();
    final saved = await storedSave(gameId);
    expect(saved!.data['difficulty'], 'hard');
    expect(restore(saved).difficulty, hard);

    expect(abandon(game).difficulty, 'hard');
    await flush();
    expect((await storedRecords()).single.difficulty, 'hard');
  });

  test('a save without a difficulty takes it from the seed', () {
    final json = KlondikeController(
      stats: stats,
      saves: saves,
      seed: listOf(1, easy).first,
    ).toJson();
    SavedGame save(Map<String, Object?> data) => SavedGame(
      gameId: gameId,
      moves: 0,
      playTime: Duration.zero,
      savedAt: now,
      data: data,
    );

    expect(restore(save({...json}..remove('difficulty'))).difficulty, easy);
    final unlisted = KlondikeController(
      stats: stats,
      saves: saves,
      seed: unlistedSeed,
    ).toJson()..remove('difficulty');
    final restored = restore(save(unlisted));
    expect(restored.difficulty, isNull);
    restored.draw();
    expect(abandon(restored).difficulty, isNull);
  });

  test('newGame skips the seeds played in its draw mode and the deal on '
      'screen', () async {
    final [a, b, ...played] = listOf(1, medium);
    GameRecord recordOf(int seed, String variant) => GameRecord(
      gameId: gameId,
      variant: variant,
      seed: seed,
      startedAt: now,
      endedAt: now,
      playTime: Duration.zero,
      outcome: GameOutcome.abandoned,
      moves: 1,
      undos: 0,
      score: 0,
    );
    final stores = await createTestStores(
      savedData([
        for (final seed in played) recordOf(seed, 'draw1'),
        recordOf(b, 'draw3'),
      ]),
    );
    stats = stores.stats;
    saves = stores.saves;
    final game = KlondikeController(stats: stats, saves: saves, seed: a);

    game.newGame();
    expect(game.seed, b, reason: 'b was only played in draw 3');
    game.newGame();
    expect(game.seed, a, reason: 'a has no record, b is on screen');
    game.draw();
    game.newGame();
    expect(game.seed, b, reason: 'a is now recorded as abandoned');
    game.draw();
    game.newGame();
    expect(listOf(1, medium), contains(game.seed), reason: 'all played');
  });

  test('newGame after a move records an abandoned game once', () async {
    final game = controller();
    game.draw();
    wait(60);
    game.newGame(seed: 2);
    game.newGame(seed: 3);

    await flush();
    final record = stats.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.seed, 1);
    expect(record.moves, 1);
    expect(record.playTime, const Duration(minutes: 1));
    expect(record.details[KlondikeStatKeys.stockDraws], 1);
    expect((await storedRecords()).single.moves, 1);
    expect(restore(await storedSave(gameId)).seed, 3);
  });

  test('newGame records the old game and resets the counters', () {
    final game = controller();
    game.draw();
    game.draw();
    game.undo();

    game.newGame(drawCount: 3, seed: 2);
    expect(game.seed, 2);
    expect(game.moves, 0);
    expect(game.undos, 0);
    expect(game.score, 0);
    expect(game.canUndo, isFalse);
    expect(game.state.tableau, KlondikeState.deal(2, drawCount: 3).tableau);

    game.draw();
    game.newGame();
    final [first, second] = stats.records;
    expect(
      (first.seed, first.variant, first.moves, first.undos),
      (1, 'draw1', 2, 1),
    );
    expect(first.details[KlondikeStatKeys.stockDraws], 2);
    expect(
      (second.seed, second.variant, second.moves, second.undos),
      (2, 'draw3', 1, 0),
    );
    expect(second.details[KlondikeStatKeys.stockDraws], 1);
  });

  test('paused time is not play time', () {
    final game = controller();
    wait(10);
    game.pause();
    wait(3600);
    expect(game.playTime, const Duration(seconds: 10));

    game.resume();
    wait(5);
    expect(game.playTime, const Duration(seconds: 15));

    game.draw();
    expect(abandon(game).playTime, const Duration(seconds: 15));
  });

  test('records time to first move and longest think time', () {
    final game = controller();
    wait(4);
    game.draw();
    wait(9);
    game.draw();
    wait(2);
    game.undo();
    game.pause();
    wait(3600);
    game.resume();
    wait(3);
    game.draw();

    final details = abandon(game).details;
    expect(details[KlondikeStatKeys.timeToFirstMoveMs], 4000);
    expect(details[KlondikeStatKeys.longestThinkMs], 9000);
  });
}
