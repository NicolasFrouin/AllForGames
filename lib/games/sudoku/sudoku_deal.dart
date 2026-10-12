import '../../cards/deal_random.dart';
import 'sudoku_grid.dart';
import 'sudoku_level.dart';
import 'sudoku_puzzles.dart';
import 'sudoku_solver.dart';

/// The puzzle of a game: its [givens] (0 for an empty cell) and the one
/// [solution].
///
/// A deal is a puzzle of `sudokuPuzzles` for its level, picked and changed by
/// the seed: digits renamed, rows moved inside their band of three, bands
/// moved, the same for columns, and the grid maybe turned over its
/// diagonal. These changes keep the one solution and the level (the grader
/// gives the same grade), and make thousands of millions of grids from each
/// puzzle.
///
/// **Never change [SudokuDeal.deal]**: records and links name a deal by its
/// seed.
class SudokuDeal {
  const SudokuDeal(this.givens, this.solution);

  factory SudokuDeal.deal(SudokuLevel level, int seed) {
    final puzzles = sudokuPuzzles[level.index];
    final random = DealRandom(seed);
    final puzzle = SudokuGrid.decode(puzzles[random.nextInt(puzzles.length)]);
    List<int> shuffled(List<int> items) {
      for (var i = items.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final item = items[i];
        items[i] = items[j];
        items[j] = item;
      }
      return items;
    }

    // Line i of the deal is line lines[i] of the puzzle.
    List<int> lines() {
      final bands = shuffled([0, 1, 2]);
      return [
        for (final band in bands)
          for (final line in shuffled([0, 1, 2])) band * 3 + line,
      ];
    }

    final digits = [
      0,
      ...shuffled([1, 2, 3, 4, 5, 6, 7, 8, 9]),
    ];
    final rows = lines();
    final columns = lines();
    final turned = random.nextInt(2) == 1;
    final givens = [
      for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
        digits[puzzle[turned
            ? columns[SudokuGrid.columnOf(cell)] * 9 +
                  rows[SudokuGrid.rowOf(cell)]
            : rows[SudokuGrid.rowOf(cell)] * 9 +
                  columns[SudokuGrid.columnOf(cell)]]],
    ];
    return SudokuDeal(givens, solveSudoku(givens).single);
  }

  final List<int> givens;
  final List<int> solution;
}
