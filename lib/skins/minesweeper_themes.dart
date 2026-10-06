import 'package:material_ui/material_ui.dart';

import '../games/minesweeper/minesweeper_art.dart';

/// The colors of the Minesweeper screen and board.
class MinesweeperTheme {
  const MinesweeperTheme({
    required this.id,
    required this.table,
    required this.bar,
    required this.frame,
    required this.covered,
    required this.coveredLight,
    required this.coveredShade,
    required this.open,
    required this.openLine,
    required this.numbers,
    required this.mine,
    required this.mineShine,
    required this.exploded,
    required this.flag,
    required this.flagPole,
    required this.cross,
    required this.accent,
    this.corner = 0.16,
    this.bevel = 0.09,
    this.unlockedBy,
  });

  final String id;

  /// The table under the board: its center, then its edges.
  final List<Color> table;

  /// App bar.
  final Color bar;

  /// Around the board and between the covered cells.
  final Color frame;

  /// The raised cover of a hidden cell: its face, top-left edge and
  /// bottom-right edge.
  final Color covered;
  final Color coveredLight;
  final Color coveredShade;

  /// An open cell, and the lines between open cells.
  final Color open;
  final Color openLine;

  /// Colors of the numbers 1 to 8.
  final List<Color> numbers;
  final Color mine;
  final Color mineShine;

  /// Under the mine the player opened.
  final Color exploded;
  final Color flag;
  final Color flagPole;

  /// The cross over a wrong flag.
  final Color cross;

  /// Hints, pressed cells and bursts.
  final Color accent;

  /// Radius of the corners of a cover, and width of its edges, for a cell
  /// width of 1.
  final double corner;
  final double bevel;

  /// Id of the achievement that unlocks this theme, null when it is free.
  final String? unlockedBy;
}

/// Slate covers on a blue-grey table.
const classicMinesweeperTheme = MinesweeperTheme(
  id: 'classic',
  table: [Color(0xFF2A3F4F), Color(0xFF111B23)],
  bar: Color(0xFF13202A),
  frame: Color(0xFF0E161D),
  covered: Color(0xFF8EA8BE),
  coveredLight: Color(0xFFC9D8E5),
  coveredShade: Color(0xFF587389),
  open: Color(0xFFE3E9EE),
  openLine: Color(0xFFC3CDD6),
  numbers: [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF1A237E),
    Color(0xFF7B1F1F),
    Color(0xFF00838F),
    Color(0xFF212121),
    Color(0xFF6B6B6B),
  ],
  mine: Color(0xFF263238),
  mineShine: Color(0xFFFFFFFF),
  exploded: Color(0xFFE53935),
  flag: Color(0xFFE53935),
  flagPole: Color(0xFF263238),
  cross: Color(0xFFB71C1C),
  accent: Color(0xFFFFC107),
);

