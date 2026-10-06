import 'package:all_for_games/games/tripeaks/tripeaks_deals.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_difficulty.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_solver.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tripeaks_test_helpers.dart';

const solver = TriPeaksSolver();

bool replaysToWin(TriPeaksState state, List<TriPeaksMove> moves) =>
    replayMoves(state, moves)?.isWon ?? false;

/// The 9♥ at place 9 sits on the 7♦ and the 8♣: the 7♦, the 8♣ and the
/// 9♥ win in that order, from a 6 on the waste.
final nearWon = board(tableau: {9: '9H', 18: '7D', 19: '8C'}, waste: '6S');

void main() {
  group('solver', () {
    test('solves a near-won board', () {
      final result = solver.solve(nearWon);
      expect(result.status, SolveStatus.solved);
      expect(result.solution, const [
        TriPeaksMove.play(18),
        TriPeaksMove.play(19),
        TriPeaksMove.play(9),
      ]);
    });

    test('keeps a card for a later waste when it must', () {
      // Both fit the 7♠, but the 8♥ must wait for the 9♣ of the stock.
      final state = board(
        tableau: {18: '8H', 19: '6D'},
        stock: '9C',
        waste: '7S',
      );
      final result = solver.solve(state);
      expect(result.solution, const [
        TriPeaksMove.play(19),
        TriPeaksMove.draw(),
        TriPeaksMove.play(18),
      ]);
      expect(replaysToWin(state, result.solution), isTrue);
      expect(solver.playGreedy(state), isNull, reason: 'it plays the 8♥');
    });

    test('solutions of real deals replay to a win', () {
      for (final seed in [1, 2, 3]) {
        final state = TriPeaksState.deal(seed);
        final result = solver.solve(state);
        expect(result.status, SolveStatus.solved, reason: 'seed $seed');
        expect(replaysToWin(state, result.solution), isTrue);
      }
    });

    test('reports unsolvable when no line wins', () {
      final state = board(tableau: {18: '5C'}, stock: '9H 2D', waste: 'KS');
      final result = solver.solve(state);
      expect(result.status, SolveStatus.unsolvable);
      expect(result.solution, isEmpty);
    });

    test('stops at maxNodes', () {
      final state = TriPeaksState.deal(triPeaksDeals['hard']!.first);
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

    test('the casual player plays the same game for a seed', () {
      final state = TriPeaksState.deal(triPeaksDeals['medium']!.first);
      final wins = [
        for (var seed = 0; seed < 40; seed++) solver.playCasual(state, seed),
      ];
      expect(wins, [
        for (var seed = 0; seed < 40; seed++) solver.playCasual(state, seed),
      ]);
      expect(wins, contains(true));
      expect(wins, contains(false));
    });
  });

  group('generated deals', () {
    test('have 100 to 200 distinct seeds per difficulty', () {
      expect(
        triPeaksDeals.keys,
        unorderedEquals(TriPeaksDifficulty.values.map((d) => d.name)),
      );
      for (final seeds in triPeaksDeals.values) {
        expect(seeds.length, inInclusiveRange(100, 200));
        expect(seeds, orderedEquals([...seeds]..sort()));
      }
      final all = triPeaksDeals.values.expand((seeds) => seeds).toList();
      expect(all.toSet(), hasLength(all.length));
    });

    for (final difficulty in TriPeaksDifficulty.values) {
      test('${difficulty.name} seeds still win and grade the same', () {
        for (final seed in triPeaksDeals[difficulty.name]!.take(3)) {
          final grade = solver.grade(seed);
          expect(grade.difficulty, difficulty, reason: 'seed $seed');
          final state = TriPeaksState.deal(seed);
          expect(replaysToWin(state, grade.result.solution), isTrue);
        }
      });
    }

    test('the levels differ for the casual player', () {
      double casualRate(TriPeaksDifficulty difficulty) {
        final seeds = triPeaksDeals[difficulty.name]!.take(10);
        return seeds
                .map((seed) => solver.grade(seed).casualWinRate)
                .reduce((a, b) => a + b) /
            seeds.length;
      }

      final easy = casualRate(TriPeaksDifficulty.easy);
      final medium = casualRate(TriPeaksDifficulty.medium);
      final hard = casualRate(TriPeaksDifficulty.hard);
      expect(easy, greaterThan(medium + 0.2));
      expect(medium, greaterThan(hard + 0.05));
    });
  });
}
