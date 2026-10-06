// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

// Times the Minesweeper generator per level, and checks that the solver
// clears every board it makes from the first tap.
//
// Usage: dart run tool/minesweeper_generation.dart [boards per level]
// In JavaScript, as on the web (node gets no arguments: 200 boards):
//   dart compile js -O2 -o /tmp/ms.js tool/minesweeper_generation.dart
//   node /tmp/ms.js
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_generator.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_solver.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';

void main(List<String> args) {
  final boards = args.isEmpty ? 200 : int.parse(args.first);
  for (final difficulty in MinesweeperDifficulty.values) {
    final (columns, rows) = difficulty.size();
    // Warm-up: the first runs compile the code.
    for (var seed = 0; seed < 20; seed++) {
      _deal(difficulty, columns, rows, -1 - seed);
    }
    final times = <double>[];
    final deals = <(MinesweeperDeal, int)>[];
    // One clock for the batch too: JavaScript clocks count whole ms.
    final batch = Stopwatch()..start();
    for (var seed = 1; seed <= boards; seed++) {
      final watch = Stopwatch()..start();
      deals.add(_deal(difficulty, columns, rows, seed));
      times.add(watch.elapsedMicroseconds / 1000);
    }
    final mean = batch.elapsedMicroseconds / 1000 / boards;
    var passes = 0;
    var fixes = 0;
    var restarts = 0;
    var unsolved = 0;
    for (final (deal, firstTap) in deals) {
      passes += deal.passes;
      fixes += deal.fixes;
      restarts += deal.restarts;
      final state = MinesweeperState.withMines(columns, rows, deal.mines);
      final solver = MinesweeperSolver.of(state.open(firstTap)!);
      if (!solver.solve()) unsolved++;
    }
    times.sort();
    String ms(double value) => value.toStringAsFixed(2);
    print(
      '${difficulty.name.padRight(6)} ${columns}x$rows/${difficulty.mines}: '
      'mean ${ms(mean)} ms, median ${ms(times[times.length ~/ 2])}, '
      'p95 ${ms(times[times.length * 95 ~/ 100])}, max ${ms(times.last)}; '
      'per board ${(passes / boards).toStringAsFixed(2)} passes, '
      '${(fixes / boards).toStringAsFixed(1)} fixes, '
      '${(restarts / boards).toStringAsFixed(2)} restarts; '
      'unsolved $unsolved',
    );
  }
}

/// A board of [seed], first tapped on a cell picked from the seed.
(MinesweeperDeal, int) _deal(
  MinesweeperDifficulty difficulty,
  int columns,
  int rows,
  int seed,
) {
  final firstTap = (seed * 7919).abs() % (columns * rows);
  final deal = generateMines(
    columns: columns,
    rows: rows,
    mineCount: difficulty.mines,
    seed: seed,
    firstTap: firstTap,
  );
  return (deal, firstTap);
}
