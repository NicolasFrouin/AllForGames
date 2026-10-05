import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mahjong_test_helpers.dart';

void main() {
  test('finds an order that clears a deal', () {
    for (var seed = 1; seed <= 20; seed++) {
      final state = generateDeal(
        MahjongDifficulty.medium.layout(),
        seed,
        trapPercent: MahjongDifficulty.medium.trapPercent,
      ).state;

      final solution = solveMahjong(state);

      expect(solution, isNotNull, reason: '$seed');
      expect(state.isSolvedBy(solution!), isTrue);
    }
  });

  test('finds none when the last two tiles of a face lie on each other', () {
    final state = board(layoutOf([(0, 0, 0), (4, 0, 0), (0, 0, 1)]), [
      dots1,
      dots2,
      dots1,
    ]);

    expect(solveMahjong(board(row(2), [dots1, dots1])), isNotNull);
    expect(solveMahjong(state), isNull);
  });

  test('finds none when two pairs wait on each other', () {
    // Two stacks: a 1 on a 2, and a 2 on a 1.
    final state = board(
      layoutOf([(0, 0, 0), (0, 0, 1), (4, 0, 0), (4, 0, 1)]),
      [dots2, dots1, dots1, dots2],
    );

    expect(solveMahjong(state), isNull);
  });

  group('mending the order after a match', () {
    // Four 1s in a row, then four 2s: the order pairs the ends.
    final state = board(row(4), [dots1, dots1, dots1, dots1]);
    final order = [(0, 3), (1, 2)];

    test('drops a pair of the order', () {
      expect(mendSolution(state.match(0, 3)!, order, 0, 3), [(1, 2)]);
    });

    test('pairs the partners of two tiles matched across pairs', () {
      final after = board(row(4), [dots1, dots1, dots1, dots1]).match(0, 3)!;

      // Matched 0 with 3 instead: 1 and 2 go together.
      expect(mendSolution(after, [(0, 1), (3, 2)], 0, 3), [(1, 2)]);
    });

    test('gives up when the partners lie on each other', () {
      // Four 1s: one on another, and two on the table.
      final layout = layoutOf([(0, 0, 0), (0, 0, 1), (4, 0, 0), (8, 0, 0)]);
      final state = board(layout, [dots1, dots1, dots1, dots1]);
      final order = [(1, 2), (0, 3)];
      expect(state.isSolvedBy(order), isTrue);

      // The two on the table go together: the top one is left on its only
      // partner.
      expect(mendSolution(state.match(2, 3)!, order, 2, 3), isNull);
    });
  });
}
