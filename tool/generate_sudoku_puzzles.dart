// Generates lib/games/sudoku/sudoku_puzzles.dart: 50 puzzles per level, each
// with one solution, graded by gradeSudoku (sudoku_grader.dart).
//
//   dart run tool/generate_sudoku_puzzles.dart              # writes the file
//   dart run tool/generate_sudoku_puzzles.dart --stats 1000 # grades 1000
//       random minimal puzzles and prints the distribution (no file)
//
// Levels 1 to 3 take givens away from a full grid while their singles still
// solve it; levels 4 to 12 sort random minimal puzzles by grade. Givens go in
// pairs symmetric about the center. Each puzzle comes from its own seed and
// full grid; seeds run in parallel isolates, then are taken in order, so the
// output does not depend on the number of cores.

// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:all_for_games/games/sudoku/sudoku_grader.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/games/sudoku/sudoku_solver.dart';

const puzzlesPerLevel = 50;
const _chunkSize = 50;

/// Seeds of the levels made from singles: `level.number * _singlesSeeds + n`.
const _singlesSeeds = 1000000;

typedef Puzzle = ({int seed, List<int> grid, SudokuGrade grade});

Future<void> main(List<String> args) async {
  final stats = args.indexOf('--stats');
  if (stats >= 0) {
    await _printStats(int.parse(args[stats + 1]));
    return;
  }

  final stopwatch = Stopwatch()..start();
  final puzzles = <SudokuLevel, List<Puzzle>>{};
  for (final level in sudokuSinglesGivens.keys) {
    final lap = stopwatch.elapsedMilliseconds;
    final (:found, :tried) = await _collectSinglesLevel(level);
    puzzles[level] = found;
    _printLevel(level, found, '$tried seeds', stopwatch, lap);
  }
  puzzles.addAll(await _collectGraded(stopwatch));
  for (final level in SudokuLevel.values) {
    for (final puzzle in puzzles[level]!) {
      if (!hasOneSolution(puzzle.grid) || puzzle.grade.level != level) {
        throw StateError('Seed ${puzzle.seed}: not a ${level.name} puzzle');
      }
    }
  }
  final file = File.fromUri(
    Platform.script.resolve('../lib/games/sudoku/sudoku_puzzles.dart'),
  );
  file.writeAsStringSync(_render(puzzles));
  final format = Process.runSync(Platform.resolvedExecutable, [
    'format',
    file.path,
  ]);
  if (format.exitCode != 0) stderr.write(format.stderr);
  print('Wrote ${file.path} in ${_seconds(stopwatch.elapsedMilliseconds)}.');
}

/// The first [puzzlesPerLevel] seeds that make a puzzle of [level].
Future<({List<Puzzle> found, int tried})> _collectSinglesLevel(
  SudokuLevel level,
) async {
  final found = <Puzzle>[];
  var next = level.number * _singlesSeeds;
  while (found.length < puzzlesPerLevel) {
    final batch = await _run(next, (seed) => _singlesPuzzle(level, seed));
    next += batch.length;
    found.addAll(batch.nonNulls.take(puzzlesPerLevel - found.length));
  }
  return (
    found: found,
    tried: found.last.seed - level.number * _singlesSeeds + 1,
  );
}

/// Grades minimal puzzles from seed 1 upward until levels 4 to 12 have
/// [puzzlesPerLevel] puzzles each.
Future<Map<SudokuLevel, List<Puzzle>>> _collectGraded(
  Stopwatch stopwatch,
) async {
  final levels = SudokuLevel.values.skip(sudokuSinglesGivens.length);
  final buckets = {for (final level in levels) level: <Puzzle>[]};
  final filledAt = <SudokuLevel, int>{};
  final start = stopwatch.elapsedMilliseconds;
  var next = 1;
  while (filledAt.length < buckets.length) {
    final batch = await _run(next, _minimalPuzzle);
    next += batch.length;
    for (final puzzle in batch) {
      final bucket = buckets[puzzle.grade.level];
      if (bucket == null || bucket.length >= puzzlesPerLevel) continue;
      bucket.add(puzzle);
      if (bucket.length == puzzlesPerLevel) {
        filledAt[puzzle.grade.level!] = stopwatch.elapsedMilliseconds;
      }
    }
    stdout.write(
      '\rminimal puzzles 1..${next - 1}: '
      '${[for (final b in buckets.values) b.length].join(' ')} '
      '(${_seconds(stopwatch.elapsedMilliseconds)})   ',
    );
  }
  stdout.writeln();
  for (final MapEntry(key: level, value: found) in buckets.entries) {
    _printLevel(
      level,
      found,
      'full at seed ${found.last.seed}',
      stopwatch,
      start,
      end: filledAt[level],
    );
  }
  return buckets;
}

