/// The geometry of the 9 x 9 grid: cells 0 to 80, row by row; the 27 units
/// (rows, columns, boxes) where each digit goes once.
///
/// Pure Dart: the rules, the solver, the grader and the tool use it.
abstract final class SudokuGrid {
  static const size = 9;
  static const cellCount = size * size;

  static int rowOf(int cell) => cell ~/ size;
  static int columnOf(int cell) => cell % size;
  static int boxOf(int cell) => cell ~/ 27 * 3 + cell % size ~/ 3;

  /// Rows 0 to 8, then columns (9 to 17), then boxes (18 to 26): the cells
  /// of each unit, in reading order.
  static final List<List<int>> units = [
    for (var row = 0; row < size; row++)
      [for (var column = 0; column < size; column++) row * size + column],
    for (var column = 0; column < size; column++)
      [for (var row = 0; row < size; row++) row * size + column],
    for (var box = 0; box < size; box++)
      [
        for (var i = 0; i < size; i++)
          (box ~/ 3 * 3 + i ~/ 3) * size + box % 3 * 3 + i % 3,
      ],
  ];

  /// The 20 other cells of each cell's row, column and box.
  static final List<List<int>> peers = [
    for (var cell = 0; cell < cellCount; cell++)
      [
        for (var other = 0; other < cellCount; other++)
          if (other != cell &&
              (rowOf(other) == rowOf(cell) ||
                  columnOf(other) == columnOf(cell) ||
                  boxOf(other) == boxOf(cell)))
            other,
      ],
  ];

  /// [grid] as 81 characters, `0` for an empty cell.
  static String encode(List<int> grid) => grid.join();

  /// The 81 values of [text] (`0` or `.` for an empty cell). Throws a
  /// [FormatException] for anything else.
  static List<int> decode(String text) {
    if (text.length != cellCount) {
      throw FormatException('A Sudoku grid has 81 cells', text);
    }
    return [
      for (final unit in text.codeUnits)
        switch (unit) {
          0x2E => 0,
          >= 0x30 && <= 0x39 => unit - 0x30,
          _ => throw FormatException('Bad Sudoku cell', text),
        },
    ];
  }
}
