import 'dart:math';

import '../../cards/deal_random.dart';
import 'mahjong_layout.dart';

/// How big the shapes of a level are: a total of [minTiles] to [maxTiles]
/// tiles on [minLayers] to [maxLayers] layers, over a base of at most
/// [columns] by [rows] tiles.
///
/// Pure Dart: the rules, the generator and the offline tool use it.
class ShapeLevel {
  const ShapeLevel({
    required this.minTiles,
    required this.maxTiles,
    required this.minLayers,
    required this.maxLayers,
    required this.columns,
    required this.rows,
  }) : assert(columns % 2 == 1 && rows % 2 == 1 && maxTiles <= 144);

  final int minTiles;
  final int maxTiles;
  final int minLayers;
  final int maxLayers;
  final int columns;
  final int rows;
}

/// The id of the generated layouts: records name them by it.
const generatedLayoutId = 'random';

/// A layout made from [seed], in the size of [level]: the same seed always
/// gives the same shape.
///
/// The base is a symmetric outline (an ellipse, a diamond, a cross, two
/// lobes...) blurred by noise. Each layer lies on the one below, smaller,
/// gathered around one or two peaks or along a ridge, so tiles always rest
/// on tiles. The count of tiles is a multiple of four (a face has four
/// tiles), and every shape is left-right symmetric.
MahjongLayout generateLayout(int seed, ShapeLevel level) {
  final random = DealRandom(seed ^ 0x2545F491);
  final layers =
      level.minLayers + random.nextInt(level.maxLayers - level.minLayers + 1);
  // Each layer keeps this share of the one below: more for a tall shape,
  // whose top needs wide layers under it.
  final keep = 0.6 + layers * 0.025 + random.nextInt(11) / 100;
  final target = _roundTo4(
    level.minTiles + random.nextInt(level.maxTiles - level.minTiles + 1),
  ).clamp(level.minTiles, level.maxTiles);
  final outline = _outlines[random.nextInt(_outlines.length)];
  final peaks = _peaks[random.nextInt(_peaks.length)];
  final counts = _layerCounts(target, layers, keep, level);
  final noiseSeed = random.nextUint32();

  // The slopes can keep the upper layers smaller than planned: then a wider
  // base makes up the tiles.
  var stack = _build(level, counts, outline, peaks, DealRandom(noiseSeed));
  for (var attempt = 0; attempt < 8; attempt++) {
    final short = level.minTiles - _total(stack);
    if (short <= 0) break;
    counts[0] = min(counts[0] + short, level.columns * level.rows);
    stack = _build(level, counts, outline, peaks, DealRandom(noiseSeed));
  }

  // A multiple of four, at most the maximum: the top cells go first, a cell
  // of the middle column for an odd change, a mirrored pair otherwise.
  final cx = (level.columns - 1) / 2;
  while (_total(stack) % 4 != 0 || _total(stack) > level.maxTiles) {
    final single = _total(stack).isOdd;
    _Cell? removable({required bool gentle}) {
      for (var z = stack.length - 1; z >= 0; z--) {
        final above = z + 1 < stack.length ? stack[z + 1] : const <_Cell>{};
        for (final cell in stack[z]) {
          final middle = cell.c == level.columns - 1 - cell.c;
          if (middle == single &&
              cell.c <= cx &&
              !above.contains(cell) &&
              (!gentle || _steps(stack, cell).every((h) => h <= z + 3))) {
            stack[z].removeAll(_unit(cell, level));
            return cell;
          }
        }
      }
      return null;
    }

    // A steeper step only when nothing else can go.
    if (removable(gentle: true) == null && removable(gentle: false) == null) {
      break;
    }
  }
  stack.removeWhere((layer) => layer.isEmpty);

  final minC = stack.first.map((cell) => cell.c).reduce(min);
  final minR = stack.first.map((cell) => cell.r).reduce(min);
  return MahjongLayout(generatedLayoutId, [
    for (final (z, layer) in stack.indexed)
      for (final cell in layer.toList()..sort(_byRow))
        TilePosition((cell.c - minC) * 2, (cell.r - minR) * 2, z),
  ]);
}

typedef _Cell = ({int c, int r});

int _total(List<Set<_Cell>> stack) =>
    stack.fold(0, (sum, layer) => sum + layer.length);

/// The heights of the neighbors of [cell] on the base.
Iterable<int> _steps(List<Set<_Cell>> stack, _Cell cell) sync* {
  for (var dr = -1; dr <= 1; dr++) {
    for (var dc = -1; dc <= 1; dc++) {
      final next = (c: cell.c + dc, r: cell.r + dr);
      if (stack.first.contains(next)) {
        yield stack.where((layer) => layer.contains(next)).length;
      }
    }
  }
}