/// Runs [make] on the seeds from [from], a chunk per core.
Future<List<T>> _run<T>(int from, T Function(int seed) make) async {
  final workers = Platform.numberOfProcessors;
  final chunks = await Future.wait([
    for (var w = 0; w < workers; w++)
      Isolate.run(() {
        final first = from + w * _chunkSize;
        return [for (var s = first; s < first + _chunkSize; s++) make(s)];
      }),
  ]);
  return [for (final chunk in chunks) ...chunk];
}

/// A random full grid: the three boxes of the diagonal shuffled (they never
/// clash), then the first completion of the solver.
List<int> _fullGrid(Random random) {
  final grid = List.filled(SudokuGrid.cellCount, 0);
  for (final box in [0, 4, 8]) {
    final digits = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
    final cells = SudokuGrid.units[18 + box];
    for (var i = 0; i < 9; i++) {
      grid[cells[i]] = digits[i];
    }
  }
  return solveSudoku(grid).single;
}

/// The cell and its mirror through the center, in a random order.
List<List<int>> _symmetricPairs(Random random) => [
  for (var cell = 0; cell <= SudokuGrid.cellCount ~/ 2; cell++)
    {cell, SudokuGrid.cellCount - 1 - cell}.toList(),
]..shuffle(random);

/// Takes pairs of givens away while the puzzle keeps one solution.
Puzzle _minimalPuzzle(int seed) {
  final random = Random(seed);
  final solution = _fullGrid(random);
  final grid = [...solution];
  for (final pair in _symmetricPairs(random)) {
    for (final cell in pair) {
      grid[cell] = 0;
    }
    if (!hasOneSolution(grid)) {
      for (final cell in pair) {
        grid[cell] = solution[cell];
      }
    }
  }
  return (seed: seed, grid: grid, grade: gradeSudoku(grid));
}

/// Takes pairs of givens away down to a random count in the range of
/// [level] while its singles solve the puzzle; null when the count is not
/// reached.
Puzzle? _singlesPuzzle(SudokuLevel level, int seed) {
  final random = Random(seed);
  final range = sudokuSinglesGivens[level]!;
  final target = range.min + random.nextInt(range.max - range.min + 1);
  final upTo = level == SudokuLevel.level3
      ? SudokuTechnique.hiddenSingleLine
      : SudokuTechnique.hiddenSingleBox;
  final solution = _fullGrid(random);
  final grid = [...solution];
  var givens = SudokuGrid.cellCount;
  for (final pair in _symmetricPairs(random)) {
    if (givens <= target) break;
    if (givens - pair.length < range.min) continue;
    for (final cell in pair) {
      grid[cell] = 0;
    }
    if (gradeSudoku(grid, upTo: upTo).solved) {
      givens -= pair.length;
    } else {
      for (final cell in pair) {
        grid[cell] = solution[cell];
      }
    }
  }
  final grade = gradeSudoku(grid);
  if (grade.level != level) return null;
  // Level 3 is the level of hidden singles in rows and columns.
  if (upTo == SudokuTechnique.hiddenSingleLine &&
      !grade.uses.containsKey(upTo)) {
    return null;
  }
  return (seed: seed, grid: grid, grade: grade);
}

