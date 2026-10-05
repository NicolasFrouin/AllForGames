// Generates lib/games/klondike/klondike_deals.dart: deal seeds that the
// solver proved winnable, by draw count and difficulty.
//
//   dart run tool/generate_klondike_deals.dart              # writes the file
//   dart run tool/generate_klondike_deals.dart --stats 2000 # grades seeds
//       1..2000 for each draw count and prints the distribution (no file)
//
// Seeds are graded in parallel isolates, then taken in seed order, so the
// output does not depend on the number of cores.

// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';

import 'package:all_for_games/games/klondike/deal_random.dart';
import 'package:all_for_games/games/klondike/klondike_solver.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';

const seedsPerBucket = 400;
const drawCounts = [1, 3];
const _chunkSize = 20;

typedef SeedReport = ({
  int seed,
  bool greedyWins,

  /// Null when the solver was skipped (only easy deals were still needed).
  SolveStatus? status,
  int nodes,
  int actions,
  int recycles,

  /// The solution replayed to a win on [KlondikeState].
  bool verified,
  KlondikeDifficulty? difficulty,
});

Future<void> main(List<String> args) async {
  final stats = args.indexOf('--stats');
  if (stats >= 0) {
    await _printStats(int.parse(args[stats + 1]));
    return;
  }

  final stopwatch = Stopwatch()..start();
  final deals = <int, Map<KlondikeDifficulty, List<int>>>{};
  for (final drawCount in drawCounts) {
    deals[drawCount] = await _collect(drawCount, stopwatch);
  }
  final file = File.fromUri(
    Platform.script.resolve('../lib/games/klondike/klondike_deals.dart'),
  );
  file.writeAsStringSync(_render(deals));
  final format = Process.runSync(Platform.resolvedExecutable, [
    'format',
    file.path,
  ]);
  if (format.exitCode != 0) stderr.write(format.stderr);
  print('Wrote ${file.path} in ${_seconds(stopwatch)}.');
}

/// Grades seeds from 1 upward until every bucket has [seedsPerBucket] seeds.
Future<Map<KlondikeDifficulty, List<int>>> _collect(
  int drawCount,
  Stopwatch stopwatch,
) async {
  final buckets = {for (final d in KlondikeDifficulty.values) d: <int>[]};
  final graded = <SeedReport>[];
  final workers = Platform.numberOfProcessors;
  var next = 1;
  bool full(KlondikeDifficulty d) => buckets[d]!.length >= seedsPerBucket;

  while (!KlondikeDifficulty.values.every(full)) {
    // Once medium and hard are full, only deals the greedy player wins are
    // still worth solving.
    final solveAll =
        !full(KlondikeDifficulty.medium) || !full(KlondikeDifficulty.hard);
    final batch = await Future.wait([
      for (var w = 0; w < workers; w++)
        _spawn(next + w * _chunkSize, drawCount, solveAll),
    ]);
    next += workers * _chunkSize;
    for (final report in batch.expand((reports) => reports)) {
      if (report.status != null && solveAll) graded.add(report);
      final difficulty = report.difficulty;
      if (difficulty == null || full(difficulty)) continue;
      if (!report.verified) {
        throw StateError('Seed ${report.seed}: the solution does not replay');
      }
      buckets[difficulty]!.add(report.seed);
    }
    final counts = [
      for (final MapEntry(:key, :value) in buckets.entries)
        '${key.name} ${value.length}',
    ];
    stdout.write(
      '\rdraw $drawCount: seeds 1..${next - 1}, ${counts.join(', ')} '
      '(${_seconds(stopwatch)})   ',
    );
  }
  stdout.writeln();
  _printSummary(drawCount, graded, buckets);
  return buckets;
}

Future<List<SeedReport>> _spawn(int from, int drawCount, bool solveAll) =>
    Isolate.run(() => _gradeSeeds(from, drawCount, solveAll));

List<SeedReport> _gradeSeeds(int from, int drawCount, bool solveAll) => [
  for (var seed = from; seed < from + _chunkSize; seed++)
    _gradeSeed(seed, drawCount, solveAll),
];

SeedReport _gradeSeed(int seed, int drawCount, bool solveAll) {
  const solver = KlondikeSolver();
  final state = dealFromSeed(seed, drawCount: drawCount);
  final greedyWins = solver.playGreedy(state) != null;
  if (!greedyWins && !solveAll) {
    return (
      seed: seed,
      greedyWins: false,
      status: null,
      nodes: 0,
      actions: 0,
      recycles: 0,
      verified: false,
      difficulty: null,
    );
  }
  final result = solver.solve(state, maxNodes: KlondikeGrading.maxNodes);
  final grade = DealGrade(
    seed: seed,
    drawCount: drawCount,
    greedyWins: greedyWins,
    result: result,
  );
  // Replay on the real rules, counting how often the waste is turned over.
  var recycles = 0;
  KlondikeState? replayed = state;
  for (final action in result.solution) {
    if (action is DrawAction) {
      final draw = replayed!.draw();
      if (draw != null && draw.recycled) recycles++;
      replayed = draw?.state;
    } else {
      replayed = action.applyTo(replayed!);
    }
    if (replayed == null) break;
  }
  return (
    seed: seed,
    greedyWins: greedyWins,
    status: result.status,
    nodes: result.nodes,
    actions: result.solution.length,
    recycles: recycles,
    verified: result.isSolved && (replayed?.isWon ?? false),
    difficulty: grade.difficulty,
  );
}