/// A cell and its mirror (one cell on the middle column).
List<_Cell> _unit(_Cell cell, ShapeLevel level) => [
  cell,
  if (cell.c != level.columns - 1 - cell.c)
    (c: level.columns - 1 - cell.c, r: cell.r),
];

/// The layers of a shape: [counts] cells each, as far as the slopes allow.
List<Set<_Cell>> _build(
  ShapeLevel level,
  List<int> counts,
  double Function(double u, double v) outline,
  double Function(double u, double v) peaks,
  DealRandom random,
) {
  final cx = (level.columns - 1) / 2;
  final cy = (level.rows - 1) / 2;
  double u(int c) => (c - cx) / max(cx, 1);
  double v(int r) => (r - cy) / max(cy, 1);

  /// The units of [cells] with the lowest scores, [count] cells in all.
  Set<_Cell> pick(
    Iterable<_Cell> cells,
    int count,
    double Function(_Cell) at, {
    required double blur,
  }) {
    final units = [
      for (final cell in cells)
        if (cell.c <= cx)
          (_unit(cell, level), at(cell) + random.nextInt(1000) / 1000 * blur),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final chosen = <_Cell>{};
    for (final (cells, _) in units) {
      if (chosen.length + cells.length <= count) chosen.addAll(cells);
      if (chosen.length == count) break;
    }
    return chosen;
  }

  final grid = [
    for (var r = 0; r < level.rows; r++)
      for (var c = 0; c < level.columns; c++) (c: c, r: r),
  ];
  final base = pick(
    grid,
    counts.first,
    (cell) => outline(u(cell.c), v(cell.r)),
    blur: 0.35,
  );
  final stack = [base];
  for (final count in counts.skip(1)) {
    final below = stack.last;
    if (count < 1 || below.length < 2) break;
    // Each layer is drawn a little up and to the left: a stack more than
    // three layers above a neighbor would hide the middle of that tile. So
    // a cell only rises when its neighbors are at most two layers lower.
    final under = stack.length >= 3 ? stack[stack.length - 3] : base;
    bool gentle(_Cell cell) {
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final next = (c: cell.c + dc, r: cell.r + dr);
          if (base.contains(next) && !under.contains(next)) return false;
        }
      }
      return true;
    }

    // Less noise up there: smooth slopes, not towers.
    final layer = pick(
      below.where(gentle),
      count,
      (cell) => peaks(u(cell.c), v(cell.r)),
      blur: 0.12,
    );
    if (layer.isEmpty) break;
    stack.add(layer);
  }
  return stack;
}

int _byRow(_Cell a, _Cell b) => a.r != b.r ? a.r - b.r : a.c - b.c;

int _roundTo4(int count) => (count / 4).round() * 4;

/// How many tiles each of [layers] layers gets, each [keep] of the one
/// below, [target] in all (the base takes what the rounding leaves).
List<int> _layerCounts(int target, int layers, double keep, ShapeLevel level) {
  final shares = [for (var z = 0; z < layers; z++) pow(keep, z).toDouble()];
  final sum = shares.reduce((a, b) => a + b);
  final counts = [
    for (final share in shares) max(1, (target * share / sum).round()),
  ];
  counts[0] = (target - counts.skip(1).fold(0, (a, b) => a + b))
      .clamp(counts.length > 1 ? counts[1] : 1, level.columns * level.rows)
      .toInt();
  return counts;
}

/// Outlines of the base: the distance of a cell from the middle (u, v from
/// -1 to 1); the closest cells make the base.
final _outlines = <double Function(double u, double v)>[
  // An ellipse.
  (u, v) => sqrt(u * u + v * v),
  // A diamond.
  (u, v) => (u.abs() + v.abs()) * 0.8,
  // A rounded rectangle.
  (u, v) => max(u.abs(), v.abs()) * 0.85 + (u * u + v * v) * 0.1,
  // A cross.
  (u, v) => min(max(u.abs(), v.abs() * 2.2), max(u.abs() * 2.2, v.abs())),
  // Two lobes side by side.
  (u, v) => min(_distance(u - 0.5, v), _distance(u + 0.5, v)) * 1.3,
  // A bow tie: wide at the sides, narrow in the middle.
  (u, v) => v.abs() * (1.6 - u.abs()) + u.abs() * 0.3,
];

/// Where the upper layers gather: around the middle, two peaks, or a ridge.
final _peaks = <double Function(double u, double v)>[
  (u, v) => _distance(u, v * 1.3),
  (u, v) => min(_distance(u - 0.45, v), _distance(u + 0.45, v)),
  (u, v) => v.abs() * 1.6 + u.abs() * 0.35,
];

double _distance(double u, double v) => sqrt(u * u + v * v);
