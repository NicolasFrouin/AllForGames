import 'dart:math';
import 'dart:typed_data';

import 'minesweeper_state.dart';

/// Finds what logic alone proves on a Minesweeper board, as a player would:
/// from the numbers of the open cells only.
///
/// Rules, from the cheapest:
/// - one number: when its mines are all known, its other hidden neighbors
///   are safe; when it needs all of them, they are mines;
/// - two numbers that share hidden cells (the 1-2 patterns and subsets):
///   the mines the shared cells can hold bound those of the others;
/// - near the end, every way to place the mines left in the hidden cells
///   (the mine count then matters).
///
/// The generator opens what the solver proves safe until the board is clear;
/// the hint stops at the first safe cell. Work is incremental: a rule only
/// looks again at numbers whose hidden neighbors changed.
class MinesweeperSolver {
  /// A solver that knows nothing yet. It reads the number of a cell in
  /// [counts] only when it opens it.
  MinesweeperSolver(this.grid, this.counts, this.mineCount)
    : _known = Uint8List(grid.length),
      _unknownAround = Uint8List.fromList([
        for (final around in grid.neighbors) around.length,
      ]),
      _minesAround = Uint8List(grid.length),
      _queued = Uint8List(grid.length),
      _dirty = Uint8List(grid.length),
      _unknownCount = grid.length;

  /// A solver that knows what the player sees on [state]: its open cells.
  /// Flags are ignored (they can be wrong).
  factory MinesweeperSolver.of(MinesweeperState state) {
    final solver = MinesweeperSolver(
      state.grid,
      state.counts!,
      state.mineCount,
    );
    for (var cell = 0; cell < state.length; cell++) {
      if (state.isOpen(cell) && !state.isMine(cell)) solver._markSafe(cell);
    }
    return solver;
  }

  /// The search near the end looks at this many hidden cells at most.
  static const endgameCells = 16;

  /// Bound on the steps of one search near the end.
  static const _endgameBudget = 200000;

  static const _unknown = 0;
  static const _safe = 1;
  static const _mine = 2;

  final MinesweeperGrid grid;

  /// Mines around each cell. The generator changes some of them while it
  /// solves (see [numbersChanged]).
  final Uint8List counts;
  final int mineCount;

  final Uint8List _known;
  final Uint8List _unknownAround;
  final Uint8List _minesAround;
  int _unknownCount;
  int _minesKnown = 0;
  int _safeKnown = 0;

  /// Open numbers for the one-number rule.
  final _todo = <int>[];
  final Uint8List _queued;

  /// Open numbers whose pairs may prove something new.
  final _dirtyList = <int>[];
  final Uint8List _dirty;

  /// While looking for a hint: the first safe cell found.
  bool _stopAtSafe = false;
  int? _found;

  /// Every safe cell is known.
  bool get isSolved => _safeKnown == grid.length - mineCount;

  bool isUnknown(int cell) => _known[cell] == _unknown;
  bool isKnownSafe(int cell) => _known[cell] == _safe;

  /// Hidden neighbors of [cell], for an open cell.
  int unknownAround(int cell) => _unknownAround[cell];

  /// Opens [cell] as the player would: a cell with no mine around opens its
  /// neighbors too.
  void open(int cell) {
    if (_known[cell] == _unknown) _openSafe(cell);
  }

  /// Applies the rules until the board is clear or they prove nothing more.
  /// Returns [isSolved].
  bool solve() {
    _stopAtSafe = false;
    _run();
    return isSolved;
  }

  /// A hidden cell that the rules prove safe, or null when they prove none.
  int? findSafe() {
    _stopAtSafe = true;
    _found = null;
    _run();
    return _found;
  }

  /// The numbers around [cell] changed (the generator moved a mine): the
  /// rules look at them again.
  void numbersChanged(int cell) {
    for (final n in grid.neighbors[cell]) {
      if (_known[n] == _safe) _touch(n);
    }
  }

