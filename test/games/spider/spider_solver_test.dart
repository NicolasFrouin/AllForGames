import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/spider/spider_deals.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_solver.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spider_test_helpers.dart';

const solver = SpiderSolver();

bool replaysToWin(SpiderState state, List<SpiderMove> moves) =>
    replayMoves(state, moves)?.isWon ?? false;

void main() {
  test('wins a near-won board in one move', () {
    final result = solver.solve(nearWon());
    expect(result.status, SolveStatus.solved);
    expect(result.solution, [const ColumnMove(1, 1, 0)]);
  });

  test('deals from the stock when it must', () {
    // The ace of spades and four hearts are in the stock: the hearts then
    // gather on the 5, and the other hearts on the king.
    const hearts = Suit.hearts;
    final state = board(
      columns: [
        run(Suit.spades, 13, 2),
        for (var rank = 13; rank >= 5; rank--) run(hearts, rank, rank),
      ],
      stock: [
        for (final code in ['AH', '2H', '3H', '4H', 'AS'])
          card(code, up: false),
      ],
    );
    final result = solver.solve(state);
    expect(result.status, SolveStatus.solved);
    expect(result.solution.first, const StockDeal());
    expect(replaysToWin(state, result.solution), isTrue);
  });

  test('a board without a full run is unsolvable', () {
    final state = board(
      columns: [
        [card('2S', up: false), card('KS', deck: 1)],
        [card('AS')],
      ],
    );
    expect(solver.solve(state).status, SolveStatus.unsolvable);
  });

  test('a solution replays to a win on the rules', () {
    final state = SpiderState.deal(
      spiderDeals['easy']!.first,
      SpiderDifficulty.easy,
    );
    final result = solver.solve(
      state,
      maxNodes: SpiderSolver.maxNodesFor[SpiderDifficulty.easy]!,
    );
    expect(result.isSolved, isTrue);
    expect(replaysToWin(state, result.solution), isTrue);
    expect(replayMoves(state, [const ColumnMove(0, 5, 1)]), isNull);
  });

  // The seed lists hold only if the solver still wins their deals: a sample
  // of each list, solved again and replayed.
  for (final difficulty in SpiderDifficulty.values) {
    test('seeds of the ${difficulty.name} list replay to a win', () {
      final seeds = spiderDeals[difficulty.name]!;
      expect(seeds.length, greaterThanOrEqualTo(300));
      expect(seeds.toSet(), hasLength(seeds.length));
      for (final seed in [seeds[seeds.length ~/ 3], seeds.last]) {
        final state = SpiderState.deal(seed, difficulty);
        final result = solver.solve(
          state,
          maxNodes: SpiderSolver.maxNodesFor[difficulty]!,
        );
        expect(result.isSolved, isTrue, reason: 'seed $seed');
        expect(replaysToWin(state, result.solution), isTrue, reason: '$seed');
      }
    });
  }
}
