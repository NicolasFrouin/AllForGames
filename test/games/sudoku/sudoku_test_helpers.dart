import 'package:all_for_games/games/sudoku/sudoku_deal.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';

/// `SudokuDeal.deal(SudokuLevel.level1, 1)`: the VM and the web must give
/// it (deals_on_web_test).
const seed1Level1Givens =
    '903200000205917403018060000590040276840756100630100004'
    '026000008704000900089420567';
const seed1Level1Solution =
    '973284615265917483418365792591843276842756139637192854'
    '126579348754638921389421567';

/// The deal of the seed 1 at level 1, with every empty cell but [left]
/// filled from the solution: one digit wins it.
SudokuDeal almostSolved({int left = 1}) {
  final givens = SudokuGrid.decode(seed1Level1Givens);
  final solution = SudokuGrid.decode(seed1Level1Solution);
  final empty = [
    for (var cell = 0; cell < 81; cell++)
      if (givens[cell] == 0) cell,
  ];
  for (final cell in empty.skip(left)) {
    givens[cell] = solution[cell];
  }
  return SudokuDeal(givens, solution);
}
