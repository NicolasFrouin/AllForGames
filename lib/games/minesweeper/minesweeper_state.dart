import 'dart:typed_data';

/// The cells of a board of [columns] by [rows], numbered row by row, and the
/// neighbors of each one. Boards of the same size share one grid.
class MinesweeperGrid {
  factory MinesweeperGrid(int columns, int rows) => _grids.putIfAbsent((
    columns,
    rows,
  ), () => MinesweeperGrid._(columns, rows));

  MinesweeperGrid._(this.columns, this.rows)
    : xs = Uint8List(columns * rows),
      ys = Uint8List(columns * rows),
      neighbors = List.filled(columns * rows, const []),
      near = List.filled(columns * rows, const []) {
    for (var cell = 0; cell < length; cell++) {
      final x = cell % columns;
      final y = cell ~/ columns;
      xs[cell] = x;
      ys[cell] = y;
      List<int> within(int distance) => [
        for (var dy = -distance; dy <= distance; dy++)
          for (var dx = -distance; dx <= distance; dx++)
            if ((dx != 0 || dy != 0) &&
                x + dx >= 0 &&
                x + dx < columns &&
                y + dy >= 0 &&
                y + dy < rows)
              (y + dy) * columns + x + dx,
      ];
      neighbors[cell] = within(1);
      near[cell] = within(2);
    }
  }

  static final _grids = <(int, int), MinesweeperGrid>{};

  final int columns;
  final int rows;

  /// Column and row of each cell.
  final Uint8List xs;
  final Uint8List ys;

  /// The (up to) 8 cells around each cell.
  final List<List<int>> neighbors;

  /// The cells at most 2 columns and 2 rows away from each cell: the cells
  /// whose neighbors can be its neighbors too.
  final List<List<int>> near;

  int get length => columns * rows;

  int cellAt(int x, int y) => y * columns + x;

  /// Whether [a] and [b] are different cells that touch (also diagonally).
  bool touches(int a, int b) =>
      a != b && (xs[a] - xs[b]).abs() <= 1 && (ys[a] - ys[b]).abs() <= 1;

  /// The number of mines around each cell, for mines at [isMine].
  Uint8List countsOf(Uint8List isMine) {
    final counts = Uint8List(length);
    for (var cell = 0; cell < length; cell++) {
      if (isMine[cell] == 0) continue;
      for (final n in neighbors[cell]) {
        counts[n]++;
      }
    }
    return counts;
  }
}

/// How the player sees a cell.
enum Cover { hidden, flagged, open }

/// A Minesweeper board: where the mines are and what the player has opened
/// and flagged. Immutable: actions return a new state, or null when they do
/// nothing.
///
/// Before the first tap the board has no mines yet ([hasMines] false): they
/// are placed around the first tap (see `generateMines`).
class MinesweeperState {
  MinesweeperState._(
    this.grid,
    this.mineCount,
    this._isMine,
    this._counts,
    this._covers,
    this.exploded,
  );

  /// A board of [columns] by [rows] before the first tap.
  factory MinesweeperState.empty(int columns, int rows, int mineCount) =>
      MinesweeperState._(
        MinesweeperGrid(columns, rows),
        mineCount,
        null,
        null,
        Uint8List(columns * rows),
        null,
      );

  /// A board with the mines at the cells [mines], all hidden, or with the
  /// [covers] of [encodeCovers].
  factory MinesweeperState.withMines(
    int columns,
    int rows,
    Iterable<int> mines, {
    String? covers,
    int? exploded,
  }) {
    final grid = MinesweeperGrid(columns, rows);
    final isMine = Uint8List(grid.length);
    for (final cell in mines) {
      isMine[cell] = 1;
    }
    return MinesweeperState._(
      grid,
      mines.length,
      isMine,
      grid.countsOf(isMine),
      covers == null ? Uint8List(grid.length) : _decodeCovers(covers),
      exploded,
    );
  }

  final MinesweeperGrid grid;
  final int mineCount;

  /// 1 for a mine. Null before the first tap.
  final Uint8List? _isMine;
  final Uint8List? _counts;

  /// [Cover] indexes.
  final Uint8List _covers;

  /// The mine the player opened, which lost the game.
  final int? exploded;

  late final int openCount = _covers.where((c) => c == _open).length;

  /// Open cells without the mines a lost game opened.
  int get openSafeCount =>
      isLost ? openCount - mines.where(isOpen).length : openCount;
  late final int flagCount = _covers.where((c) => c == _flagged).length;

  static const _hidden = 0;
  static const _flagged = 1;
  static const _open = 2;

  int get columns => grid.columns;
  int get rows => grid.rows;
  int get length => grid.length;
  bool get hasMines => _isMine != null;
  int get safeCount => length - mineCount;

  bool get isLost => exploded != null;
  bool get isWon => !isLost && hasMines && openCount == safeCount;
  bool get isOver => isLost || isWon;