  void _run() {
    while (_found == null && !isSolved) {
      _singles();
      if (_found != null || _todo.isNotEmpty) continue;
      if (_pairs()) continue;
      if (!_endgame()) return;
    }
  }

  void _touch(int cell) {
    if (_queued[cell] == 0) {
      _queued[cell] = 1;
      _todo.add(cell);
    }
    if (_dirty[cell] == 0) {
      _dirty[cell] = 1;
      _dirtyList.add(cell);
    }
  }

  int _need(int cell) => counts[cell] - _minesAround[cell];

  void _singles() {
    while (_todo.isNotEmpty && _found == null) {
      final cell = _todo.removeLast();
      _queued[cell] = 0;
      final unknown = _unknownAround[cell];
      if (unknown == 0) continue;
      final need = _need(cell);
      if (need == 0) {
        for (final n in grid.neighbors[cell]) {
          if (_known[n] == _unknown) _proveSafe(n);
          if (_found != null) return;
        }
      } else if (need == unknown) {
        for (final n in grid.neighbors[cell]) {
          if (_known[n] == _unknown) _markMine(n);
        }
      }
    }
  }

  /// Looks at the pairs of a changed number and the numbers near it. Returns
  /// whether it proved something.
  bool _pairs() {
    while (_dirtyList.isNotEmpty) {
      final a = _dirtyList.removeLast();
      _dirty[a] = 0;
      if (_known[a] != _safe || _unknownAround[a] == 0) continue;
      for (final b in grid.near[a]) {
        if (_known[b] != _safe || _unknownAround[b] == 0) continue;
        if (_pair(a, b)) {
          // Its other pairs are still to see.
          if (_dirty[a] == 0) {
            _dirty[a] = 1;
            _dirtyList.add(a);
          }
          return true;
        }
      }
    }
    return false;
  }

  /// The hidden neighbors of [a] and [b]: some around both, the others only
  /// around one. The mines in the shared cells are between [lo] and [hi];
  /// when that leaves the cells around one of them all safe or all mines,
  /// they are.
  bool _pair(int a, int b) {
    var shared = 0;
    for (final n in grid.neighbors[a]) {
      if (_known[n] == _unknown && grid.touches(n, b)) shared++;
    }
    if (shared == 0) return false;
    final needA = _need(a);
    final needB = _need(b);
    final onlyA = _unknownAround[a] - shared;
    final onlyB = _unknownAround[b] - shared;
    final lo = max(0, max(needA - onlyA, needB - onlyB));
    final hi = min(shared, min(needA, needB));
    if (lo > hi) return false;
    // The cells only around a hold from needA - hi to needA - lo mines.
    final aSafe = onlyA > 0 && needA == lo;
    final aMines = onlyA > 0 && needA - hi == onlyA;
    final bSafe = onlyB > 0 && needB == lo;
    final bMines = onlyB > 0 && needB - hi == onlyB;
    if (!aSafe && !aMines && !bSafe && !bMines) return false;
    // Both lists before any change: a change moves cells out of them.
    final aCells = _onlyAround(a, b);
    final bCells = _onlyAround(b, a);
    if (aSafe || aMines) _settle(aCells, safe: aSafe);
    if (bSafe || bMines) _settle(bCells, safe: bSafe);
    return true;
  }

  /// The hidden neighbors of [a] that do not touch [b].
  List<int> _onlyAround(int a, int b) => [
    for (final n in grid.neighbors[a])
      if (_known[n] == _unknown && !grid.touches(n, b)) n,
  ];

  void _settle(List<int> cells, {required bool safe}) {
    for (final cell in cells) {
      if (_found != null) return;
      if (_known[cell] != _unknown) continue;
      if (safe) {
        _proveSafe(cell);
      } else {
        _markMine(cell);
      }
    }
  }