const minesweeperThemes = [
  classicMinesweeperTheme,
  // Teal waves over sea foam, with yellow buoys for flags.
  MinesweeperTheme(
    id: 'ocean',
    table: [Color(0xFF0F4C5C), Color(0xFF06222B)],
    bar: Color(0xFF082C36),
    frame: Color(0xFF052029),
    covered: Color(0xFF2F9DB0),
    coveredLight: Color(0xFF86D5E0),
    coveredShade: Color(0xFF17677A),
    open: Color(0xFFE4F3F1),
    openLine: Color(0xFFBFDCD8),
    numbers: [
      Color(0xFF0D47A1),
      Color(0xFF1B7A3E),
      Color(0xFFC62828),
      Color(0xFF311B92),
      Color(0xFF8E2424),
      Color(0xFF00695C),
      Color(0xFF1C2833),
      Color(0xFF5F6B73),
    ],
    mine: Color(0xFF102A33),
    mineShine: Color(0xFFFFFFFF),
    exploded: Color(0xFFFF5A4E),
    flag: Color(0xFFFFE14D),
    flagPole: Color(0xFF0B3440),
    cross: Color(0xFFB71C1C),
    accent: Color(0xFFFFF176),
    unlockedBy: 'minesweeper.firstWin',
  ),
  // Grass over sand.
  MinesweeperTheme(
    id: 'meadow',
    table: [Color(0xFF3A6B2E), Color(0xFF16300F)],
    bar: Color(0xFF1D3B16),
    frame: Color(0xFF2A4D20),
    covered: Color(0xFF8CC63F),
    coveredLight: Color(0xFFBDE27F),
    coveredShade: Color(0xFF5C8F27),
    open: Color(0xFFEAD7B7),
    openLine: Color(0xFFD6BD95),
    numbers: [
      Color(0xFF1558B0),
      Color(0xFF26702B),
      Color(0xFFC62828),
      Color(0xFF4A148C),
      Color(0xFF8B2500),
      Color(0xFF00695C),
      Color(0xFF212121),
      Color(0xFF5E5E5E),
    ],
    mine: Color(0xFF3B2F2F),
    mineShine: Color(0xFFFFFFFF),
    exploded: Color(0xFFE53935),
    flag: Color(0xFFB3140C),
    flagPole: Color(0xFF4E342E),
    cross: Color(0xFFB71C1C),
    accent: Color(0xFFFFEE58),
    unlockedBy: 'minesweeper.intermediateWin',
  ),
  // Dark basalt with glowing edges, over warm ash.
  MinesweeperTheme(
    id: 'lava',
    table: [Color(0xFF4A1E10), Color(0xFF160703)],
    bar: Color(0xFF240B05),
    frame: Color(0xFF120604),
    covered: Color(0xFF4E3B36),
    coveredLight: Color(0xFFFF8F3F),
    coveredShade: Color(0xFF231714),
    open: Color(0xFFF5E3C8),
    openLine: Color(0xFFE0C7A2),
    numbers: [
      Color(0xFF1F57C3),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
      Color(0xFF311B92),
      Color(0xFF8B1E1E),
      Color(0xFF00695C),
      Color(0xFF212121),
      Color(0xFF665A52),
    ],
    mine: Color(0xFF2B1B17),
    mineShine: Color(0xFFFFB074),
    exploded: Color(0xFFFF3D00),
    flag: Color(0xFFFFC400),
    flagPole: Color(0xFFFFE0B2),
    cross: Color(0xFFFF6E40),
    accent: Color(0xFFFFD740),
    unlockedBy: 'minesweeper.expertWin',
  ),
  // Pink and cream, purple flags.
  MinesweeperTheme(
    id: 'candy',
    table: [Color(0xFF7A3B6B), Color(0xFF2E1028)],
    bar: Color(0xFF3A1534),
    frame: Color(0xFF4A1C40),
    covered: Color(0xFFF48FB1),
    coveredLight: Color(0xFFFCC9DC),
    coveredShade: Color(0xFFC9567F),
    open: Color(0xFFFFF5F9),
    openLine: Color(0xFFF2D3E1),
    numbers: [
      Color(0xFF1E5BC6),
      Color(0xFF13804F),
      Color(0xFFD81B60),
      Color(0xFF4527A0),
      Color(0xFF9A3412),
      Color(0xFF00838F),
      Color(0xFF37474F),
      Color(0xFF7D7178),
    ],
    mine: Color(0xFF4A1C40),
    mineShine: Color(0xFFFFFFFF),
    exploded: Color(0xFFE53935),
    flag: Color(0xFF5E35B1),
    flagPole: Color(0xFF4A1C40),
    cross: Color(0xFF8E0038),
    accent: Color(0xFF26C6DA),
    unlockedBy: 'minesweeper.fastWin',
  ),
  // Dark covers over a darker field, bright numbers.
  MinesweeperTheme(
    id: 'night',
    table: [Color(0xFF1A2138), Color(0xFF080B14)],
    bar: Color(0xFF0E1322),
    frame: Color(0xFF060910),
    covered: Color(0xFF34405F),
    coveredLight: Color(0xFF5A6995),
    coveredShade: Color(0xFF1E263B),
    open: Color(0xFF151B2C),
    openLine: Color(0xFF262F48),
    numbers: [
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFF7A7A),
      Color(0xFFB39DDB),
      Color(0xFFFFB74D),
      Color(0xFF4DD0E1),
      Color(0xFFECEFF1),
      Color(0xFF9EA7B8),
    ],
    mine: Color(0xFFB8C4D9),
    mineShine: Color(0xFFFFFFFF),
    exploded: Color(0xFFB3261E),
    flag: Color(0xFFFF5252),
    flagPole: Color(0xFFCFD8DC),
    cross: Color(0xFFFF8A80),
    accent: Color(0xFFFFD54F),
    unlockedBy: 'minesweeper.noFlagWin',
  ),
  // The grey bevels of old desktops, on their teal background.
  MinesweeperTheme(
    id: 'retro',
    table: [Color(0xFF008080), Color(0xFF005C5C)],
    bar: Color(0xFF000080),
    // As the covers: the bevels draw the grid.
    frame: Color(0xFFC0C0C0),
    covered: Color(0xFFC0C0C0),
    coveredLight: Color(0xFFFFFFFF),
    coveredShade: Color(0xFF7B7B7B),
    open: Color(0xFFC6C6C6),
    openLine: Color(0xFF8A8A8A),
    // The classic colors, a little darker to read on grey.
    numbers: [
      Color(0xFF0000F0),
      Color(0xFF006E00),
      Color(0xFFC80000),
      Color(0xFF000080),
      Color(0xFF800000),
      Color(0xFF006666),
      Color(0xFF000000),
      Color(0xFF4F4F4F),
    ],
    mine: Color(0xFF000000),
    mineShine: Color(0xFFFFFFFF),
    exploded: Color(0xFFFF0000),
    flag: Color(0xFFE00000),
    flagPole: Color(0xFF000000),
    cross: Color(0xFF000000),
    accent: Color(0xFFFFFF00),
    corner: 0,
    bevel: 0.12,
    unlockedBy: 'minesweeper.wins10',
  ),
];

