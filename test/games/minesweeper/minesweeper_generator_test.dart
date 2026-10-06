import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_generator.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_solver.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mines of the Expert board of seed 1, first tapped in the middle
/// ([seed1HardTap]), on the Dart VM. A seed must give the same board on
/// every platform: `test/cards/deals_on_web_test.dart` checks it on the web.
const seed1HardMines = [
  6, 9, 11, 17, 21, 28, 31, 39, 40, 43, 58, 61, 81, 82, 85, 88, 90, 93, 99, //
  101, 113, 114, 119, 128, 135, 136, 138, 142, 144, 145, 146, 165, 166, 167,
  174, 195, 201, 205, 206, 207, 208, 212, 219, 222, 229, 235, 238, 245, 248,
  257, 266, 267, 271, 272, 274, 276, 277, 278, 289, 300, 301, 305, 319, 320,
  321, 322, 323, 324, 328, 343, 349, 350, 361, 362, 364, 367, 368, 374, 378,
  392, 393, 403, 409, 411, 416, 420, 421, 424, 434, 441, 443, 453, 454, 457,
  458, 460, 467, 468, 478,
];

/// Row 8, column 15 of the 30 x 16 board.
const seed1HardTap = 8 * 30 + 15;

List<int> seed1Hard() => generateMines(
  columns: 30,
  rows: 16,
  mineCount: 99,
  seed: 1,
  firstTap: seed1HardTap,
).mines;

/// The board of [seed] for [difficulty], after the first tap at [tap].
MinesweeperState deal(
  MinesweeperDifficulty difficulty,
  int seed,
  int tap, {
  bool turned = false,
}) {
  final (columns, rows) = difficulty.size(turned: turned);
  final deal = generateMines(
    columns: columns,
    rows: rows,
    mineCount: difficulty.mines,
    seed: seed,
    firstTap: tap,
  );
  return MinesweeperState.withMines(columns, rows, deal.mines).open(tap)!;
}

void main() {
  test('the Expert board of seed 1 is the same as always', () {
    expect(seed1Hard(), seed1HardMines);
  });

  for (final difficulty in MinesweeperDifficulty.values) {
    for (final turned in [false, true]) {
      test(
        '${difficulty.name}${turned ? ', turned' : ''}: the first tap opens an '
        'area, and logic alone clears the board from there',
        () {
          final (columns, rows) = difficulty.size(turned: turned);
          final length = columns * rows;
          // The corners, then taps all over the board.
          final taps = [0, columns - 1, length - columns, length - 1];
          for (var seed = 1; seed <= 250; seed++) {
            final tap = seed <= taps.length
                ? taps[seed - 1]
                : DealRandom(seed).nextInt(length);
            final state = deal(difficulty, seed, tap, turned: turned);
            final reason = 'seed $seed, tap $tap';

            expect(state.mines, hasLength(difficulty.mines), reason: reason);
            expect(state.countAt(tap), 0, reason: reason);
            expect(state.isLost, isFalse, reason: reason);
            final solver = MinesweeperSolver.of(state);
            expect(solver.solve(), isTrue, reason: reason);
          }
        },
      );
    }
  }

  test('the same seed and tap give the same board; others give others', () {
    const difficulty = MinesweeperDifficulty.medium;
    final board = deal(difficulty, 7, 100).mines;

    expect(deal(difficulty, 7, 100).mines, board);
    expect(deal(difficulty, 8, 100).mines, isNot(board));
    expect(deal(difficulty, 7, 101).mines, isNot(board));
  });
}