  /// With the mines left: all safe, all mines, or, with few hidden cells,
  /// what holds in every way to place them.
  bool _endgame() {
    if (_unknownCount == 0) return false;
    final left = mineCount - _minesKnown;
    if (left == 0 || left == _unknownCount) {
      for (var cell = 0; cell < grid.length; cell++) {
        if (_known[cell] != _unknown) continue;
        if (left == 0) {
          _proveSafe(cell);
          if (_found != null) return true;
        } else {
          _markMine(cell);
        }
      }
      return true;
    }
    if (_unknownCount > endgameCells) return false;
    return _search(left);
  }

  /// Tries every way to place [left] mines in the hidden cells that agrees
  /// with the numbers.
  bool _search(int left) {
    final cells = [
      for (var cell = 0; cell < grid.length; cell++)
        if (_known[cell] == _unknown) cell,
    ];
    // Per open number: mines still to place around it, and hidden cells
    // still free around it.
    final need = Int32List(grid.length);
    final free = Int32List(grid.length);
    for (final cell in cells) {
      for (final n in grid.neighbors[cell]) {
        if (_known[n] != _safe) continue;
        need[n] = _need(n);
        free[n] = _unknownAround[n];
      }
    }
    final mineHits = Int32List(cells.length);
    final isMine = Uint8List(cells.length);
    var solutions = 0;
    var steps = 0;

    // Places cell i as a mine or not; false when the search is too long.
    bool place(int i, int placed) {
      if (++steps > _endgameBudget) return false;
      if (i == cells.length) {
        if (placed != left) return true;
        solutions++;
        for (var j = 0; j < cells.length; j++) {
          mineHits[j] += isMine[j];
        }
        return true;
      }
      final around = grid.neighbors[cells[i]];
      for (var mine = 0; mine <= 1; mine++) {
        if (placed + mine > left) break;
        if (placed + mine + cells.length - i - 1 < left) continue;
        var fits = true;
        for (final n in around) {
          if (_known[n] != _safe) continue;
          need[n] -= mine;
          free[n]--;
          if (need[n] < 0 || need[n] > free[n]) fits = false;
        }
        isMine[i] = mine;
        final ok = !fits || place(i + 1, placed + mine);
        for (final n in around) {
          if (_known[n] != _safe) continue;
          need[n] += mine;
          free[n]++;
        }
        if (!ok) return false;
      }
      isMine[i] = 0;
      return true;
    }

    if (!place(0, 0) || solutions == 0) return false;
    var proved = false;
    for (var j = 0; j < cells.length; j++) {
      if (mineHits[j] == 0) {
        _proveSafe(cells[j]);
        proved = true;
        if (_found != null) return true;
      } else if (mineHits[j] == solutions) {
        _markMine(cells[j]);
        proved = true;
      }
    }
    return proved;
  }

  void _proveSafe(int cell) {
    if (_stopAtSafe) {
      _found = cell;
    } else {
      _openSafe(cell);
    }
  }

  /// Opens [cell] and, while they have no mine around, its neighbors.
  void _openSafe(int cell) {
    final stack = [cell];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      if (_known[c] != _unknown) continue;
      _markSafe(c);
      if (counts[c] == 0) {
        for (final n in grid.neighbors[c]) {
          if (_known[n] == _unknown) stack.add(n);
        }
      }
    }
  }

  void _markSafe(int cell) {
    _known[cell] = _safe;
    _unknownCount--;
    _safeKnown++;
    _touch(cell);
    for (final n in grid.neighbors[cell]) {
      _unknownAround[n]--;
      if (_known[n] == _safe) _touch(n);
    }
  }

  void _markMine(int cell) {
    _known[cell] = _mine;
    _unknownCount--;
    _minesKnown++;
    for (final n in grid.neighbors[cell]) {
      _unknownAround[n]--;
      _minesAround[n]++;
      if (_known[n] == _safe) _touch(n);
    }
  }
}