/// The theme with [id], or [classicMinesweeperTheme] when there is none
/// (for example a theme saved by a newer app version).
MinesweeperTheme minesweeperThemeById(String id) =>
    minesweeperThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => classicMinesweeperTheme,
    );

/// A corner of a board in [theme], [width] pixels wide: covers, a flag, a
/// few numbers and a mine.
class MinesweeperThemePreview extends StatelessWidget {
  const MinesweeperThemePreview({
    super.key,
    required this.theme,
    required this.width,
  });

  /// Covered (`#`), flagged (`F`), open (a number, or `.`), mine (`*`).
  static const _cells = ['##F', '12#', '.13', '.1*'];

  /// Room around the cells, for a cell width of 1.
  static const _frame = 0.15;

  final MinesweeperTheme theme;
  final double width;

  static double heightOf(double width) {
    final cell = width / (_cells.first.length + 2 * _frame);
    return cell * (_cells.length + 2 * _frame);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: heightOf(width),
      child: CustomPaint(painter: _PreviewPainter(theme)),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.theme);

  final MinesweeperTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = MinesweeperThemePreview._cells;
    final cell =
        size.width / (cells.first.length + 2 * MinesweeperThemePreview._frame);
    final frame = cell * MinesweeperThemePreview._frame;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(frame * 2)),
      Paint()..color = theme.frame,
    );
    final art = MinesweeperArt(theme, cell);
    for (final (y, row) in cells.indexed) {
      for (var x = 0; x < row.length; x++) {
        final rect = Rect.fromLTWH(
          frame + x * cell,
          frame + y * cell,
          cell,
          cell,
        );
        switch (row[x]) {
          case '#':
            art.covered(canvas, rect);
          case 'F':
            art
              ..covered(canvas, rect)
              ..flag(canvas, rect);
          case '*':
            art
              ..open(canvas, rect)
              ..mine(canvas, rect);
          case final char:
            art.open(canvas, rect);
            if (int.tryParse(char) case final count?) {
              art.number(canvas, rect, count);
            }
        }
      }
    }
    art.dispose();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => oldDelegate.theme != theme;
}
