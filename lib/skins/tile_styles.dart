import 'package:material_ui/material_ui.dart';

import '../games/mahjong/mahjong_tile_view.dart';
import '../games/mahjong/mahjong_tiles.dart';

/// The colors the art of the tile faces is drawn with. A dark face needs
/// light ink.
class TileInk {
  const TileInk({
    required this.red,
    required this.green,
    required this.blue,
    required this.black,
    required this.hollow,
    required this.flowers,
    required this.seasons,
    required this.flowerMark,
    required this.seasonMark,
  });

  /// Coins, sticks, numerals and dragons.
  final Color red;
  final Color green;
  final Color blue;

  /// Winds and the mark under the numerals.
  final Color black;

  /// The rings inside the coins, the joints of the sticks: the color of the
  /// face.
  final Color hollow;

  /// The icon of each flower and season, by rank.
  final List<Color> flowers;
  final List<Color> seasons;

  /// The corner number and band that tell a flower from a season.
  final Color flowerMark;
  final Color seasonMark;
}

const _classicInk = TileInk(
  red: Color(0xFFC62828),
  green: Color(0xFF23803A),
  blue: Color(0xFF1C4E9E),
  black: Color(0xFF1B2440),
  hollow: Color(0xFFFFFDF4),
  flowers: [
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFFEF8F00),
    Color(0xFF2E7D32),
  ],
  seasons: [
    Color(0xFF43A047),
    Color(0xFFF57C00),
    Color(0xFFB5541C),
    Color(0xFF1E88E5),
  ],
  flowerMark: Color(0xFFC2185B),
  seasonMark: Color(0xFF1565C0),
);

/// The look of the Mahjong tiles.
class TileStyle {
  const TileStyle({
    required this.id,
    required this.faceColors,
    required this.edgeColor,
    required this.bodyColors,
    required this.backColors,
    this.rimColor,
    this.selectedFaceColors = const [Color(0xFFFFF4C9), Color(0xFFFFD970)],
    this.selectedEdgeColor = const Color(0xFFE0A100),
    this.dimColor = const Color(0x1A1B2440),
    this.ink = _classicInk,
    this.unlockedBy,
  });

  final String id;

  /// Face gradient, from the top-left to the bottom-right corner.
  final List<Color> faceColors;

  /// The thin line around the face.
  final Color edgeColor;

  /// The thickness of a tile: its body under the face, from the back to the
  /// face, then its back, from the table up.
  final List<Color> bodyColors;
  final List<Color> backColors;

  /// A line inside the edge of the face, if any.
  final Color? rimColor;

  /// The face and edge of the tile the player picked.
  final List<Color> selectedFaceColors;
  final Color selectedEdgeColor;

  /// Laid over a blocked tile.
  final Color dimColor;

  final TileInk ink;

  /// Id of the achievement that unlocks this style, null when it is free.
  final String? unlockedBy;
}

/// Ivory tiles with a jade back.
const classicTileStyle = TileStyle(
  id: 'classic',
  faceColors: [Color(0xFFFFFDF4), Color(0xFFF0E6CC)],
  edgeColor: Color(0xFFBFAE84),
  bodyColors: [Color(0xFFCDBB8E), Color(0xFFE2D4AE)],
  backColors: [Color(0xFF0E5E4E), Color(0xFF14806A)],
);

