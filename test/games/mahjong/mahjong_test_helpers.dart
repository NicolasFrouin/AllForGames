import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';

/// Face codes for readable boards.
final dots1 = TileFace.of(TileSuit.dots, 1).code;
final dots2 = TileFace.of(TileSuit.dots, 2).code;
final dots3 = TileFace.of(TileSuit.dots, 3).code;
final bamboo1 = TileFace.of(TileSuit.bamboo, 1).code;
final plum = TileFace.of(TileSuit.flowers, 1).code;
final orchid = TileFace.of(TileSuit.flowers, 2).code;
final spring = TileFace.of(TileSuit.seasons, 1).code;

/// A board of [layout] with a tile of each face of [faces] on the positions
/// in order: tile `i` is on position `i`.
MahjongState board(MahjongLayout layout, List<int> faces) => MahjongState(
  layout: layout,
  faces: faces,
  slots: [for (var i = 0; i < faces.length; i++) i],
);

/// A layout of the positions `(x, y, z)`.
MahjongLayout layoutOf(List<(int, int, int)> positions) => MahjongLayout(
  'test',
  [for (final (x, y, z) in positions) TilePosition(x, y, z)],
);

/// A row of [count] tiles side by side on the table.
MahjongLayout row(int count) =>
    layoutOf([for (var i = 0; i < count; i++) (i * 2, 0, 0)]);
