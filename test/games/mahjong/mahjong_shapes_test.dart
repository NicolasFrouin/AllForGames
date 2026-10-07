import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_shapes.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:flutter_test/flutter_test.dart';

/// The count of tiles and the last 8 positions (x, y, z) of the Hard shape
/// of seed 1 on the Dart VM: `deals_on_web_test.dart` checks the web makes
/// the same shape.
const seed1HardShape = [
  128, //
  20, 8, 6, 10, 8, 6, 0, 8, 6, 20, 8, 5, //
  12, 8, 5, 10, 8, 5, 8, 8, 5, 0, 8, 5,
];

List<int> hardShapeOfSeed1() {
  final layout = generateLayout(1, MahjongDifficulty.hard.shape);
  return [
    layout.length,
    for (final p in layout.positions.reversed.take(8)) ...[p.x, p.y, p.z],
  ];
}

/// The height of each cell (in tiles) of [layout].
Map<(int, int), int> heights(MahjongLayout layout) =>
    {for (final p in layout.positions) (p.x, p.y): 0}..updateAll((cell, _) {
      final (x, y) = cell;
      return layout.positions.where((p) => p.x == x && p.y == y).length;
    });

/// The biggest step between two neighbor cells, in layers.
int steepest(MahjongLayout layout) {
  final height = heights(layout);
  var steepest = 0;
  for (final MapEntry(key: (x, y), value: h) in height.entries) {
    for (var dx = -2; dx <= 2; dx += 2) {
      for (var dy = -2; dy <= 2; dy += 2) {
        if (height[(x + dx, y + dy)] case final other?) {
          if (h - other > steepest) steepest = h - other;
        }
      }
    }
  }
  return steepest;
}

void main() {
  for (final difficulty in MahjongDifficulty.values) {
    final level = difficulty.shape;
    test('${difficulty.name}: every seed gives a playable, symmetric shape of '
        'its size', () {
      for (var seed = 1; seed <= 60; seed++) {
        final layout = generateLayout(seed, level);
        final reason = '${difficulty.name} seed $seed';
        expect(layout.id, generatedLayoutId);
        expect(layout.length % 4, 0, reason: reason);
        expect(
          layout.length,
          inInclusiveRange(level.minTiles, level.maxTiles),
          reason: reason,
        );
        expect(layout.layers, lessThanOrEqualTo(level.maxLayers));
        expect(
          generateLayout(seed, level).positions,
          layout.positions,
          reason: 'the same seed gives the same shape',
        );
        final positions = layout.positions.toSet();
        for (final p in positions) {
          if (p.z > 0) {
            expect(
              positions,
              contains(TilePosition(p.x, p.y, p.z - 1)),
              reason: '$reason: $p rests on a tile',
            );
          }
          expect(
            positions,
            contains(TilePosition(layout.width - 2 - p.x, p.y, p.z)),
            reason: '$reason: $p has its mirror',
          );
        }
        expect(
          removalOrder(
            layout,
            List.filled(layout.length, true),
            DealRandom(seed),
            attempts: 1000,
          ),
          isNotNull,
          reason: '$reason can be cleared',
        );
        final tray = generateTrayDeal(layout, seed, difficulty.tray);
        expect(
          TrayState(tray.state, const []).isSolvedBy(tray.solution),
          isTrue,
          reason: reason,
        );
      }
    });

    test('${difficulty.name}: steps between neighbors stay low, so a tile '
        'next to a stack shows its middle', () {
      // A trim to a multiple of four may leave a rare steeper step.
      final steep = [
        for (var seed = 1; seed <= 100; seed++)
          if (steepest(generateLayout(seed, level)) > 3) seed,
      ];
      expect(steep.length, lessThanOrEqualTo(2), reason: '$steep');
    });
  }

  test('the shape of a seed never changes', () {
    expect(hardShapeOfSeed1(), seed1HardShape);
  });

  test('Hard shapes rise up to 8 layers', () {
    final layers = {
      for (var seed = 1; seed <= 100; seed++)
        generateLayout(seed, MahjongDifficulty.hard.shape).layers,
    };
    expect(layers, contains(8));
    expect(layers.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(4));
  });
}
