/// Levels of Minesweeper: the classic Beginner, Intermediate and Expert
/// boards, [columns] by [rows] with [mines].
///
/// Pure Dart: the rules, the generator and the tool use it without Flutter.
enum MinesweeperDifficulty {
  easy(9, 9, 10),
  medium(16, 16, 40),
  hard(30, 16, 99);

  const MinesweeperDifficulty(this.columns, this.rows, this.mines);

  final int columns;
  final int rows;
  final int mines;

  /// Columns and rows of the board, swapped when [turned] (for tall
  /// screens).
  (int, int) size({bool turned = false}) =>
      turned ? (rows, columns) : (columns, rows);
}
