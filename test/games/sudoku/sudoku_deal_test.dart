import 'package:all_for_games/games/sudoku/sudoku_deal.dart';
import 'package:all_for_games/games/sudoku/sudoku_grader.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/games/sudoku/sudoku_solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sudoku_test_helpers.dart';

void main() {
  test('a seed always gives the same deal', () {
    final deal = SudokuDeal.deal(SudokuLevel.level1, 1);
    expect(SudokuGrid.encode(deal.givens), seed1Level1Givens);
    expect(SudokuGrid.encode(deal.solution), seed1Level1Solution);
  });

  test('every deal has one solution and keeps the level of its puzzle', () {
    for (final level in SudokuLevel.values) {
      for (var seed = 1; seed <= 6; seed++) {
        final deal = SudokuDeal.deal(level, seed);
        final reason = '${level.name} seed $seed';
        expect(solveSudoku(deal.givens, limit: 2), [
          deal.solution,
        ], reason: reason);
        expect(gradeSudoku(deal.givens).level, level, reason: reason);
      }
    }
  });

  test('seeds give different grids', () {
    final grids = {
      for (var seed = 1; seed <= 40; seed++)
        SudokuGrid.encode(SudokuDeal.deal(SudokuLevel.level5, seed).givens),
    };
    expect(grids, hasLength(40));
  });
}
