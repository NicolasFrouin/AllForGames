import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'mahjong_tiles.dart';

/// Ink of the tile faces.
const _blue = Color(0xFF1C4E9E);
const _green = Color(0xFF23803A);
const _red = Color(0xFFC62828);
const _ink = Color(0xFF1B2440);

/// The hint's rim and halo, apart from the gold of a selected tile.
const _hintColor = Color(0xFF26C6DA);

/// Flowers and seasons only match their own kind: a colored band and corner
/// number tell them apart.
const _flowerInk = Color(0xFFC2185B);
const _seasonInk = Color(0xFF1565C0);

/// A Mahjong tile seen from above, a little from the bottom right: an ivory
/// face, and its thickness (ivory, then the jade back) below and to the
/// right of it. Drawn with vector shapes, Material icons and Latin letters
/// only: no emoji and no CJK font, which the web does not always have.
///
/// The widget is [faceSize] plus [depth] on the right and at the bottom.
/// The board paints the glow of a hint around it ([paintHintHalo],
/// [paintHintRim]), so a pulse does not repaint the tile.
class MahjongTileView extends StatelessWidget {
  const MahjongTileView({
    super.key,
    required this.face,
    required this.faceSize,
    required this.depth,
    this.selected = false,
    this.dimmed = false,
  });

  final TileFace face;
  final Size faceSize;
  final double depth;

  /// Picked by the player: a warm face and a golden rim.
  final bool selected;

  /// Blocked: the face is a little darker.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomPaint(
      size: Size(faceSize.width + depth, faceSize.height + depth),
      painter: _TilePainter(
        face: face,
        faceSize: faceSize,
        depth: depth,
        selected: selected,
        dimmed: dimmed,
        windLetter: switch (face.suit) {
          TileSuit.winds => [
            l10n.mahjongWindEastLetter,
            l10n.mahjongWindSouthLetter,
            l10n.mahjongWindWestLetter,
            l10n.mahjongWindNorthLetter,
          ][face.rank - 1],
          _ => '',
        },
      ),
    );
  }
}

/// The name of [face] for screen readers.
String tileName(TileFace face, AppLocalizations l10n) => switch (face.suit) {
  TileSuit.dots => l10n.mahjongTileDots(face.rank),
  TileSuit.bamboo => l10n.mahjongTileBamboo(face.rank),
  TileSuit.characters => l10n.mahjongTileCharacters(face.rank),
  TileSuit.winds => [
    l10n.mahjongTileEastWind,
    l10n.mahjongTileSouthWind,
    l10n.mahjongTileWestWind,
    l10n.mahjongTileNorthWind,
  ][face.rank - 1],
  TileSuit.dragons => [
    l10n.mahjongTileRedDragon,
    l10n.mahjongTileGreenDragon,
    l10n.mahjongTileWhiteDragon,
  ][face.rank - 1],
  TileSuit.flowers => [
    l10n.mahjongTilePlum,
    l10n.mahjongTileOrchid,
    l10n.mahjongTileChrysanthemum,
    l10n.mahjongTileBambooFlower,
  ][face.rank - 1],
  TileSuit.seasons => [
    l10n.mahjongTileSpring,
    l10n.mahjongTileSummer,
    l10n.mahjongTileAutumn,
    l10n.mahjongTileWinter,
  ][face.rank - 1],
};

/// The rounded face of a tile at [faceRect].
RRect _faceRRect(Rect faceRect) =>
    RRect.fromRectAndRadius(faceRect, Radius.circular(faceRect.width * 0.12));