const tileStyles = [
  classicTileStyle,
  TileStyle(
    id: 'jade',
    faceColors: [Color(0xFFF1F9EE), Color(0xFFCDE6CA)],
    edgeColor: Color(0xFF8DBB93),
    bodyColors: [Color(0xFF8CC29A), Color(0xFFBBDDBE)],
    backColors: [Color(0xFF063D2E), Color(0xFF0E5C46)],
    unlockedBy: 'mahjong.firstWin',
  ),
  TileStyle(
    id: 'bamboo',
    faceColors: [Color(0xFFF7F5DA), Color(0xFFDDD8A0)],
    edgeColor: Color(0xFFB3AC66),
    bodyColors: [Color(0xFFC6BC74), Color(0xFFE1DAA4)],
    backColors: [Color(0xFF3D6B18), Color(0xFF6A9C2E)],
    ink: TileInk(
      red: Color(0xFFC0392B),
      green: Color(0xFF2E7A28),
      blue: Color(0xFF1F4F8F),
      black: Color(0xFF3B2A14),
      hollow: Color(0xFFF7F5DA),
      flowers: [
        Color(0xFFD81B60),
        Color(0xFF8E24AA),
        Color(0xFFE67E00),
        Color(0xFF2E7D32),
      ],
      seasons: [
        Color(0xFF43A047),
        Color(0xFFE66A00),
        Color(0xFFA14A16),
        Color(0xFF1E88E5),
      ],
      flowerMark: Color(0xFFB0174F),
      seasonMark: Color(0xFF1F5E9E),
    ),
    unlockedBy: 'mahjong.turtleWin',
  ),
  TileStyle(
    id: 'ebony',
    faceColors: [Color(0xFF3B312B), Color(0xFF1A1512)],
    edgeColor: Color(0xFF6E5646),
    bodyColors: [Color(0xFF7A4B28), Color(0xFF9C6438)],
    backColors: [Color(0xFF3E2512), Color(0xFF5E3A1E)],
    selectedFaceColors: [Color(0xFF6A5420), Color(0xFF3F3010)],
    selectedEdgeColor: Color(0xFFFFC940),
    dimColor: Color(0x33000000),
    ink: TileInk(
      red: Color(0xFFFF6B5E),
      green: Color(0xFF5BD08A),
      blue: Color(0xFF72B4FF),
      black: Color(0xFFF3E9D6),
      hollow: Color(0xFF2A221D),
      flowers: [
        Color(0xFFFF77A6),
        Color(0xFFD594FF),
        Color(0xFFFFB74D),
        Color(0xFF7FD67F),
      ],
      seasons: [
        Color(0xFF8BD86B),
        Color(0xFFFFA040),
        Color(0xFFE8915C),
        Color(0xFF6EC1FF),
      ],
      flowerMark: Color(0xFFFF7AA8),
      seasonMark: Color(0xFF7FB8FF),
    ),
    unlockedBy: 'mahjong.hardWin',
  ),
  TileStyle(
    id: 'coral',
    faceColors: [Color(0xFFFFF4F2), Color(0xFFF8D6D1)],
    edgeColor: Color(0xFFE0A79E),
    bodyColors: [Color(0xFFEBAFA4), Color(0xFFF6D0C8)],
    backColors: [Color(0xFFB53A2C), Color(0xFFE2624F)],
    unlockedBy: 'mahjong.noHintWin',
  ),
  TileStyle(
    id: 'sapphire',
    faceColors: [Color(0xFFF5F9FF), Color(0xFFD3E2F6)],
    edgeColor: Color(0xFF9AB2D6),
    bodyColors: [Color(0xFFAFC4E4), Color(0xFFD0DEF2)],
    backColors: [Color(0xFF0D1F4A), Color(0xFF1B3A7A)],
    unlockedBy: 'mahjong.combo10',
  ),
  TileStyle(
    id: 'golden',
    faceColors: [Color(0xFFFFF5D2), Color(0xFFF3D27A), Color(0xFFF9E4A6)],
    edgeColor: Color(0xFFB8902A),
    bodyColors: [Color(0xFFC99525), Color(0xFFE6BD56)],
    backColors: [Color(0xFF6E4A00), Color(0xFFB07E0C)],
    rimColor: Color(0xFFB98A16),
    selectedFaceColors: [Color(0xFFFFF1E0), Color(0xFFFFB36B)],
    selectedEdgeColor: Color(0xFFE05A00),
    unlockedBy: 'mahjong.wins10',
  ),
];

/// The style with [id], or [classicTileStyle] when there is none (for
/// example a style saved by a newer app version).
TileStyle tileStyleById(String id) => tileStyles.firstWhere(
  (style) => style.id == id,
  orElse: () => classicTileStyle,
);

/// A sample tile (the 5 of dots) in [style], [width] pixels wide with its
/// thickness.
class TileStylePreview extends StatelessWidget {
  const TileStylePreview({super.key, required this.style, required this.width});

  /// Thickness of a tile for a face width of 1, as on the board.
  static const _depthRatio = 0.13;

  final TileStyle style;
  final double width;

  @override
  Widget build(BuildContext context) {
    final faceWidth = width / (1 + _depthRatio);
    return MahjongTileView(
      face: TileFace.of(TileSuit.dots, 5),
      faceSize: Size(faceWidth, faceWidth * 1.3),
      depth: faceWidth * _depthRatio,
      style: style,
    );
  }
}
