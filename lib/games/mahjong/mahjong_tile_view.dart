import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../skins/tile_styles.dart';
import 'mahjong_tiles.dart';

/// The hint's rim and halo, apart from the gold of a selected tile.
const _hintColor = Color(0xFF26C6DA);

/// The inks of the coins and sticks, resolved by the [TileStyle].
enum _Hue { red, green, blue }

const _r = _Hue.red;
const _g = _Hue.green;
const _b = _Hue.blue;

/// A Mahjong tile seen from above, a little from the bottom right: a face
/// in [style], and its thickness (the body, then the back) below and to the
/// right of it. Drawn with vector shapes and Latin letters only: no emoji
/// and no CJK font, which the web does not always have.
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
    required this.style,
    this.selected = false,
    this.dimmed = false,
  });

  final TileFace face;
  final Size faceSize;
  final double depth;
  final TileStyle style;

  /// Picked by the player: a warm face and a golden rim.
  final bool selected;

  /// Blocked: the face is a little darker.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(faceSize.width + depth, faceSize.height + depth),
      painter: _TilePainter(
        face: face,
        faceSize: faceSize,
        depth: depth,
        style: style,
        selected: selected,
        dimmed: dimmed,
        windLetter: switch (face.suit) {
          TileSuit.winds => _windLetter(
            AppLocalizations.of(context),
            face.rank,
          ),
          _ => '',
        },
      ),
    );
  }

  static String _windLetter(AppLocalizations l10n, int rank) => [
    l10n.mahjongWindEastLetter,
    l10n.mahjongWindSouthLetter,
    l10n.mahjongWindWestLetter,
    l10n.mahjongWindNorthLetter,
  ][rank - 1];
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
    required this.style,
    required this.selected,
    required this.dimmed,
    required this.windLetter,
  });

  final TileFace face;
  final Size faceSize;
  final double depth;
  final TileStyle style;
  final bool selected;
  final bool dimmed;
  final String windLetter;

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

    // The thickness: the back, then the body, step by step.
    final steps = max(2, (depth / 1.5).ceil());
    final [back, backTop] = style.backColors;
    final [body, bodyTop] = style.bodyColors;
    for (var i = steps; i > 0; i--) {
      final t = i / steps;
      canvas.drawRRect(
        at(depth * t),
        Paint()
          ..color = t > 0.55
              ? Color.lerp(back, backTop, (1 - t) / 0.45)!
              : Color.lerp(body, bodyTop, 1 - t / 0.55)!,
      );
    }

    final faceRRect = at(0);
    canvas.drawRRect(
      faceRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected ? style.selectedFaceColors : style.faceColors,
        ).createShader(faceRect),
    );
    if (style.rimColor case final rim?) {
      canvas.drawRRect(
        faceRRect.deflate(max(1.5, w * 0.055)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.025)
          ..color = rim,
      );
    }
    canvas.drawRRect(
      faceRRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? max(1.5, w * 0.05) : max(0.8, w * 0.02)
        ..color = selected ? style.selectedEdgeColor : style.edgeColor,
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
      canvas.drawRRect(faceRRect, Paint()..color = style.dimColor);
    }
  }

  TileInk get _ink => style.ink;

  Color _color(_Hue hue) => switch (hue) {
    _Hue.red => _ink.red,
    _Hue.green => _ink.green,
    _Hue.blue => _ink.blue,
  };

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
          _ink.black,
          weight: FontWeight.w900,
        );
      case TileSuit.dragons:
        _paintDragon(canvas, art, face.rank);
      // Any flower matches any flower, and any season any season: one art
      // each, whatever the rank.
      case TileSuit.flowers:
        _paintFlower(canvas, art);
      case TileSuit.seasons:
        _paintSeason(canvas, art);
    }
  }

  /// Point ([x], [y]) of [art], from 0 to 1 on each side.
  static Offset _in(Rect art, double x, double y) =>
      Offset(art.left + art.width * x, art.top + art.height * y);

  static const _dotLayouts = <List<(double, double, _Hue)>>[
    [(0.5, 0.5, _r)],
    [(0.5, 0.26, _g), (0.5, 0.74, _b)],
    [(0.2, 0.18, _b), (0.5, 0.5, _r), (0.8, 0.82, _g)],
    [(0.27, 0.27, _b), (0.73, 0.27, _g), (0.27, 0.73, _g), (0.73, 0.73, _b)],
    [
      (0.24, 0.2, _b),
      (0.76, 0.2, _g),
      (0.5, 0.5, _r),
      (0.24, 0.8, _g),
      (0.76, 0.8, _b),
    ],
    [
      (0.28, 0.17, _g),
      (0.72, 0.17, _g),
      (0.28, 0.5, _r),
      (0.72, 0.5, _r),
      (0.28, 0.83, _r),
      (0.72, 0.83, _r),
    ],
    [
      (0.18, 0.1, _g),
      (0.5, 0.21, _g),
      (0.82, 0.32, _g),
      (0.3, 0.6, _r),
      (0.7, 0.6, _r),
      (0.3, 0.88, _r),
      (0.7, 0.88, _r),
    ],
    [
      (0.28, 0.12, _b),
      (0.72, 0.12, _b),
      (0.28, 0.37, _b),
      (0.72, 0.37, _b),
      (0.28, 0.63, _b),
      (0.72, 0.63, _b),
      (0.28, 0.88, _b),
      (0.72, 0.88, _b),
    ],
    [
      (0.18, 0.17, _b),
      (0.5, 0.17, _b),
      (0.82, 0.17, _b),
      (0.18, 0.5, _r),
      (0.5, 0.5, _r),
      (0.82, 0.5, _r),
      (0.18, 0.83, _g),
      (0.5, 0.83, _g),
      (0.82, 0.83, _g),
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
  void _paintDots(Canvas canvas, Rect art, int rank) {
    final unit = min(art.width, art.height / 1.15);
    final radius = unit * _dotSizes[rank - 1];
    for (final (x, y, hue) in _dotLayouts[rank - 1]) {
      final center = _in(art, x, y);
      if (rank == 1) {
        _coin(canvas, center, radius, _ink.green);
        _coin(canvas, center, radius * 0.62, _ink.red);
        _coin(canvas, center, radius * 0.3, _ink.blue);
      } else {
        _coin(canvas, center, radius, _color(hue));
      }
    }
  }

  void _coin(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..color = _ink.hollow,
    );
    canvas.drawCircle(center, radius * 0.28, Paint()..color = _ink.hollow);
  }

  static const _bambooLayouts = <List<(double, double, _Hue)>>[
    [(0.5, 0.5, _g)],
    [(0.5, 0.27, _g), (0.5, 0.73, _b)],
    [(0.5, 0.27, _g), (0.3, 0.73, _b), (0.7, 0.73, _b)],
    [(0.3, 0.27, _g), (0.7, 0.27, _b), (0.3, 0.73, _b), (0.7, 0.73, _g)],
    [
      (0.22, 0.27, _g),
      (0.78, 0.27, _b),
      (0.5, 0.5, _r),
      (0.22, 0.73, _b),
      (0.78, 0.73, _g),
    ],
    [
      (0.2, 0.27, _g),
      (0.5, 0.27, _g),
      (0.8, 0.27, _g),
      (0.2, 0.73, _b),
      (0.5, 0.73, _b),
      (0.8, 0.73, _b),
    ],
    [
      (0.5, 0.15, _r),
      (0.2, 0.5, _g),
      (0.5, 0.5, _g),
      (0.8, 0.5, _g),
      (0.2, 0.85, _g),
      (0.5, 0.85, _g),
      (0.8, 0.85, _g),
    ],
    [
      (0.14, 0.27, _g),
      (0.38, 0.27, _g),
      (0.62, 0.27, _g),
      (0.86, 0.27, _g),
      (0.14, 0.73, _b),
      (0.38, 0.73, _b),
      (0.62, 0.73, _b),
      (0.86, 0.73, _b),
    ],
    [
      (0.2, 0.17, _g),
      (0.5, 0.17, _r),
      (0.8, 0.17, _b),
      (0.2, 0.5, _g),
      (0.5, 0.5, _r),
      (0.8, 0.5, _b),
      (0.2, 0.83, _g),
      (0.5, 0.83, _r),
      (0.8, 0.83, _b),
    ],
  ];

  /// Sticks with joints. The one of bamboo 1 is big, with leaves.
  void _paintBamboo(Canvas canvas, Rect art, int rank) {
    final rows = rank == 7 || rank == 9 ? 3 : (rank == 1 ? 1 : 2);
    final height = rank == 1 ? art.height * 0.78 : art.height / rows * 0.82;
    final width = rank == 1
        ? art.width * 0.24
        : min(art.width * (rank == 8 ? 0.15 : 0.18), height * 0.42);
    for (final (x, y, hue) in _bambooLayouts[rank - 1]) {
      _stick(canvas, _in(art, x, y), width, height, _color(hue));
    }
    if (rank == 1) {
      final leaf = Paint()..color = _ink.green;
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

  void _stick(
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
      ..color = _ink.hollow.withValues(alpha: 0.8)
      ..strokeWidth = max(0.8, height * 0.05);
    for (final t in [0.5]) {
      final y = rect.top + rect.height * t;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), joint);
    }
  }

  /// A red numeral over a mark drawn after the character "wan" (萬): grass,
  /// a field with a cross, then a frame with a hook around a bent stroke.
  void _paintCharacter(Canvas canvas, Rect art, int rank) {
    _paintText(
      canvas,
      '$rank',
      _in(art, 0.5, 0.2),
      art.height * 0.42,
      _ink.red,
      weight: FontWeight.w900,
    );
    final size = min(art.width * 0.86, art.height * 0.52);
    final mark = Rect.fromCenter(
      center: _in(art, 0.5, 0.72),
      width: size,
      height: size,
    );
    Path strokes(List<List<(double, double)>> lines) {
      final path = Path();
      for (final line in lines) {
        final (x, y) = line.first;
        path.moveTo(mark.left + mark.width * x, mark.top + mark.height * y);
        for (final (x, y) in line.skip(1)) {
          path.lineTo(mark.left + mark.width * x, mark.top + mark.height * y);
        }
      }
      return path;
    }

    Paint pen(double width) => Paint()
      ..color = _ink.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Thin across and thick down, as in a printed character: the gaps
    // between the many rows stay open on small tiles.
    canvas.drawPath(strokes(_wanAcross), pen(max(0.8, size * 0.065)));
    canvas.drawPath(strokes(_wanDown), pen(max(1.1, size * 0.095)));
  }

  /// The strokes of the "wan" mark in a unit square.
  static const _wanAcross = [
    [(0.04, 0.12), (0.96, 0.12)],
    [(0.2, 0.29), (0.8, 0.29)],
    [(0.2, 0.41), (0.8, 0.41)],
    [(0.2, 0.53), (0.8, 0.53)],
    [(0.08, 0.65), (0.92, 0.65)],
    [(0.32, 0.9), (0.72, 0.88)],
  ];
  static const _wanDown = [
    [(0.32, 0.0), (0.32, 0.22)],
    [(0.68, 0.0), (0.68, 0.22)],
    [(0.2, 0.29), (0.2, 0.53)],
    [(0.8, 0.29), (0.8, 0.53)],
    [(0.5, 0.29), (0.5, 0.73), (0.32, 0.9)],
    [(0.08, 0.65), (0.08, 1.0)],
    [(0.92, 0.65), (0.92, 0.97), (0.83, 0.92)],
    [(0.62, 0.77), (0.7, 0.85)],
  ];

  /// Red: a box with a stroke through it. Green: a leaf in a ring. White: a
  /// blue frame.
  void _paintDragon(Canvas canvas, Rect art, int rank) {
    final unit = art.width;
    switch (rank) {
      case 1:
        final stroke = Paint()
          ..color = _ink.red
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
            ..color = _ink.green
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
        canvas.drawPath(leaf, Paint()..color = _ink.green);
        canvas.drawLine(
          top.translate(0, radius * 0.2),
          bottom.translate(0, -radius * 0.2),
          Paint()
            ..color = _ink.hollow
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
          ..color = _ink.blue
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

  /// A plum twig: a big blossom, and a small one on a side twig.
  void _paintFlower(Canvas canvas, Rect art) {
    final unit = min(art.width, art.height / 1.3);
    final twig = Paint()..color = _ink.twig;
    final center = _in(art, 0.56, 0.36);
    final foot = _in(art, 0.06, 1.02);
    final bend = _in(art, 0.24, 0.62);
    canvas.drawPath(_twig(foot, bend, center, unit * 0.13), twig);
    final small = _in(art, 0.78, 0.82);
    canvas.drawPath(
      _twig(
        _bezier(foot, bend, center, 0.3),
        _in(art, 0.5, 0.88),
        small,
        unit * 0.07,
      ),
      twig,
    );
    _blossom(canvas, small, unit * 0.19, stamens: false);
    _blossom(canvas, center, unit * 0.38);
  }

  /// Point [t] of the curve from [a] to [b] pulled towards [c].
  static Offset _bezier(Offset a, Offset c, Offset b, double t) =>
      a * ((1 - t) * (1 - t)) + c * (2 * t * (1 - t)) + b * (t * t);

  /// A twig along a curve from [from] to [to], [width] wide at [from] and
  /// thinner and thinner.
  static Path _twig(Offset from, Offset control, Offset to, double width) {
    const steps = 12;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final at = _bezier(from, control, to, t);
      final tangent = (control - from) * (1 - t) + (to - control) * t;
      final normal = Offset(-tangent.dy, tangent.dx) / tangent.distance;
      final half = max(0.5, width * (1 - 0.6 * t) / 2);
      left.add(at + normal * half);
      right.add(at - normal * half);
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// Five round petals around a heart.
  void _blossom(
    Canvas canvas,
    Offset center,
    double radius, {
    bool stamens = true,
  }) {
    var petals = Path();
    for (var i = 0; i < 5; i++) {
      final at =
          center +
          Offset.fromDirection(-pi / 2 + i * 2 * pi / 5, radius * 0.56);
      petals = Path.combine(
        PathOperation.union,
        petals,
        Path()..addOval(Rect.fromCircle(center: at, radius: radius * 0.44)),
      );
    }
    canvas.drawPath(
      petals,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(_ink.petal, Colors.white, 0.55)!, _ink.petal],
          stops: const [0.2, 0.8],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      petals,
      Paint()
        ..color = _ink.petalEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, radius * 0.07)
        ..strokeJoin = StrokeJoin.round,
    );
    if (stamens) {
      final stamen = Paint()
        ..color = _ink.petalEdge
        ..strokeWidth = max(0.5, radius * 0.035)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 10; i++) {
        final tip = center + Offset.fromDirection(i * pi / 5, radius * 0.4);
        canvas.drawLine(center, tip, stamen);
        canvas.drawCircle(tip, radius * 0.055, Paint()..color = _ink.heart);
      }
    }
    canvas.drawCircle(center, radius * 0.2, Paint()..color = _ink.heart);
  }

  /// A sun: a disc in a ring of long and short rays.
  void _paintSeason(Canvas canvas, Rect art) {
    final center = art.center;
    final radius = min(art.width, art.height) * 0.48;
    final disc = radius * 0.5;
    final rays = Path();
    for (var i = 0; i < 12; i++) {
      final angle = -pi / 2 + i * pi / 6;
      final base = disc * 1.25;
      final tip =
          center + Offset.fromDirection(angle, radius * (i.isEven ? 1 : 0.8));
      final left = center + Offset.fromDirection(angle - pi / 12, base);
      final right = center + Offset.fromDirection(angle + pi / 12, base);
      rays
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
    }
    canvas.drawPath(rays, Paint()..color = _ink.sunRays);
    canvas.drawCircle(
      center,
      disc,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(_ink.sun, Colors.white, 0.5)!, _ink.sun],
        ).createShader(Rect.fromCircle(center: center, radius: disc)),
    );
    canvas.drawCircle(
      center,
      disc,
      Paint()
        ..color = _ink.sunRays
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, disc * 0.14),
    );
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
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
      old.style != style ||
      old.selected != selected ||
      old.dimmed != dimmed ||
      old.windLetter != windLetter;
}
