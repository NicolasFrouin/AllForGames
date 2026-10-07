import 'mahjong_layout.dart';
import 'mahjong_shapes.dart';

export 'mahjong_shapes.dart' show ShapeLevel;

/// The ways to play Mahjong: [classic] matches two free tiles at a time;
/// in [tray], each tile tapped goes into a tray of four places, where two
/// tiles of a face clear each other, and a full tray loses the game.
///
/// Pure Dart: the settings and the offline tool use it.
enum MahjongMode { classic, tray }

/// Where the tray of the tray mode is, next to the board (a setting).
enum MahjongTraySide { top, bottom, left, right }

/// The shape of a new deal: [generated] from its seed (a new one each time),
/// or the [classic] layout of its level (the Pyramid, the Turtle).
enum MahjongShape { generated, classic }

/// How the tray deals of a level are built (`generateTrayDeal`): the order
/// that wins a deal holds at most [held] tiles in the tray at once. After a
/// pick that waits in the tray, the next one waits too with [waitPercent]
/// chances. [blindPercent] of the pairs are not free together: their first
/// tile goes into the tray before its partner is free, so the player must
/// guess it. [decoyPercent] of the second pairs of a face can be seen with
/// the first pair: more pairs to see, in an order other than the winning
/// one. `tool/mahjong_difficulty.dart` shows that seen pairs make a deal
/// easier, blind pairs and held tiles harder.
class TrayLevel {
  const TrayLevel({
    required this.held,
    required this.waitPercent,
    required this.blindPercent,
    required this.decoyPercent,
  }) : assert(held >= 1 && held < 4);

  final int held;
  final int waitPercent;
  final int blindPercent;
  final int decoyPercent;
}

/// Levels of Mahjong deals: the size of their generated shapes ([shape]),
/// or the classic layout ([layoutId]); the share of faces placed as traps by
/// the generator (`generateDeal`), or the tray deal level ([tray]); the
/// share of tiles that lie face down ([hiddenPercent]), and the discs to
/// free in the discs mode. `tool/mahjong_difficulty.dart` checks them with
/// simulated players.
///
/// Pure Dart: the rules, the generator and the tool use it without Flutter.
enum MahjongDifficulty {
  easy(
    layoutId: 'pyramid',
    shape: ShapeLevel(
      minTiles: 64,
      maxTiles: 80,
      minLayers: 2,
      maxLayers: 3,
      columns: 11,
      rows: 7,
    ),
    trapPercent: 0,
    tray: TrayLevel(held: 1, waitPercent: 0, blindPercent: 0, decoyPercent: 0),
    hiddenPercent: 0,
    discs: 2,
  ),
  medium(
    layoutId: 'turtle',
    shape: ShapeLevel(
      minTiles: 100,
      maxTiles: 120,
      minLayers: 4,
      maxLayers: 6,
      columns: 13,
      rows: 9,
    ),
    trapPercent: 15,
    tray: TrayLevel(
      held: 2,
      waitPercent: 40,
      blindPercent: 50,
      decoyPercent: 30,
    ),
    hiddenPercent: 10,
    discs: 3,
  ),
  hard(
    layoutId: 'turtle',
    shape: ShapeLevel(
      minTiles: 128,
      maxTiles: 144,
      minLayers: 6,
      maxLayers: 8,
      columns: 15,
      rows: 9,
    ),
    trapPercent: 50,
    tray: TrayLevel(
      held: 3,
      waitPercent: 80,
      blindPercent: 100,
      decoyPercent: 0,
    ),
    hiddenPercent: 20,
    discs: 4,
  );

  const MahjongDifficulty({
    required this.layoutId,
    required this.shape,
    required this.trapPercent,
    required this.tray,
    required this.hiddenPercent,
    required this.discs,
  });

  /// The classic layout of the level.
  final String layoutId;
  final ShapeLevel shape;
  final int trapPercent;
  final TrayLevel tray;
  final int hiddenPercent;
  final int discs;

  /// The classic layout of the level, transposed when asked.
  MahjongLayout layout({bool transposed = false}) =>
      layoutById(layoutId, transposed: transposed)!;

  /// The layout of a deal: generated from [seed] for [MahjongShape.generated].
  MahjongLayout layoutFor(MahjongShape kind, int seed) => switch (kind) {
    MahjongShape.generated => generateLayout(seed, shape),
    MahjongShape.classic => layout(),
  };
}
