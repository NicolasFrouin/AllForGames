import 'package:all_for_games/games/freecell/freecell_deals.dart';
import 'package:all_for_games/games/freecell/freecell_difficulty.dart';
import 'package:all_for_games/games/freecell/freecell_solver.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freecell_test_helpers.dart';

const solver = FreeCellSolver();

bool replaysToWin(FreeCellState state, List<FreeCellMove> moves) =>
    replayMoves(state, moves)?.isWon ?? false;

/// Wins once the 9♣ leaves the 8♥ for a free cell.
final nearWon = fullBoard(
  cascades: [
    'KS QH JS 10H 9S',
    'KH QS JH 10S 8H 9C',
    'KC QD JC 10D',
    'KD QC JD 10C 9H 9D',
  ],
);

void main() {
  group('solver', () {
    test('solves a near-won board', () {
      final result = solver.solve(nearWon);
      expect(result.status, SolveStatus.solved);
      expect(replaysToWin(nearWon, result.solution), isTrue);
    });

    test('solutions of real deals replay to a win', () {
      for (final seed in [1, 2, 3]) {
        final state = FreeCellState.deal(seed);
        final result = solver.solve(state);
        expect(result.status, SolveStatus.solved, reason: 'seed $seed');
        expect(replaysToWin(state, result.solution), isTrue);
      }
    });

    test('with fewer free cells, the solution only uses those', () {
      final state = FreeCellState.deal(1);
      final result = solver.solve(state, cells: 2);
      expect(result.status, SolveStatus.solved);
      expect(replaysToWin(state, result.solution), isTrue);
      final cellsUsed = {
        for (final move in result.solution)
          if (move.to.type == FreeCellPileType.cell) move.to.index,
      };
      expect(cellsUsed, everyElement(lessThan(2)));
    });

    test('reports unsolvable when no move is left', () {
      // Hearts on every cascade: nothing stacks, and the aces are buried.
      final state = fullBoard(
        cascades: [
          'AH AS 2S 3S 4S 3H',
          '5S 6S 7S 4H',
          '8S 9S 10S 5H',
          'JS QS KS 6H',
          '2H 7H',
          '8H',
          '9H',
          '10H JH QH KH',
        ],
      );
      final result = solver.solve(state, cells: 0);
      expect(result.status, SolveStatus.unsolvable);
      expect(result.solution, isEmpty);
      expect(solver.solve(state).status, SolveStatus.solved);
    });

    test('stops at maxNodes', () {
      final state = FreeCellState.deal(freecellDeals['hard']!.first);
      final result = solver.solve(state, maxNodes: 5);
      expect(result.status, SolveStatus.unknown);
      expect(result.nodes, 5);
      expect(result.solution, isEmpty);
    });

    test('the greedy player wins an easy board with real moves', () {
      final moves = solver.playGreedy(nearWon);
      expect(moves, isNotNull);
      expect(replaysToWin(nearWon, moves!), isTrue);
    });
  });

  group('generated deals', () {
    test('have 300 to 500 distinct seeds per difficulty', () {
      expect(
        freecellDeals.keys,
        unorderedEquals(FreeCellDifficulty.values.map((d) => d.name)),
      );
      for (final seeds in freecellDeals.values) {
        expect(seeds.length, inInclusiveRange(300, 500));
        expect(seeds, orderedEquals([...seeds]..sort()));
      }
      final all = freecellDeals.values.expand((seeds) => seeds).toList();
      expect(all.toSet(), hasLength(all.length));
    });

    for (final difficulty in FreeCellDifficulty.values) {
      test('${difficulty.name} seeds still win and grade the same', () {
        for (final seed in freecellDeals[difficulty.name]!.take(3)) {
          final grade = solver.grade(seed);
          expect(grade.difficulty, difficulty, reason: 'seed $seed');
          final state = FreeCellState.deal(seed);
          expect(replaysToWin(state, grade.result.solution), isTrue);
        }
      });
    }
  });
}