/// A hint's halo, painted under a tile whose face is at [faceRect]: [glow]
/// from 0 (none) to 1.
void paintHintHalo(Canvas canvas, Rect faceRect, double depth, double glow) {
  final w = faceRect.width;
  canvas.drawRRect(
    _faceRRect(faceRect.shift(Offset(depth / 2, depth / 2))).inflate(w * 0.06),
    Paint()
      ..color = _hintColor.withValues(alpha: 0.9 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
  );
}

/// A hint's tint and rim, painted over the face of a tile at [faceRect].
void paintHintRim(Canvas canvas, Rect faceRect, double glow) {
  final w = faceRect.width;
  final face = _faceRRect(faceRect);
  canvas.drawRRect(
    face,
    Paint()..color = _hintColor.withValues(alpha: 0.16 * glow),
  );
  canvas.drawRRect(
    face.deflate(max(1.0, w * 0.03)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, w * 0.06)
      ..color = _hintColor.withValues(alpha: glow),
  );
}

class _TilePainter extends CustomPainter {
  _TilePainter({
    required this.face,
    required this.faceSize,
    required this.depth,
    required this.selected,
    required this.dimmed,
    required this.windLetter,
  });

  final TileFace face;
  final Size faceSize;
  final double depth;
  final bool selected;
  final bool dimmed;
  final String windLetter;

  static const _flowerIcons = [
    Icons.local_florist,
    Icons.spa,
    Icons.filter_vintage,
    Icons.grass,
  ];
  static const _seasonIcons = [
    Icons.emoji_nature,
    Icons.wb_sunny,
    Icons.eco,
    Icons.ac_unit,
  ];
  static const _flowerColors = [
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFFEF8F00),
    Color(0xFF2E7D32),
  ];
  static const _seasonColors = [
    Color(0xFF43A047),
    Color(0xFFF57C00),
    Color(0xFFB5541C),
    Color(0xFF1E88E5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = faceSize.width;
    final radius = Radius.circular(w * 0.12);
    final faceRect = Offset.zero & faceSize;
    RRect at(double shift) =>
        RRect.fromRectAndRadius(faceRect.shift(Offset(shift, shift)), radius);

    // The shadow falls on the tiles of the layers below.
    canvas.drawRRect(
      at(depth).shift(Offset(depth * 0.5, depth * 0.8)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth * 0.9 + 1),
    );

    // The thickness: the jade back, then the ivory front, step by step.
    final steps = max(2, (depth / 1.5).ceil());
    for (var i = steps; i > 0; i--) {
      final t = i / steps;
      canvas.drawRRect(
        at(depth * t),
        Paint()
          ..color = t > 0.55
              ? Color.lerp(
                  const Color(0xFF0E5E4E),
                  const Color(0xFF14806A),
                  (1 - t) / 0.45,
                )!
              : Color.lerp(
                  const Color(0xFFCDBB8E),
                  const Color(0xFFE2D4AE),
                  1 - t / 0.55,
                )!,
      );
    }

    final faceRRect = at(0);
    canvas.drawRRect(
      faceRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [Color(0xFFFFF4C9), Color(0xFFFFD970)]
              : const [Color(0xFFFFFDF4), Color(0xFFF0E6CC)],
        ).createShader(faceRect),
    );
    canvas.drawRRect(
      faceRRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? max(1.5, w * 0.05) : max(0.8, w * 0.02)
        ..color = selected ? const Color(0xFFE0A100) : const Color(0xFFBFAE84),
    );

    final art = Rect.fromLTRB(
      w * 0.13,
      faceSize.height * 0.1,
      w * 0.87,
      faceSize.height * 0.9,
    );
    canvas.save();
    canvas.clipRRect(faceRRect);
    _paintFace(canvas, art);
    canvas.restore();

    if (dimmed && !selected) {
      canvas.drawRRect(faceRRect, Paint()..color = const Color(0x1A1B2440));
    }
  }

  void _paintFace(Canvas canvas, Rect art) {
    switch (face.suit) {
      case TileSuit.dots:
        _paintDots(canvas, art, face.rank);
      case TileSuit.bamboo:
        _paintBamboo(canvas, art, face.rank);
      case TileSuit.characters:
        _paintCharacter(canvas, art, face.rank);
      case TileSuit.winds:
        _paintText(
          canvas,
          windLetter,
          art.center,
          art.height * 0.62,
          _ink,
          weight: FontWeight.w900,
        );
      case TileSuit.dragons:
        _paintDragon(canvas, art, face.rank);
      case TileSuit.flowers:
        _paintFlowerOrSeason(
          canvas,
          art,
          face.rank,
          _flowerIcons[face.rank - 1],
          _flowerColors[face.rank - 1],
          _flowerInk,
        );
      case TileSuit.seasons:
        _paintFlowerOrSeason(
          canvas,
          art,
          face.rank,
          _seasonIcons[face.rank - 1],
          _seasonColors[face.rank - 1],
          _seasonInk,
        );
    }
  }

  /// Point ([x], [y]) of [art], from 0 to 1 on each side.
  static Offset _in(Rect art, double x, double y) =>
      Offset(art.left + art.width * x, art.top + art.height * y);

  static const _dotLayouts = <List<(double, double, Color)>>[
    [(0.5, 0.5, _red)],
    [(0.5, 0.26, _green), (0.5, 0.74, _blue)],
    [(0.2, 0.18, _blue), (0.5, 0.5, _red), (0.8, 0.82, _green)],
    [
      (0.27, 0.27, _blue),
      (0.73, 0.27, _green),
      (0.27, 0.73, _green),
      (0.73, 0.73, _blue),
    ],
    [
      (0.24, 0.2, _blue),
      (0.76, 0.2, _green),
      (0.5, 0.5, _red),
      (0.24, 0.8, _green),
      (0.76, 0.8, _blue),
    ],
    [
      (0.28, 0.17, _green),
      (0.72, 0.17, _green),
      (0.28, 0.5, _red),
      (0.72, 0.5, _red),
      (0.28, 0.83, _red),
      (0.72, 0.83, _red),
    ],
    [
      (0.18, 0.1, _green),
      (0.5, 0.21, _green),
      (0.82, 0.32, _green),
      (0.3, 0.6, _red),
      (0.7, 0.6, _red),
      (0.3, 0.88, _red),
      (0.7, 0.88, _red),
    ],
    [
      (0.28, 0.12, _blue),
      (0.72, 0.12, _blue),
      (0.28, 0.37, _blue),
      (0.72, 0.37, _blue),
      (0.28, 0.63, _blue),
      (0.72, 0.63, _blue),
      (0.28, 0.88, _blue),
      (0.72, 0.88, _blue),
    ],
    [
      (0.18, 0.17, _blue),
      (0.5, 0.17, _blue),
      (0.82, 0.17, _blue),
      (0.18, 0.5, _red),
      (0.5, 0.5, _red),
      (0.82, 0.5, _red),
      (0.18, 0.83, _green),
      (0.5, 0.83, _green),
      (0.82, 0.83, _green),
    ],
  ];

  static const _dotSizes = [
    0.42,
    0.24,
    0.2,
    0.21,
    0.19,
    0.17,
    0.145,
    0.135,
    0.15,
  ];

  /// Coins: a colored ring, a white ring, and a colored heart.
  static void _paintDots(Canvas canvas, Rect art, int rank) {
    final unit = min(art.width, art.height / 1.15);
    final radius = unit * _dotSizes[rank - 1];
    for (final (x, y, color) in _dotLayouts[rank - 1]) {
      final center = _in(art, x, y);
      if (rank == 1) {
        _coin(canvas, center, radius, _green);
        _coin(canvas, center, radius * 0.62, _red);
        _coin(canvas, center, radius * 0.3, _blue);
      } else {
        _coin(canvas, center, radius, color);
      }
    }
  }

  static void _coin(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..color = const Color(0xFFFFFDF4),
    );
    canvas.drawCircle(
      center,
      radius * 0.28,
      Paint()..color = const Color(0xFFFFFDF4),
    );
  }

  static const _bambooLayouts = <List<(double, double, Color)>>[
    [(0.5, 0.5, _green)],
    [(0.5, 0.27, _green), (0.5, 0.73, _blue)],
    [(0.5, 0.27, _green), (0.3, 0.73, _blue), (0.7, 0.73, _blue)],
    [
      (0.3, 0.27, _green),
      (0.7, 0.27, _blue),
      (0.3, 0.73, _blue),
      (0.7, 0.73, _green),
    ],
    [
      (0.22, 0.27, _green),
      (0.78, 0.27, _blue),
      (0.5, 0.5, _red),
      (0.22, 0.73, _blue),
      (0.78, 0.73, _green),
    ],
    [
      (0.2, 0.27, _green),
      (0.5, 0.27, _green),
      (0.8, 0.27, _green),
      (0.2, 0.73, _blue),
      (0.5, 0.73, _blue),
      (0.8, 0.73, _blue),
    ],
    [
      (0.5, 0.15, _red),
      (0.2, 0.5, _green),
      (0.5, 0.5, _green),
      (0.8, 0.5, _green),
      (0.2, 0.85, _green),
      (0.5, 0.85, _green),
      (0.8, 0.85, _green),
    ],
    [
      (0.14, 0.27, _green),
      (0.38, 0.27, _green),
      (0.62, 0.27, _green),
      (0.86, 0.27, _green),
      (0.14, 0.73, _blue),
      (0.38, 0.73, _blue),
      (0.62, 0.73, _blue),
      (0.86, 0.73, _blue),
    ],
    [
      (0.2, 0.17, _green),
      (0.5, 0.17, _red),
      (0.8, 0.17, _blue),
      (0.2, 0.5, _green),
      (0.5, 0.5, _red),
      (0.8, 0.5, _blue),
      (0.2, 0.83, _green),
      (0.5, 0.83, _red),
      (0.8, 0.83, _blue),
    ],
  ];

  /// Sticks with joints. The one of bamboo 1 is big, with leaves.
  static void _paintBamboo(Canvas canvas, Rect art, int rank) {
    final rows = rank == 7 || rank == 9 ? 3 : (rank == 1 ? 1 : 2);
    final height = rank == 1 ? art.height * 0.78 : art.height / rows * 0.82;
    final width = rank == 1
        ? art.width * 0.24
        : min(art.width * (rank == 8 ? 0.15 : 0.18), height * 0.42);
    for (final (x, y, color) in _bambooLayouts[rank - 1]) {
      _stick(canvas, _in(art, x, y), width, height, color);
    }
    if (rank == 1) {
      final leaf = Paint()..color = _green;
      for (final side in [-1.0, 1.0]) {
        final base = _in(art, 0.5 + side * 0.1, 0.42);
        final path = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            base.dx + side * art.width * 0.32,
            base.dy - art.height * 0.18,
            base.dx + side * art.width * 0.38,
            base.dy - art.height * 0.3,
          )
          ..quadraticBezierTo(
            base.dx + side * art.width * 0.12,
            base.dy - art.height * 0.2,
            base.dx,
            base.dy,
          );
        canvas.drawPath(path, leaf);
      }
    }
  }

  static void _stick(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color color,
  ) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * 0.45)),
      Paint()..color = color,
    );
    // A light stripe, and the joints.
    final light = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = max(0.8, width * 0.16)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.center.dx - width * 0.12, rect.top + width * 0.5),
      Offset(rect.center.dx - width * 0.12, rect.bottom - width * 0.5),
      light,
    );
    final joint = Paint()
      ..color = const Color(0xCCFFFDF4)
      ..strokeWidth = max(0.8, height * 0.05);
    for (final t in [0.5]) {
      final y = rect.top + rect.height * t;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), joint);
    }
  }

  /// A red numeral over a mark that stands for the character "wan".
  void _paintCharacter(Canvas canvas, Rect art, int rank) {
    _paintText(
      canvas,
      '$rank',
      _in(art, 0.5, 0.27),
      art.height * 0.5,
      _red,
      weight: FontWeight.w900,
    );
    final mark = Rect.fromLTRB(
      art.left + art.width * 0.14,
      art.top + art.height * 0.56,
      art.right - art.width * 0.14,
      art.bottom - art.height * 0.02,
    );
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, art.width * 0.075)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => _in(mark, x, y);
    final path = Path()
      // The grass on top.
      ..moveTo(p(0.05, 0.12).dx, p(0.05, 0.12).dy)
      ..lineTo(p(0.95, 0.12).dx, p(0.95, 0.12).dy)
      ..moveTo(p(0.32, 0).dx, p(0.32, 0).dy)
      ..lineTo(p(0.32, 0.26).dx, p(0.32, 0.26).dy)
      ..moveTo(p(0.68, 0).dx, p(0.68, 0).dy)
      ..lineTo(p(0.68, 0.26).dx, p(0.68, 0.26).dy)
      // The field in the middle.
      ..addRect(Rect.fromPoints(p(0.24, 0.36), p(0.76, 0.6)))
      ..moveTo(p(0.5, 0.36).dx, p(0.5, 0.36).dy)
      ..lineTo(p(0.5, 0.6).dx, p(0.5, 0.6).dy)
      // The legs, with a hook.
      ..moveTo(p(0.12, 1).dx, p(0.12, 1).dy)
      ..lineTo(p(0.12, 0.72).dx, p(0.12, 0.72).dy)
      ..lineTo(p(0.88, 0.72).dx, p(0.88, 0.72).dy)
      ..lineTo(p(0.88, 0.96).dx, p(0.88, 0.96).dy)
      ..lineTo(p(0.74, 0.9).dx, p(0.74, 0.9).dy)
      ..moveTo(p(0.5, 0.72).dx, p(0.5, 0.72).dy)
      ..lineTo(p(0.36, 0.92).dx, p(0.36, 0.92).dy)
      ..lineTo(p(0.62, 0.9).dx, p(0.62, 0.9).dy);
    canvas.drawPath(path, ink);
  }

  /// Red: a box with a stroke through it. Green: a leaf in a ring. White: a
  /// blue frame.
  static void _paintDragon(Canvas canvas, Rect art, int rank) {
    final unit = art.width;
    switch (rank) {
      case 1:
        final stroke = Paint()
          ..color = _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.13
          ..strokeJoin = StrokeJoin.round;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: art.center,
              width: unit * 0.82,
              height: art.height * 0.36,
            ),
            Radius.circular(unit * 0.06),
          ),
          stroke,
        );
        canvas.drawLine(
          _in(art, 0.5, 0.06),
          _in(art, 0.5, 0.94),
          stroke..strokeCap = StrokeCap.round,
        );
      case 2:
        final center = art.center;
        final radius = min(unit * 0.46, art.height * 0.36);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = _green
            ..style = PaintingStyle.stroke
            ..strokeWidth = unit * 0.09,
        );
        final top = center.translate(0, -radius * 0.72);
        final bottom = center.translate(0, radius * 0.72);
        final leaf = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            center.dx + radius * 0.85,
            center.dy,
            bottom.dx,
            bottom.dy,
          )
          ..quadraticBezierTo(
            center.dx - radius * 0.85,
            center.dy,
            top.dx,
            top.dy,
          );
        canvas.drawPath(leaf, Paint()..color = _green);
        canvas.drawLine(
          top.translate(0, radius * 0.2),
          bottom.translate(0, -radius * 0.2),
          Paint()
            ..color = const Color(0xFFFFFDF4)
            ..strokeWidth = unit * 0.05
            ..strokeCap = StrokeCap.round,
        );
      default:
        final frame = Rect.fromCenter(
          center: art.center,
          width: unit * 0.84,
          height: art.height * 0.84,
        );
        final paint = Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.07;
        canvas.drawRRect(
          RRect.fromRectAndRadius(frame, Radius.circular(unit * 0.08)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            frame.deflate(unit * 0.15),
            Radius.circular(unit * 0.04),
          ),
          paint..strokeWidth = unit * 0.035,
        );
    }
  }

  static void _paintFlowerOrSeason(
    Canvas canvas,
    Rect art,
    int rank,
    IconData icon,
    Color color,
    Color kind,
  ) {
    _paintText(
      canvas,
      String.fromCharCode(icon.codePoint),
      _in(art, 0.5, 0.46),
      min(art.width * 1.05, art.height * 0.72),
      color,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
    );
    _paintText(
      canvas,
      '$rank',
      _in(art, 0.1, 0.06),
      art.height * 0.2,
      kind,
      weight: FontWeight.w800,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          art.left + art.width * 0.1,
          art.bottom - art.height * 0.07,
          art.right - art.width * 0.1,
          art.bottom,
        ),
        Radius.circular(art.height * 0.04),
      ),
      Paint()..color = kind,
    );
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    String? fontFamily,
    String? package,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          fontFamily: fontFamily,
          package: package,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      // Tile art keeps its size whatever the text size of the device.
      textScaler: TextScaler.noScaling,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.face != face ||
      old.faceSize != faceSize ||
      old.depth != depth ||
      old.selected != selected ||
      old.dimmed != dimmed ||
      old.windLetter != windLetter;
}
