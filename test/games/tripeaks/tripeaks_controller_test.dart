import 'package:all_for_games/games/tripeaks/tripeaks_controller.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deal_picker.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deals.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_difficulty.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'tripeaks_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = TriPeaksController.gameId;
const easy = TriPeaksDifficulty.easy;
const medium = TriPeaksDifficulty.medium;
const hard = TriPeaksDifficulty.hard;

List<int> listOf(TriPeaksDifficulty difficulty) =>
    triPeaksDeals[difficulty.name]!;

/// A seed in none of the lists.
final unlistedSeed = Iterable.generate(
  5000,
  (i) => i + 1,
).firstWhere((seed) => triPeaksDifficultyOfSeed(seed) == null);

/// From the 4♠: the 5♣ then the 6♦ make a run; the K♠ waits for the stock.
final runBoard = board(
  tableau: {18: '5C', 19: '6D', 20: 'KS'},
  stock: '2H QD',
  waste: '4S',
);

/// The 5♣ on the last peak top wins, with two cards left in the stock.
final lastCard = board(tableau: {0: '5C'}, stock: '2H 9D', waste: '4S');

/// Every card on the waste.
TriPeaksState wonBoard() {
  final dealt = TriPeaksState.deal(1);
  return TriPeaksState(
    tableau: List.filled(TriPeaksState.positions, null),
    stock: const [],
    waste: [
      for (final card in [
        ...dealt.tableau.nonNulls,
        ...dealt.stock,
        ...dealt.waste,
      ])
        card.turned(faceUp: true),
    ],
  );
}

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

  TriPeaksController controller([TriPeaksState? state]) => TriPeaksController(
    stats: stats,
    saves: saves,
    seed: 1,
    initialState: state,
    clock: () => now,
  );

  TriPeaksController restore(SavedGame? saved) => TriPeaksController.restore(
    saved!.data,
    stats: stats,
    saves: saves,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Starts a new game, so [game] counts as abandoned, and returns its record.
  GameRecord abandon(TriPeaksController game) {
    game.newGame();
    return stats.records.last;
  }

  /// Plays the first card that fits, else draws.
  void step(TriPeaksController game) {
    final playable = game.state.playable;
    expect(playable.isEmpty ? game.draw() : game.play(playable.first), isTrue);
  }

  /// Many moves and undos on the seed 1 deal, with time between them.
  void play(TriPeaksController game) {
    for (var i = 0; i < 30; i++) {
      wait(i % 7);
      step(game);
      if (i % 5 == 0) game.undo();
    }
    expect(game.result, isNull);
    // Saves the play time since the last action.
    game
      ..pause()
      ..resume();
  }

  test('a card that fits goes onto the waste; a run scores more for each '
      'card', () {
    final game = controller(runBoard);
    expect(game.play(18), isTrue);
    expect(game.state.wasteTop, card('5C'));
    expect(game.run, 1);
    expect(game.score, TriPeaksScoring.card(1));
    expect(game.lastAction, TriPeaksAction.play);
    expect(game.lastMovedCardIds, ['clubs-5']);

    expect(game.play(19), isTrue);
    expect(game.run, 2);
    expect(game.score, 10 + 20);
    expect(game.moves, 2);

    final details = abandon(game).details;
    expect(details[TriPeaksStatKeys.longestRun], 2);
    expect(details[TriPeaksStatKeys.stockLeft], 2);
    expect(details[TriPeaksStatKeys.draws], isNull);
  });

  test('a draw turns the stock card over and starts a new run', () {
    final game = controller(runBoard);
    game.play(18);
    expect(game.draw(), isTrue);
    expect(game.state.wasteTop, card('QD'));
    expect(game.lastAction, TriPeaksAction.draw);
    expect(game.lastMovedCardIds, ['diamonds-12']);
    expect(game.run, 0);
    expect(game.score, 10);

    expect(game.play(20), isTrue, reason: 'K on Q');
    expect(game.run, 1);
    expect(game.score, 20);

    final details = abandon(game).details;
    expect(details[TriPeaksStatKeys.draws], 1);
    expect(details[TriPeaksStatKeys.longestRun], 1);
    expect(details[TriPeaksStatKeys.stockLeft], 1);
  });

  test('a card that does not fit or a draw from an empty stock returns '
      'false and changes nothing', () async {
    final game = controller(board(tableau: {18: '9C', 9: 'QH'}, waste: '4S'));
    final before = game.state;
    var notified = 0;
    game.addListener(() => notified++);

    expect(game.play(18), isFalse);
    expect(game.play(9), isFalse);
    expect(game.play(0), isFalse);
    expect(game.draw(), isFalse);

    expect(game.state, same(before));
    expect(game.moves, 0);
    expect(game.canUndo, isFalse);
    expect(notified, 0);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('undo takes back the card, its points and the run', () {
    final game = controller(runBoard);
    game.play(18);
    final before = game.state;
    game.play(19);

    game.undo();
    expect(game.state, same(before));
    expect(game.score, 10);
    expect(game.run, 1);
    expect(game.undos, 1);
    expect(game.moves, 2);
    expect(game.lastAction, TriPeaksAction.undo);
    expect(game.lastMovedCardIds, ['diamonds-6']);

    game.draw();
    game.undo();
    expect(game.lastMovedCardIds, ['diamonds-12']);
    expect(game.state.stock, cards('2H QD', faceUp: false));
  });

  test('clearing a peak scores a bonus', () {
    // The 9♥ at the top of the first peak, with the two other peaks gone.
    final game = controller(
      board(tableau: {0: '9H', 3: '8C', 4: '7D', 27: 'KS'}, waste: '6S'),
    );
    game
      ..play(4)
      ..play(3);
    expect(game.score, 10 + 20);
    expect(game.play(0), isTrue);
    expect(game.score, 10 + 20 + 30 + TriPeaksScoring.peak);
    expect(game.state.peaksCleared, 3);
    expect(game.result, isNull, reason: 'the K♠ is left');
  });

  test('the last card wins: the stock goes onto the waste as a bonus, the '
      'timer stops and the game is recorded', () async {
    final game = controller(lastCard);
    wait(30);
    expect(game.play(0), isTrue);
    wait(600);
    game.resume();

    expect(game.state.stock, isEmpty);
    expect(game.state.waste, cards('4S 5C 9D 2H'));
    expect(game.lastMovedCardIds, ['clubs-5', 'diamonds-9', 'hearts-2']);
    expect(game.lastBonusCount, 2);
    final result = game.result!;
    expect(result.outcome, GameOutcome.won);
    expect(result.variant, TriPeaksController.variant);
    expect(result.seed, 1);
    expect(result.moves, 1);
    expect(
      result.score,
      10 + TriPeaksScoring.peak + 2 * TriPeaksScoring.stockCardLeft,
    );
    expect(game.score, result.score);
    expect(result.playTime, const Duration(seconds: 30));
    expect(game.playTime, const Duration(seconds: 30));
    expect(result.details, {
      TriPeaksStatKeys.longestRun: 1,
      TriPeaksStatKeys.cardsCleared: 28,
      TriPeaksStatKeys.peaksCleared: 3,
      TriPeaksStatKeys.stockLeft: 2,
      TriPeaksStatKeys.timeToFirstMoveMs: 30000,
      TriPeaksStatKeys.longestThinkMs: 30000,
    });
    expect(game.canUndo, isFalse);
    expect(game.isStuck, isFalse);
    expect(game.draw(), isFalse);

    await flush();
    expect(stats.records, [same(result)]);
    expect((await storedRecords()).map((r) => r.outcome), [GameOutcome.won]);
  });

  test('a win removes the saved game, and a won game is not saved', () async {
    final game = controller(
      board(tableau: {0: '5C', 27: '6H'}, stock: '2H', waste: '4S'),
    );
    game.play(0);
    await flush();
    expect((await storedSave(gameId))!.moves, 1);

    game.play(27);
    expect(game.result, isNotNull);
    game.pause();
    game.save();

    expect(saves[gameId], isNull);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('stuck when nothing fits and the stock is empty; undo gets out of '
      'it', () {
    final game = controller(
      board(tableau: {18: '5C', 19: '9H'}, stock: 'JD', waste: '4S'),
    );
    game.play(18);
    expect(game.isStuck, isFalse);
    game.draw();
    expect(game.isStuck, isTrue);
    expect(game.result, isNull);
    game.undo();
    expect(game.isStuck, isFalse);
  });

  test('each action is seen once, with its kind', () {
    final game = controller(runBoard);
    expect(game.lastAction, TriPeaksAction.deal);
    final dealt = game.actionSerial;

    game.play(18);
    expect(game.actionSerial, dealt + 1);
    game.draw();
    expect(game.actionSerial, dealt + 2);
    game.undo();
    expect(game.actionSerial, dealt + 3);
    game.newGame(seed: 1);
    expect(game.lastAction, TriPeaksAction.deal);
    expect(game.lastMovedCardIds, isEmpty);
  });

  test('a continued game starts with no action to animate', () {
    final game = controller();
    step(game);
    final restored = TriPeaksController.restore(
      game.toJson(),
      stats: stats,
      saves: saves,
    );
    expect(restored.lastAction, TriPeaksAction.none);
  });

  test('every action and a pause save the game', () async {
    final game = controller();
    void expectSaved() {
      final saved = saves[gameId]!;
      expect(saved.moves, game.moves);
      expect(saved.playTime, game.playTime);
      expect(saved.data, game.toJson());
    }

    wait(5);
    step(game);
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
    expect(game.moves, greaterThan(10));
    expect(game.undos, greaterThan(0));
    await flush();

    final restored = restore(await storedSave(gameId));
    expect(restored.state.encode(), game.state.encode());
    expect(restored.seed, 1);
    expect(restored.score, game.score);
    expect(restored.run, game.run);
    expect(restored.moves, game.moves);
    expect(restored.undos, game.undos);
    expect(restored.playTime, game.playTime);
    expect(restored.canUndo, isTrue);

    // Same next action, same record: counters, start time and think times
    // all continue.
    wait(9);
    game.undo();
    restored.undo();
    expect(restored.state.encode(), game.state.encode());
    expect(restored.score, game.score);
    expect(restored.run, game.run);
    final original = abandon(game);
    final continued = abandon(restored);
    expect(continued.toJson(), original.toJson());
    expect(original.details[TriPeaksStatKeys.longestRun], greaterThan(0));
  });

  test('undo goes back through the whole game after a restore', () async {
    final game = controller();
    play(game);
    await flush();

    final restored = restore(await storedSave(gameId));
    while (restored.canUndo) {
      restored.undo();
    }
    expect(restored.state.encode(), TriPeaksState.deal(1).encode());
    expect(restored.score, 0);
    expect(restored.run, 0);
    expect(restored.undos, greaterThan(game.undos));
  });

  test('restore throws a FormatException for unreadable data', () {
    final json = controller().toJson();
    final invalid = <String, Map<String, Object?>>{
      'another version': {...json, 'version': 99},
      'a missing field': {...json}..remove('run'),
      'a wrong type': {...json, 'moves': 'many'},
      'a bad board': {...json, 'state': 'AS'},
      'a won board': {...json, 'state': wonBoard().encode()},
      'a bad undo entry': {
        ...json,
        'history': [
          [0, 0],
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

  test('a new deal is a seed of the list of its difficulty', () {
    final game = TriPeaksController(stats: stats, saves: saves);
    expect(game.difficulty, medium, reason: 'the default');
    expect(listOf(medium), contains(game.seed));
    expect(game.state.encode(), TriPeaksState.deal(game.seed).encode());

    game.newGame(difficulty: hard);
    expect(game.difficulty, hard);
    expect(listOf(hard), contains(game.seed));
    expect(game.state.encode(), TriPeaksState.deal(game.seed).encode());

    game.newGame();
    expect(game.difficulty, hard, reason: 'kept');
    expect(listOf(hard), contains(game.seed));

    final easyGame = TriPeaksController(
      stats: stats,
      saves: saves,
      difficulty: easy,
    );
    expect(listOf(easy), contains(easyGame.seed));
  });

  test('an explicit seed has the difficulty of its list, or none', () {
    final game = TriPeaksController(
      stats: stats,
      saves: saves,
      seed: listOf(hard).first,
    );
    expect(game.difficulty, hard);

    game.newGame(seed: unlistedSeed);
    expect(game.difficulty, isNull);
    step(game);
    expect(abandon(game).difficulty, isNull);
    expect(game.difficulty, medium, reason: 'a new deal without a level');
  });

  test('records and saves the difficulty; a save without it takes it from '
      'the seed', () async {
    final game = TriPeaksController(
      stats: stats,
      saves: saves,
      difficulty: easy,
      clock: () => now,
    );
    step(game);
    await flush();
    final saved = await storedSave(gameId);
    expect(saved!.data['difficulty'], 'easy');
    expect(restore(saved).difficulty, easy);
    final withoutLevel = SavedGame(
      gameId: gameId,
      moves: 1,
      playTime: Duration.zero,
      savedAt: now,
      data: {...saved.data}..remove('difficulty'),
    );
    expect(restore(withoutLevel).difficulty, easy);

    expect(abandon(game).difficulty, 'easy');
    await flush();
    expect((await storedRecords()).single.difficulty, 'easy');
  });

  test('newGame skips the played seeds and the deal on screen', () async {
    final [a, b, ...played] = listOf(medium);
    GameRecord recordOf(int seed) => GameRecord(
      gameId: gameId,
      variant: TriPeaksController.variant,
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
      savedData([for (final seed in played) recordOf(seed)]),
    );
    stats = stores.stats;
    saves = stores.saves;
    final game = TriPeaksController(stats: stats, saves: saves, seed: a);

    game.newGame();
    expect(game.seed, b);
    game.newGame();
    expect(game.seed, a, reason: 'a has no record, b is on screen');
    step(game);
    game.newGame();
    expect(game.seed, b, reason: 'a is now recorded as abandoned');
  });

  test('newGame after a move records an abandoned game once', () async {
    final game = controller();
    step(game);
    wait(60);
    game.newGame(seed: 2);
    game.newGame(seed: 3);

    await flush();
    final record = stats.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.seed, 1);
    expect(record.moves, 1);
    expect(record.playTime, const Duration(minutes: 1));
    expect(record.details[TriPeaksStatKeys.cardsCleared], 1);
    expect(record.details[TriPeaksStatKeys.stockLeft], 23);
    expect(record.details[TriPeaksStatKeys.peaksCleared], 0);
    expect((await storedRecords()).single.moves, 1);
    expect(restore(await storedSave(gameId)).seed, 3);
  });

  test('records time to first move and longest think time', () {
    final game = controller();
    wait(4);
    step(game);
    wait(9);
    step(game);
    wait(2);
    game.undo();
    game.pause();
    wait(3600);
    game.resume();
    wait(3);
    step(game);

    final details = abandon(game).details;
    expect(details[TriPeaksStatKeys.timeToFirstMoveMs], 4000);
    expect(details[TriPeaksStatKeys.longestThinkMs], 9000);
  });
}
