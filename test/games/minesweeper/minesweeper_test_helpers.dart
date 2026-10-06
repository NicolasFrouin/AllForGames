import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';

/// A board from rows of text, all hidden: `*` is a mine, any other
/// character a safe cell.
MinesweeperState boardOf(List<String> rows) =>
    MinesweeperState.withMines(rows.first.length, rows.length, [
      for (final (y, row) in rows.indexed)
        for (var x = 0; x < row.length; x++)
          if (row[x] == '*') y * row.length + x,
    ]);

/// The cell at column [x], row [y] of [state].
int at(MinesweeperState state, int x, int y) => y * state.columns + x;

/// The safe cells of [state] still hidden or flagged.
List<int> safeHidden(MinesweeperState state) => [
  for (var cell = 0; cell < state.length; cell++)
    if (!state.isMine(cell) && !state.isOpen(cell)) cell,
];

/// A 5 x 5 board where mines wall in the two top left cells: a first tap
/// at the bottom right ([cornerTap]) opens every other safe cell.
final cornerBoard = boardOf(['..*..', '***..', '.....', '.....', '.....']);

/// The bottom right cell of [cornerBoard].
const cornerTap = 24;
