import 'sudoku_grid.dart';

/// The solutions of [grid] (81 values, 0 for an empty cell), at most
/// [limit]: two tell whether a puzzle has one solution only.
///
/// A search over bit masks that fills the cell with the fewest candidates
/// first: a few milliseconds at most for any 9 x 9 puzzle.
List<List<int>> solveSudoku(List<int> grid, {int limit = 1}) {
  final cells = [...grid];
  final rows = List.filled(9, 0);
  final columns = List.filled(9, 0);
  final boxes = List.filled(9, 0);
  for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
    final value = cells[cell];
    if (value == 0) continue;
    final bit = 1 << value;
    final row = SudokuGrid.rowOf(cell);
    final column = SudokuGrid.columnOf(cell);
    final box = SudokuGrid.boxOf(cell);
    if ((rows[row] | columns[column] | boxes[box]) & bit != 0) return const [];
    rows[row] |= bit;
    columns[column] |= bit;
    boxes[box] |= bit;
  }
  final solutions = <List<int>>[];

  void search() {
    var best = -1;
    var bestFree = 0;
    var bestCount = 10;
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
      if (cells[cell] != 0) continue;
      final free =
          ~(rows[SudokuGrid.rowOf(cell)] |
              columns[SudokuGrid.columnOf(cell)] |
              boxes[SudokuGrid.boxOf(cell)]) &
          0x3FE;
      final count = _bitCount(free);
      if (count < bestCount) {
        best = cell;
        bestFree = free;
        bestCount = count;
        if (count <= 1) break;
      }
    }
    if (best < 0) {
      solutions.add([...cells]);
      return;
    }
    final row = SudokuGrid.rowOf(best);
    final column = SudokuGrid.columnOf(best);
    final box = SudokuGrid.boxOf(best);
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      if (bestFree & bit == 0) continue;
      cells[best] = digit;
      rows[row] |= bit;
      columns[column] |= bit;
      boxes[box] |= bit;
      search();
      rows[row] &= ~bit;
      columns[column] &= ~bit;
      boxes[box] &= ~bit;
      cells[best] = 0;
      if (solutions.length >= limit) return;
    }
  }

  search();
  return solutions;
}

/// Whether [grid] has exactly one solution.
bool hasOneSolution(List<int> grid) => solveSudoku(grid, limit: 2).length == 1;

int _bitCount(int mask) {
  var count = 0;
  for (var bits = mask; bits != 0; bits &= bits - 1) {
    count++;
  }
  return count;
}
