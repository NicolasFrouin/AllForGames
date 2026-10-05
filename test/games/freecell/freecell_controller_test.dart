import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/freecell/freecell_controller.dart';
import 'package:all_for_games/games/freecell/freecell_deal_picker.dart';
import 'package:all_for_games/games/freecell/freecell_deals.dart';
import 'package:all_for_games/games/freecell/freecell_difficulty.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'freecell_test_helpers.dart';

FreeCellPile col(int index) => FreeCellPile.cascade(index);
FreeCellPile cell(int index) => FreeCellPile.cell(index);
FreeCellPile home(Suit suit) => FreeCellPile.foundation(suit.index);

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = FreeCellController.gameId;
const easy = FreeCellDifficulty.easy;
const medium = FreeCellDifficulty.medium;
const hard = FreeCellDifficulty.hard;

List<int> listOf(FreeCellDifficulty difficulty) =>
    freecellDeals[difficulty.name]!;

/// A seed in none of the lists.
final unlistedSeed = Iterable.generate(
  5000,
  (i) => i + 1,
).firstWhere((seed) => freeCellDifficultyOfSeed(seed) == null);

/// The 5♣ goes on the 6♦ and frees the A♥, which goes home by itself.
final acePlay = board(cascades: ['AH 5C', '6D']);

/// The Q♠ goes home, and the K♠ follows: the game is won.
final lastMove = fullBoard(cascades: ['KS', 'QS']);

