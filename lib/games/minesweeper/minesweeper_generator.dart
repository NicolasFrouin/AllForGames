import 'dart:typed_data';

import '../../cards/deal_random.dart';
import 'minesweeper_solver.dart';
import 'minesweeper_state.dart';

/// How a board was made, for the tool and the tests.
typedef MinesweeperDeal = ({
  List<int> mines,

  /// Solver runs over the whole board: the last one needed no fix.
  int passes,

  /// Stuck places fixed by moving mines, over all the passes.
  int fixes,

  /// Mine layouts given up, and started again.
  int restarts,
});

/// Where the mines of a board of [columns] by [rows] go once the player has
/// opened [firstTap], for [seed]: the same cells on every platform.
///
/// The first tap is safe and opens an area: no mine touches it. The board
/// is then cleared by logic alone ([MinesweeperSolver]) from that opening:
/// the generator runs the solver, and where it gets stuck, moves a few mines
/// so that a number around the stuck place proves its hidden cells (all
/// safe, or all mines), taking the mines from (or to) cells far from what is
/// open. Moving mines can change numbers that earlier steps used, so the
/// solver runs again from the first tap until a run needs no fix.
MinesweeperDeal generateMines({
  required int columns,
  required int rows,
  required int mineCount,
  required int seed,
  required int firstTap,
}) {
  final grid = MinesweeperGrid(columns, rows);
  // The tap position picks a different layout for the same seed.
  final random = DealRandom(seed + 7919 * (firstTap + 1));
  final opening = {firstTap, ...grid.neighbors[firstTap]};
  final candidates = [
    for (var cell = 0; cell < grid.length; cell++)
      if (!opening.contains(cell)) cell,
  ];
  assert(mineCount <= candidates.length, 'Too many mines for the board');
  var fixes = 0;
  var passes = 0;
  late Uint8List isMine;
  for (var restart = 0; restart < _maxRestarts; restart++) {
    // A partial Fisher-Yates shuffle: the first mineCount candidates.
    for (var i = 0; i < mineCount; i++) {
      final j = i + random.nextInt(candidates.length - i);
      final cell = candidates[j];
      candidates[j] = candidates[i];
      candidates[i] = cell;
    }
    isMine = Uint8List(grid.length);
    for (var i = 0; i < mineCount; i++) {
      isMine[candidates[i]] = 1;
    }
    final counts = grid.countsOf(isMine);
    for (var pass = 0; pass < _maxPasses; pass++) {
      passes++;
      final solver = MinesweeperSolver(grid, counts, mineCount)..open(firstTap);
      var passFixes = 0;
      while (!solver.solve() &&
          passFixes < _maxFixes &&
          _fix(solver, grid, isMine, counts, random)) {
        passFixes++;
      }
      fixes += passFixes;
      if (!solver.isSolved) break;
      if (passFixes == 0) {
        return (
          mines: _minesOf(isMine),
          passes: passes,
          fixes: fixes,
          restarts: restart,
        );
      }
    }
  }
  // Not reached in the tests (thousands of boards): the last layout, which
  // may need a guess.
  return (
    mines: _minesOf(isMine),
    passes: passes,
    fixes: fixes,
    restarts: _maxRestarts,
  );
}

const _maxRestarts = 20;
const _maxPasses = 12;
const _maxFixes = 400;

List<int> _minesOf(Uint8List isMine) => [
  for (var cell = 0; cell < isMine.length; cell++)
    if (isMine[cell] == 1) cell,
];

/// Picks an open number next to hidden cells and makes its hidden neighbors
/// all safe or all mines, with as few mine moves as possible: the solver
/// can go on from there. Returns false when no mine can move.
bool _fix(
  MinesweeperSolver solver,
  MinesweeperGrid grid,
  Uint8List isMine,
  Uint8List counts,
  DealRandom random,
) {
  // Hidden cells that no open cell touches: changing them changes no number
  // the solver has seen. Near the end there may be too few: then any hidden
  // cell will do.
  final far = <int>[];
  final hidden = <int>[];
  for (var cell = 0; cell < grid.length; cell++) {
    if (!solver.isUnknown(cell)) continue;
    hidden.add(cell);
    if (!grid.neighbors[cell].any(solver.isKnownSafe)) far.add(cell);
  }

  for (final pool in [far, hidden]) {
    final poolMines = pool.where((cell) => isMine[cell] == 1).length;
    final poolSafe = pool.length - poolMines;
    // The cheapest fixes: (number, fill with mines or clear).
    final best = <(int, bool)>[];
    var bestCost = 1 << 30;
    for (var cell = 0; cell < grid.length; cell++) {
      if (!solver.isKnownSafe(cell) || solver.unknownAround(cell) == 0) {
        continue;
      }
      final around = [
        for (final n in grid.neighbors[cell])
          if (solver.isUnknown(n)) n,
      ];
      // The cells to fix are not in the far pool, but in the other one.
      final inPool = identical(pool, far) ? const <int>[] : around;
      final mines = around.where((n) => isMine[n] == 1).length;
      final poolMinesLeft =
          poolMines - inPool.where((n) => isMine[n] == 1).length;
      final poolSafeLeft =
          poolSafe - inPool.where((n) => isMine[n] == 0).length;
      for (final fill in [false, true]) {
        final cost = fill ? around.length - mines : mines;
        final available = fill ? poolMinesLeft : poolSafeLeft;
        if (cost == 0 || cost > available || cost > bestCost) continue;
        if (cost < bestCost) {
          bestCost = cost;
          best.clear();
        }
        best.add((cell, fill));
      }
    }
    if (best.isEmpty) continue;

    final (cell, fill) = best[random.nextInt(best.length)];
    final around = [
      for (final n in grid.neighbors[cell])
        if (solver.isUnknown(n)) n,
    ];
    final others = [
      for (final n in pool)
        if (!around.contains(n) && isMine[n] == (fill ? 1 : 0)) n,
    ];
    for (final n in around) {
      if (isMine[n] == (fill ? 1 : 0)) continue;
      final other = others.removeAt(random.nextInt(others.length));
      _flip(n, grid, isMine, counts, solver);
      _flip(other, grid, isMine, counts, solver);
    }
    return true;
  }
  return false;
}

void _flip(
  int cell,
  MinesweeperGrid grid,
  Uint8List isMine,
  Uint8List counts,
  MinesweeperSolver solver,
) {
  isMine[cell] ^= 1;
  for (final n in grid.neighbors[cell]) {
    if (isMine[cell] == 1) {
      counts[n]++;
    } else {
      counts[n]--;
    }
  }
  solver.numbersChanged(cell);
}