  Cover coverOf(int cell) => Cover.values[_covers[cell]];
  bool isOpen(int cell) => _covers[cell] == _open;
  bool isFlagged(int cell) => _covers[cell] == _flagged;
  bool isMine(int cell) => _isMine?[cell] == 1;

  /// Mines around [cell] (0 before the first tap).
  int countAt(int cell) => _counts?[cell] ?? 0;

  /// The numbers of every cell, for the solver. Null before the first tap.
  Uint8List? get counts => _counts;

  List<int> get mines => [
    for (var cell = 0; cell < length; cell++)
      if (isMine(cell)) cell,
  ];

  /// Opens [cell]. A cell with no mine around opens its neighbors too, and
  /// so on (flags stop it). Opening a mine loses the game.
  MinesweeperState? open(int cell) {
    if (isOver || !hasMines || _covers[cell] != _hidden) return null;
    return _opened([cell]);
  }

  /// Flags a hidden cell, or takes the flag back.
  MinesweeperState? toggleFlag(int cell) {
    if (isOver || isOpen(cell)) return null;
    final covers = Uint8List.fromList(_covers);
    covers[cell] = isFlagged(cell) ? _hidden : _flagged;
    return _with(covers);
  }

  /// The hidden cells that a chord on [cell] opens: on an open number with
  /// as many flags around, its other hidden neighbors. Empty when the chord
  /// does nothing.
  List<int> chordCells(int cell) {
    if (isOver || !isOpen(cell) || countAt(cell) == 0) return const [];
    final around = grid.neighbors[cell];
    final flags = around.where(isFlagged).length;
    if (flags != countAt(cell)) return const [];
    return [
      for (final n in around)
        if (_covers[n] == _hidden) n,
    ];
  }

  /// Opens the [chordCells] of [cell]. A wrong flag around it can open a
  /// mine.
  MinesweeperState? chord(int cell) {
    final cells = chordCells(cell);
    return cells.isEmpty ? null : _opened(cells);
  }

  /// A won board shows every mine flagged.
  MinesweeperState flagMines() {
    final covers = Uint8List.fromList(_covers);
    for (final cell in mines) {
      covers[cell] = _flagged;
    }
    return _with(covers);
  }

  /// The covers as text, for saves: `-` hidden, `f` flagged, `o` open.
  String encodeCovers() => String.fromCharCodes([
    for (final cover in _covers) _coverChars.codeUnitAt(cover),
  ]);

  static const _coverChars = '-fo';

  static Uint8List _decodeCovers(String text) {
    final covers = Uint8List(text.length);
    for (var i = 0; i < text.length; i++) {
      final cover = _coverChars.indexOf(text[i]);
      if (cover < 0) throw FormatException('Bad Minesweeper cover', text, i);
      covers[i] = cover;
    }
    return covers;
  }

  /// The "3BV" of the board: the fewest clicks that open every safe cell
  /// (one per opening of empty cells, one per number outside them).
  late final int boardValue = _boardValue(solvedOnly: false);

  /// The part of [boardValue] already done: openings fully open, and open
  /// numbers outside them.
  int get boardValueSolved => _boardValue(solvedOnly: true);

  int _boardValue({required bool solvedOnly}) {
    if (!hasMines) return 0;
    final seen = Uint8List(length);
    var value = 0;
    for (var cell = 0; cell < length; cell++) {
      if (seen[cell] == 1 || isMine(cell) || countAt(cell) != 0) continue;
      // An opening: the empty cells joined to this one, and their borders.
      var done = true;
      final stack = [cell];
      seen[cell] = 1;
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (!isOpen(c)) done = false;
        if (countAt(c) != 0) continue;
        for (final n in grid.neighbors[c]) {
          if (seen[n] == 1) continue;
          seen[n] = 1;
          stack.add(n);
        }
      }
      if (done || !solvedOnly) value++;
    }
    for (var cell = 0; cell < length; cell++) {
      if (seen[cell] == 1 || isMine(cell)) continue;
      if (isOpen(cell) || !solvedOnly) value++;
    }
    return value;
  }

  MinesweeperState _opened(List<int> cells) {
    final covers = Uint8List.fromList(_covers);
    int? exploded;
    final stack = [...cells];
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      if (covers[cell] != _hidden) continue;
      covers[cell] = _open;
      if (isMine(cell)) {
        exploded ??= cell;
      } else if (countAt(cell) == 0) {
        stack.addAll(grid.neighbors[cell]);
      }
    }
    return MinesweeperState._(
      grid,
      mineCount,
      _isMine,
      _counts,
      covers,
      exploded,
    );
  }

  MinesweeperState _with(Uint8List covers) =>
      MinesweeperState._(grid, mineCount, _isMine, _counts, covers, exploded);
}