/// Every cascade goes down: the game can finish itself.
final finishBoard = fullBoard(cascades: ['KS QH', 'KH QS', 'KC QD', 'KD QC']);

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

  FreeCellController controller([FreeCellState? state]) => FreeCellController(
    stats: stats,
    saves: saves,
    seed: 1,
    initialState: state,
    clock: () => now,
  );

  FreeCellController restore(SavedGame? saved) => FreeCellController.restore(
    saved!.data,
    stats: stats,
    saves: saves,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Starts a new game, so [game] counts as abandoned, and returns its record.
  GameRecord abandon(FreeCellController game) {
    game.newGame();
    return stats.records.last;
  }

  /// Taps the first card that can move, from the left.
  void tapAny(FreeCellController game) {
    final moved = [
      for (var c = 0; c < 8; c++) col(c),
      for (var i = 0; i < 4; i++) cell(i),
    ].any((pile) => game.tap(pile, 1));
    expect(moved, isTrue);
  }

  /// Many taps and undos on the seed 1 deal, with time between them.
  void play(FreeCellController game) {
    for (var i = 0; i < 30; i++) {
      wait(i % 7);
      for (var c = 0; c < 8; c++) {
        game.tap(col(c), 1);
      }
      game.tap(cell(i % 4), 1);
      if (i % 5 == 0) game.undo();
    }
    // Saves the play time since the last action.
    game
      ..pause()
      ..resume();
  }

  test('a move frees an ace, which goes home by itself', () {
    final game = controller(acePlay);
    expect(game.move(col(0), 1, col(1)), isTrue);

    expect(game.state.cascades[1], cards('6D 5C'));
    expect(game.state.foundations[Suit.hearts.index], cards('AH'));
    expect(game.lastAction, FreeCellAction.move);
    expect(game.lastMovedCardIds, ['clubs-5', 'hearts-1']);
    expect(game.lastAutoMoveCount, 1);
    expect(game.moves, 1);
    expect(game.score, FreeCellScoring.toFoundation);

    final details = abandon(game).details;
    expect(details[FreeCellStatKeys.dragMoves], 1);
    expect(details[FreeCellStatKeys.autoMoves], 1);
    expect(details[FreeCellStatKeys.cardsToFoundation], 1);
  });

  test('undo takes back the move and its automatic moves', () {
    final game = controller(acePlay);
    final before = game.state;
    game.move(col(0), 1, col(1));

    game.undo();
    expect(game.state, same(before));
    expect(game.score, 0);
    expect(game.undos, 1);
    expect(game.moves, 1);
    expect(game.canUndo, isFalse);
    expect(game.lastAction, FreeCellAction.undo);
    expect(game.lastMovedCardIds, unorderedEquals(['clubs-5', 'hearts-1']));
    expect(abandon(game).details[FreeCellStatKeys.cardsToFoundation], 0);
  });

  test('a tap moves the card where the rules send it and counts a tap '
      'move', () {
    final game = controller(board(cascades: ['3D AS', '4C']));
    expect(game.tap(col(0), 1), isTrue);
    expect(game.state.foundations[Suit.spades.index], cards('AS'));
    expect(game.tap(col(0), 1), isTrue);
    expect(game.state.cascades[1], cards('4C 3D'));
    expect(game.tap(col(1), 1), isTrue, reason: 'to a free cell');
    expect(game.state.cells.first, card('3D'));

    final details = abandon(game).details;
    expect(details[FreeCellStatKeys.tapMoves], 3);
    expect(details[FreeCellStatKeys.dragMoves], isNull);
    expect(details[FreeCellStatKeys.freeCellUses], 1);
  });

  test('an illegal move returns false and changes nothing', () async {
    final game = controller(board(cascades: ['9H', '10D']));
    final before = game.state;
    var notified = 0;
    game.addListener(() => notified++);

    expect(game.move(col(0), 1, col(1)), isFalse);
    expect(game.move(col(0), 1, home(Suit.hearts)), isFalse);
    expect(game.tap(col(5), 1), isFalse);

    expect(game.state, same(before));
    expect(game.moves, 0);
    expect(game.canUndo, isFalse);
    expect(notified, 0);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('counts free cell uses, the most cells used at once, multi-card '
      'moves and moves to an empty column', () {
    final game = controller(board(cascades: ['4D 9H 8C', '10S', 'KD']));
    expect(game.move(col(0), 2, col(1)), isTrue);
    expect(game.move(col(0), 1, cell(0)), isTrue);
    expect(game.move(cell(0), 1, col(3)), isTrue);
    expect(game.move(col(2), 1, cell(0)), isTrue);
    expect(game.move(col(3), 1, cell(1)), isTrue);
    game.undo();
    game.undo();

    final details = abandon(game).details;
    expect(details[FreeCellStatKeys.supermoves], 1);
    expect(details[FreeCellStatKeys.freeCellUses], 3);
    expect(details[FreeCellStatKeys.mostFreeCellsUsed], 2);
    expect(details[FreeCellStatKeys.emptyColumnUses], 1);
    expect(details[FreeCellStatKeys.dragMoves], 5);
    expect(details[FreeCellStatKeys.autoMoves], isNull);
  });

  test('the last card wins: result, stopped timer and a won record', () async {
    final game = controller(lastMove);
    wait(30);
    expect(game.move(col(1), 1, home(Suit.spades)), isTrue);
    wait(600);
    game.resume();

    final result = game.result!;
    expect(result.outcome, GameOutcome.won);
    expect(result.variant, FreeCellController.variant);
    expect(result.seed, 1);
    expect(result.moves, 1);
    expect(result.score, 20 + FreeCellScoring.winBonus(1));
    expect(game.score, result.score);
    expect(result.playTime, const Duration(seconds: 30));
    expect(game.playTime, const Duration(seconds: 30));
    expect(result.details, {
      FreeCellStatKeys.dragMoves: 1,
      FreeCellStatKeys.mostFreeCellsUsed: 0,
      FreeCellStatKeys.autoMoves: 1,
      FreeCellStatKeys.cardsToFoundation: 52,
      FreeCellStatKeys.timeToFirstMoveMs: 30000,
      FreeCellStatKeys.longestThinkMs: 30000,
    });
    expect(game.canUndo, isFalse);
    expect(game.tap(col(0), 1), isFalse);

    await flush();
    expect(stats.records, [same(result)]);
    expect((await storedRecords()).map((r) => r.outcome), [GameOutcome.won]);
  });

  test('a win removes the saved game, and a won game is not saved', () async {
    // The Q♠ in a cell lets the hearts and spades go home, but the Q♥.
    final game = controller(
      fullBoard(cascades: ['KS 10H', 'QS', 'JH', 'QH KH']),
    );
    game.move(col(1), 1, cell(0));
    expect(game.state.foundationCardCount, 50);
    expect(game.result, isNull);
    await flush();
    expect((await storedSave(gameId))!.moves, 1);

    game.tap(col(3), 1);
    expect(game.result, isNotNull);
    game.pause();
    game.save();

    expect(saves[gameId], isNull);
    await flush();
    expect(await storedSave(gameId), isNull);
  });

  test('finish sends every card home as one move, lowest first', () async {
    final game = controller(finishBoard);
    expect(game.canFinish, isTrue);

    game.finish();
    expect(game.state.isWon, isTrue);
    expect(game.lastAction, FreeCellAction.finish);
    final ranks = [
      for (final id in game.lastMovedCardIds) int.parse(id.split('-').last),
    ];
    expect(ranks, [12, 12, 12, 12, 13, 13, 13, 13]);
    expect(game.moves, 1);
    expect(game.score, 80 + FreeCellScoring.winBonus(1));
    expect(game.canFinish, isFalse);
    expect(game.result!.details[FreeCellStatKeys.autoFinished], 1);
    await flush();
    expect(stats.records.single.won, isTrue);
  });

  test('finish does nothing while a card sits on a lower one', () {
    final game = controller();
    expect(game.canFinish, isFalse);
    game.finish();
    expect(game.moves, 0);
  });

  test('each action is seen once, with its kind', () {
    final game = controller(acePlay);
    expect(game.lastAction, FreeCellAction.deal);
    final dealt = game.actionSerial;

    game.move(col(0), 1, col(1));
    expect(game.actionSerial, dealt + 1);
    game.undo();
    expect(game.actionSerial, dealt + 2);
    game.newGame(seed: 1);
    expect(game.lastAction, FreeCellAction.deal);
    expect(game.lastMovedCardIds, isEmpty);
  });

  test('a continued game starts with no action to animate', () {
    final game = controller();
    game.tap(col(0), 1);
    final restored = FreeCellController.restore(
      game.toJson(),
      stats: stats,
      saves: saves,
    );
    expect(restored.lastAction, FreeCellAction.none);
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
    expect(game.tap(col(0), 1), isTrue);
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
    final original = abandon(game);
    final continued = abandon(restored);
    expect(continued.toJson(), original.toJson());
    expect(original.details[FreeCellStatKeys.tapMoves], greaterThan(0));
  });

  test('undo goes back through the whole game after a restore', () async {
    final game = controller();
    play(game);
    await flush();

    final restored = restore(await storedSave(gameId));
    while (restored.canUndo) {
      restored.undo();
    }
    expect(restored.state.encode(), FreeCellState.deal(1).encode());
    expect(restored.score, 0);
    expect(restored.undos, greaterThan(game.undos));
  });

  test('restore throws a FormatException for unreadable data', () {
    final json = controller().toJson();
    final invalid = <String, Map<String, Object?>>{
      'another version': {...json, 'version': 99},
      'a missing field': {...json}..remove('score'),
      'a wrong type': {...json, 'moves': 'many'},
      'a bad board': {...json, 'state': 'AS'},
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

  test('a new deal is a seed of the list of its difficulty', () {
    final game = FreeCellController(stats: stats, saves: saves);
    expect(game.difficulty, medium, reason: 'the default');
    expect(listOf(medium), contains(game.seed));
    expect(game.state.encode(), FreeCellState.deal(game.seed).encode());

    game.newGame(difficulty: hard);
    expect(game.difficulty, hard);
    expect(listOf(hard), contains(game.seed));
    expect(game.state.encode(), FreeCellState.deal(game.seed).encode());

    game.newGame();
    expect(game.difficulty, hard, reason: 'kept');
    expect(listOf(hard), contains(game.seed));

    final easyGame = FreeCellController(
      stats: stats,
      saves: saves,
      difficulty: easy,
    );
    expect(listOf(easy), contains(easyGame.seed));
  });

  test('an explicit seed has the difficulty of its list, or none', () {
    final game = FreeCellController(
      stats: stats,
      saves: saves,
      seed: listOf(hard).first,
    );
    expect(game.difficulty, hard);

    game.newGame(seed: unlistedSeed);
    expect(game.difficulty, isNull);
    game.tap(col(0), 1);
    expect(abandon(game).difficulty, isNull);
    expect(game.difficulty, medium, reason: 'a new deal without a level');
  });

  test('records and saves the difficulty; a save without it takes it from '
      'the seed', () async {
    final game = FreeCellController(
      stats: stats,
      saves: saves,
      difficulty: easy,
      clock: () => now,
    );
    game.tap(col(0), 1);
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
      variant: FreeCellController.variant,
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
    final game = FreeCellController(stats: stats, saves: saves, seed: a);

    game.newGame();
    expect(game.seed, b);
    game.newGame();
    expect(game.seed, a, reason: 'a has no record, b is on screen');
    game.tap(col(0), 1);
    game.newGame();
    expect(game.seed, b, reason: 'a is now recorded as abandoned');
  });

  test('newGame after a move records an abandoned game once', () async {
    final game = controller();
    game.tap(col(0), 1);
    wait(60);
    game.newGame(seed: 2);
    game.newGame(seed: 3);

    await flush();
    final record = stats.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.seed, 1);
    expect(record.moves, 1);
    expect(record.playTime, const Duration(minutes: 1));
    expect((await storedRecords()).single.moves, 1);
    expect(restore(await storedSave(gameId)).seed, 3);
  });

  test('records time to first move and longest think time', () {
    final game = controller();
    wait(4);
    tapAny(game);
    wait(9);
    tapAny(game);
    wait(2);
    game.undo();
    game.pause();
    wait(3600);
    game.resume();
    wait(3);
    tapAny(game);

    final details = abandon(game).details;
    expect(details[FreeCellStatKeys.timeToFirstMoveMs], 4000);
    expect(details[FreeCellStatKeys.longestThinkMs], 9000);
  });
}
