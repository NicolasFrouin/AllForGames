/// The 12 levels of Sudoku, from many givens and simple steps to puzzles
/// that need long chains of reasoning. The grader (`gradeSudoku`) sorts the
/// puzzles of `sudokuPuzzles` into them.
///
/// Pure Dart without imports: the generator tool runs it outside Flutter.
enum SudokuLevel {
  level1,
  level2,
  level3,
  level4,
  level5,
  level6,
  level7,
  level8,
  level9,
  level10,
  level11,
  level12;

  /// 1 to 12.
  int get number => index + 1;

  static SudokuLevel ofNumber(int number) => values[number - 1];
}