String _render(Map<SudokuLevel, List<Puzzle>> puzzles) {
  final out = StringBuffer()
    ..writeln('// Generated by tool/generate_sudoku_puzzles.dart. Do not edit.')
    ..writeln('//')
    ..writeln(
      '// $puzzlesPerLevel puzzles per level, each with one solution and its own full',
    )
    ..writeln(
      '// grid. Their level comes from gradeSudoku (sudoku_grader.dart): the hardest',
    )
    ..writeln(
      '// technique a solver needs when it always takes the simplest step, in rounds',
    )
    ..writeln('// (levelOf). Turned or relabeled, a puzzle keeps its level.')
    ..writeln(
      '// - level 1: full houses and hidden singles in boxes, 42 to 46 givens;',
    )
    ..writeln('// - level 2: the same, 34 to 38 givens;')
    ..writeln(
      '// - level 3: hidden singles in rows and columns too, 28 to 32 givens;',
    )
    ..writeln('// - level 4: naked singles;')
    ..writeln('// - level 5: locked candidates, in 1 or 2 rounds;')
    ..writeln(
      '// - level 6: locked candidates in 3 rounds or more, naked or hidden pairs;',
    )
    ..writeln('// - level 7: naked or hidden triples;')
    ..writeln('// - level 8: X-Wing;')
    ..writeln('// - level 9: XY-Wing or Swordfish;')
    ..writeln(
      '// - level 10: XYZ-Wing, quads, Jellyfish, Skyscraper, 2-String Kite, W-Wing;',
    )
    ..writeln('// - level 11: X-chains or XY-chains;')
    ..writeln('// - level 12: none of these techniques solves it.')
    ..writeln(
      '// Levels 1 to 3 take pairs of givens away from a full grid while their',
    )
    ..writeln(
      '// singles solve it; levels 4 to 12 are random minimal puzzles. Givens are',
    )
    ..writeln('// symmetric about the center.')
    ..writeln()
    ..writeln(
      '/// Puzzles with one solution each, by level (`SudokuLevel.index`):',
    )
    ..writeln('/// 81 digits row by row, `0` for an empty cell.')
    ..writeln('const sudokuPuzzles = <List<String>>[');
  for (final level in SudokuLevel.values) {
    out.writeln('  [');
    for (final puzzle in puzzles[level]!) {
      out.writeln("    '${SudokuGrid.encode(puzzle.grid)}',");
    }
    out.writeln('  ],');
  }
  out.writeln('];');
  return out.toString();
}

void _printLevel(
  SudokuLevel level,
  List<Puzzle> found,
  String note,
  Stopwatch stopwatch,
  int start, {
  int? end,
}) {
  final givens = [for (final p in found) p.grade.givens];
  final average = givens.reduce((a, b) => a + b) / givens.length;
  print(
    '  ${level.name.padRight(7)} ${found.length} puzzles, givens avg '
    '${average.toStringAsFixed(1)} (${givens.reduce(min)} to '
    '${givens.reduce(max)}), $note, '
    '${_seconds((end ?? stopwatch.elapsedMilliseconds) - start)}',
  );
}

/// Prints the grades of the minimal puzzles of seeds 1..[count].
Future<void> _printStats(int count) async {
  final stopwatch = Stopwatch()..start();
  final puzzles = <Puzzle>[];
  for (var next = 1; next <= count; next = puzzles.length + 1) {
    final batch = await _run(next, _minimalPuzzle);
    puzzles.addAll(batch.where((p) => p.seed <= count));
  }
  String share(int part) =>
      '${part.toString().padLeft(5)} ${(100 * part / count).toStringAsFixed(1).padLeft(5)}%';
  final givens = [for (final p in puzzles) p.grade.givens];
  print(
    '$count minimal puzzles, givens avg '
    '${(givens.reduce((a, b) => a + b) / count).toStringAsFixed(1)} '
    '(${givens.reduce(min)} to ${givens.reduce(max)})',
  );
  print('By level:');
  for (final level in [...SudokuLevel.values, null]) {
    final n = puzzles.where((p) => p.grade.level == level).length;
    print('  ${(level?.name ?? 'none').padRight(8)} ${share(n)}');
  }
  print('By hardest technique (solved):');
  for (final technique in SudokuTechnique.values) {
    final n = puzzles
        .where((p) => p.grade.solved && p.grade.hardest == technique)
        .length;
    print('  ${technique.name.padRight(17)} ${share(n)}');
  }
  print('Puzzles using each technique:');
  for (final technique in SudokuTechnique.values) {
    final n = puzzles.where((p) => p.grade.uses.containsKey(technique)).length;
    print('  ${technique.name.padRight(17)} ${share(n)}');
  }
  print('  ${_seconds(stopwatch.elapsedMilliseconds)}');
}

String _seconds(int milliseconds) =>
    '${(milliseconds / 1000).toStringAsFixed(1)} s';
