import 'package:all_for_games/games/klondike/klondike_auto_win.dart';
import 'package:all_for_games/games/klondike/klondike_solver.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'klondike_test_helpers.dart';

/// A winnable draw 3 deal (in `klondikeDeals`) that random moves lose fast.
final deal = KlondikeState.deal(213, drawCount: 3);

void main() {
  const solver = KlondikeSolver();

  test('solving in slices finds the solution of one search', () async {
    final sliced = await solver.solveInSlices(deal, slice: 10);
    final whole = solver.solve(deal);
    expect(sliced.status, SolveStatus.solved);
    expect(sliced.nodes, whole.nodes);
    expect(sliced.solution, whole.solution);
  });

  test('from a position it wins from, the plan takes nothing back', () async {
    final plan = (await planAutoWin([deal]))!;
    expect(plan.undos, 0);
    expect(replayActions(deal, plan.actions)!.isWon, isTrue);
  });

  test('from a lost position, the plan goes back to the latest position it '
      'wins from', () async {
    final states = [deal];
    for (final action in actionsToLose(deal, seed: 2)) {
      states.add(action.applyTo(states.last)!);
    }
    expect(solver.solve(states.last).isSolved, isFalse, reason: 'lost');

    final plan = (await planAutoWin(states))!;
    expect(plan.undos, greaterThan(0));
    final from = states.length - 1 - plan.undos;
    expect(replayActions(states[from], plan.actions)!.isWon, isTrue);
    expect(
      solver.solve(states[from + 1]).isSolved,
      isFalse,
      reason: 'the next move lost the game',
    );
  });

  test('no plan when the solver wins from no position', () async {
    expect(await planAutoWin([deal], maxNodes: 1), isNull);
  });
}
