import 'dart:math';

import 'package:all_for_games/games/sudoku/sudoku_grader.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/games/sudoku/sudoku_puzzles.dart';
import 'package:all_for_games/games/sudoku/sudoku_solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// [grid] with its digits relabeled, its rows and columns shuffled within
/// their bands and stacks, the bands and stacks shuffled, maybe transposed.
List<int> shuffledSymmetry(List<int> grid, Random random) {
  final digits = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
  List<int> lines() => [
    for (final band in [0, 1, 2]..shuffle(random))
      for (final line in [0, 1, 2]..shuffle(random)) band * 3 + line,
  ];
  final rows = lines();
  final columns = lines();
  final transpose = random.nextBool();
  return [
    for (var row = 0; row < 9; row++)
      for (var column = 0; column < 9; column++)
        switch (transpose
            ? grid[columns[column] * 9 + rows[row]]
            : grid[rows[row] * 9 + columns[column]]) {
          0 => 0,
          final digit => digits[digit - 1],
        },
  ];
}

void main() {
  test('every level has 50 puzzles', () {
    expect(sudokuPuzzles, hasLength(SudokuLevel.values.length));
    for (final puzzles in sudokuPuzzles) {
      expect(puzzles, hasLength(50));
    }
  });

  test('no puzzle comes twice', () {
    final all = [for (final puzzles in sudokuPuzzles) ...puzzles];
    expect(all.toSet(), hasLength(all.length));
  });

  for (final level in SudokuLevel.values) {
    test('the puzzles of ${level.name} have one solution and that level', () {
      for (final puzzle in sudokuPuzzles[level.index]) {
        expect(puzzle, hasLength(SudokuGrid.cellCount));
        final grid = SudokuGrid.decode(puzzle);
        final solutions = solveSudoku(grid, limit: 2);
        expect(solutions, hasLength(1), reason: puzzle);
        final solution = solutions.single;
        final grade = gradeSudoku(
          grid,
          onStep: (technique, grader) {
            for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
              final value = grader.values[cell];
              final sound = value == 0
                  ? grader.candidates[cell] & 1 << solution[cell] != 0
                  : value == solution[cell];
              if (!sound) fail('$puzzle, ${technique.name}: cell $cell');
            }
          },
        );
        expect(grade.level, level, reason: puzzle);
      }
    });
  }

  test('a turned and relabeled puzzle keeps its level', () {
    // The game deals each puzzle under a random symmetry.
    final random = Random(12);
    for (final level in SudokuLevel.values) {
      for (final puzzle in sudokuPuzzles[level.index]) {
        final grid = SudokuGrid.decode(puzzle);
        for (var i = 0; i < 3; i++) {
          final turned = shuffledSymmetry(grid, random);
          expect(hasOneSolution(turned), isTrue);
          expect(gradeSudoku(turned).level, level, reason: puzzle);
        }
      }
    }
  });
}
