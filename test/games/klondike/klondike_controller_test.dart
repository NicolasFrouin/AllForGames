import 'dart:math';

import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/games/klondike/playing_card.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stats_store.dart';
import 'klondike_test_helpers.dart';

PileRef tab(int index) => PileRef.tableau(index);
PileRef fnd(Suit suit) => PileRef.foundation(suit.index);

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late StatsStore store;
  late DateTime now;

  setUp(() async {
    store = await createTestStatsStore();
    now = DateTime.utc(2026, 1, 1, 12);
  });

  KlondikeController controller([KlondikeState? state]) => KlondikeController(
    stats: store,
    seed: 1,
    initialState: state,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  test('draw counts a move and a stock draw', () async {
    final game = controller();
    expect(game.draw(), isTrue);
    expect(game.moves, 1);
    expect(game.state.waste, hasLength(1));

    await flush();
    final saved = (await savedGames()).single;
    expect(saved.outcome, GameOutcome.abandoned);
    expect(saved.moves, 1);
    expect(saved.details[KlondikeStatKeys.stockDraws], 1);
    expect(store.records, isEmpty);
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
    expect(await savedGames(), isEmpty);
  });

  test('undo restores the state and score and counts an undo', () async {
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
    await flush();
    expect((await savedGames()).single.undos, 1);
  });

  test('score never goes below zero', () async {
    final game = controller(board(waste: [card('5D'), card('AS')]));
    expect(game.move(PileRef.waste, 1, fnd(Suit.spades)), isTrue);
    expect(game.score, 10);

    expect(game.draw(), isTrue, reason: 'recycles the waste for -100');
    expect(game.score, 0);
    game.draw();
    expect(game.draw(), isTrue, reason: 'recycles again at score 0');
    expect(game.score, 0);
    await flush();
    expect(
      (await savedGames()).single.details[KlondikeStatKeys.stockRecycles],
      2,
    );

    game.undo();
    game.undo();
    game.undo();
    expect(game.score, 10);
  });

  test('tap sends a card to its foundation and counts a tap move', () async {
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

    await flush();
    final details = (await savedGames()).single.details;
    expect(details[KlondikeStatKeys.tapMoves], 1);
    expect(details[KlondikeStatKeys.dragMoves], isNull);
    expect(details[KlondikeStatKeys.cardsRevealed], 1);
    expect(details[KlondikeStatKeys.cardsToFoundation], 1);
  });

  test('an undone reveal does not count as a revealed card', () async {
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

    await flush();
    final details = (await savedGames()).single.details;
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
    await flush();
    expect((await savedGames()).single.won, isFalse);
    expect(game.result, isNull);

    wait(10);
    expect(game.tap(tab(0), 1), isTrue);
    wait(600);

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
    expect(store.records, [same(result)]);
    expect((await savedGames()).map((r) => r.outcome), [GameOutcome.won]);
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
    expect(store.records.single.won, isTrue);
  });

  test('autoComplete does nothing while cards are face down', () {
    final game = controller();
    game.autoComplete();
    expect(game.moves, 0);
    expect(game.state.foundationCardCount, 0);
  });

  test('abandon without a move records nothing', () async {
    final game = controller();
    game.abandon();
    await flush();
    expect(store.records, isEmpty);
    expect(game.draw(), isFalse);
  });

  test('abandon after a move records an abandoned game once', () async {
    final game = controller();
    game.draw();
    wait(60);
    game.abandon();
    game.abandon();

    await flush();
    final record = store.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.moves, 1);
    expect(record.playTime, const Duration(minutes: 1));
    expect(record.details[KlondikeStatKeys.stockDraws], 1);
    expect((await savedGames()).single.moves, 1);
  });

  test('newGame records the old game and resets the counters', () async {
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
    expect(
      game.state.tableau,
      KlondikeState.deal(Random(2), drawCount: 3).tableau,
    );

    game.draw();
    game.abandon();
    await flush();
    final [first, second] = store.records;
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

  test('paused time is not play time', () async {
    final game = controller();
    wait(10);
    game.pause();
    wait(3600);
    expect(game.playTime, const Duration(seconds: 10));

    game.resume();
    wait(5);
    expect(game.playTime, const Duration(seconds: 15));

    game.draw();
    game.abandon();
    game.resume();
    wait(60);
    expect(game.playTime, const Duration(seconds: 15));
    await flush();
    expect(store.records.single.playTime, const Duration(seconds: 15));
  });

  test('records time to first move and longest think time', () async {
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
    game.abandon();

    await flush();
    final details = store.records.single.details;
    expect(details[KlondikeStatKeys.timeToFirstMoveMs], 4000);
    expect(details[KlondikeStatKeys.longestThinkMs], 9000);
  });
}