String _render(Map<int, Map<KlondikeDifficulty, List<int>>> deals) {
  final out = StringBuffer()
    ..writeln('// Generated by tool/generate_klondike_deals.dart. Do not edit.')
    ..writeln('//')
    ..writeln(
      '// Grading (KlondikeGrading), for seeds the solver won and whose',
    )
    ..writeln('// solution replayed to a win:')
    ..writeln('// - easy: the greedy player (no lookahead, no undo) wins;')
    ..writeln(
      '// - medium: otherwise, the solver needs at most '
      '${KlondikeGrading.mediumMaxNodes} nodes;',
    )
    ..writeln(
      '// - hard: the solver needs more nodes (budget '
      '${KlondikeGrading.maxNodes}).',
    )
    ..writeln()
    ..writeln('/// Winnable seeds for `dealFromSeed`, by draw count, then by')
    ..writeln(
      '/// difficulty (`KlondikeDifficulty.name`), in increasing order.',
    )
    ..writeln('const klondikeDeals = <int, Map<String, List<int>>>{');
  for (final MapEntry(key: drawCount, value: buckets) in deals.entries) {
    out.writeln('  $drawCount: {');
    for (final MapEntry(key: difficulty, value: seeds) in buckets.entries) {
      out.writeln("    '${difficulty.name}': [${seeds.join(', ')}],");
    }
    out.writeln('  },');
  }
  out.writeln('};');
  return out.toString();
}

void _printSummary(
  int drawCount,
  List<SeedReport> graded,
  Map<KlondikeDifficulty, List<int>> buckets,
) {
  final n = graded.length;
  int count(bool Function(SeedReport) test) => graded.where(test).length;
  String rate(int k) => _percent(k, n);
  print(
    'draw $drawCount, $n seeds fully graded: '
    'solved ${rate(count((r) => r.status == SolveStatus.solved))}, '
    'unknown ${rate(count((r) => r.status == SolveStatus.unknown))}, '
    'unsolvable ${rate(count((r) => r.status == SolveStatus.unsolvable))}, '
    'greedy wins ${rate(count((r) => r.greedyWins))}',
  );
  final bySeed = {for (final r in graded) r.seed: r};
  for (final MapEntry(key: difficulty, value: seeds) in buckets.entries) {
    final reports = [for (final s in seeds) ?bySeed[s]];
    print(
      '  ${difficulty.name.padRight(6)} ${seeds.length} seeds, '
      'natural share ${rate(count((r) => r.difficulty == difficulty))}'
      '${_averages(reports)}',
    );
  }
}

String _averages(List<SeedReport> reports) {
  if (reports.isEmpty) return '';
  double avg(int Function(SeedReport) value) =>
      reports.fold(0, (sum, r) => sum + value(r)) / reports.length;
  return ', avg ${avg((r) => r.nodes).round()} nodes, '
      '${avg((r) => r.actions).round()} actions, '
      '${avg((r) => r.recycles).toStringAsFixed(1)} recycles';
}

/// Prints the distribution of grading metrics over seeds 1..[count].
Future<void> _printStats(int count) async {
  final workers = Platform.numberOfProcessors;
  for (final drawCount in drawCounts) {
    final stopwatch = Stopwatch()..start();
    final reports = <SeedReport>[];
    for (var next = 1; next <= count; next += workers * _chunkSize) {
      final batch = await Future.wait([
        for (var w = 0; w < workers; w++)
          _spawn(next + w * _chunkSize, drawCount, true),
      ]);
      reports.addAll(batch.expand((r) => r).where((r) => r.seed <= count));
    }
    final buckets = {
      for (final d in KlondikeDifficulty.values)
        d: [
          for (final r in reports)
            if (r.difficulty == d) r.seed,
        ],
    };
    _printSummary(drawCount, reports, buckets);
    if (reports.any((r) => r.status == SolveStatus.solved && !r.verified)) {
      print('  SOME SOLUTIONS DO NOT REPLAY');
    }
    for (final greedy in [true, false]) {
      final nodes = [
        for (final r in reports)
          if (r.status == SolveStatus.solved && r.greedyWins == greedy) r.nodes,
      ]..sort();
      if (nodes.isEmpty) continue;
      String at(double p) => '${nodes[((nodes.length - 1) * p).round()]}';
      print(
        '  solver nodes when greedy ${greedy ? 'wins ' : 'loses'}: '
        'p10 ${at(.1)}, p25 ${at(.25)}, p50 ${at(.5)}, p75 ${at(.75)}, '
        'p90 ${at(.9)}, max ${nodes.last}',
      );
    }
    // To tune KlondikeGrading.mediumMaxNodes.
    final searched = [
      for (final r in reports)
        if (r.status == SolveStatus.solved && !r.greedyWins) r.nodes,
    ];
    String share(int threshold) => _percent(
      searched.where((nodes) => nodes > threshold).length,
      reports.length,
    );
    final hardShares = [
      for (final threshold in [250, 500, 1000, 2000, 5000])
        '>$threshold: ${share(threshold)}',
    ];
    print('  share of seeds hard with a threshold of ${hardShares.join(', ')}');
    print('  ${_seconds(stopwatch)}');
  }
}

String _percent(int part, int total) =>
    '${(100 * part / total).toStringAsFixed(1)}%';

String _seconds(Stopwatch stopwatch) =>
    '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s';
