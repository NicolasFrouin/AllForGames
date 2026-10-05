import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../cards/deal_random.dart';

enum CardBackPattern {
  none,
  stripes,
  lattice,
  waves,
  rays,
  stars,
  dots,
  rings,
  chevrons,
  grid,
  circuit,
  maze,
  engraved,
  ripples,
  bolts,
  web,
  moon,
  scales,
  sheen,
  rivets,
  honeycomb,
  bands,
  guilloche,
  nebula,
}

/// The look of the face-down cards.
class CardBackSkin {
  const CardBackSkin({
    required this.id,
    required this.colors,
    this.pattern = CardBackPattern.none,
    this.patternColor = const Color(0x33FFFFFF),
    this.borderColor = const Color(0x66FFFFFF),
    this.accentColor = const Color(0xFFFFFFFF),
    this.emblem,
    this.unlockedBy,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  });

  final String id;

  /// Background gradient, from [gradientBegin] to [gradientEnd].
  final List<Color> colors;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final CardBackPattern pattern;

  /// Color of the pattern and of the [emblem].
  final Color patternColor;

  /// Color of the thin inner border.
  final Color borderColor;

  /// Second color of some patterns (pads, bolts, moon, planet...).
  final Color accentColor;

  /// Icon in the middle of the card, if any.
  final IconData? emblem;

  /// Id of the achievement that unlocks this skin, null when it is free.
  final String? unlockedBy;
}

const classicCardBack = CardBackSkin(
  id: 'classic',
  colors: [Color(0xFF283593), Color(0xFF1A237E), Color(0xFF3949AB)],
  patternColor: Color(0x55FFFFFF),
  emblem: Icons.diamond_outlined,
);

const cardBacks = [
  classicCardBack,
  CardBackSkin(
    id: 'crimson',
    colors: [Color(0xFFD32F2F), Color(0xFF8E0000), Color(0xFFC62828)],
    pattern: CardBackPattern.stripes,
    patternColor: Color(0x24FFFFFF),
    unlockedBy: 'klondike.firstWin',
  ),
  CardBackSkin(
    id: 'emerald',
    colors: [Color(0xFF2E7D32), Color(0xFF0D3B12), Color(0xFF388E3C)],
    pattern: CardBackPattern.lattice,
    patternColor: Color(0x3DFFFFFF),
    unlockedBy: 'klondike.wins10',
  ),
  CardBackSkin(
    id: 'ocean',
    colors: [Color(0xFF0097A7), Color(0xFF005F66), Color(0xFF00838F)],
    pattern: CardBackPattern.waves,
    patternColor: Color(0x40FFFFFF),
    unlockedBy: 'klondike.draw3Win',
  ),
  CardBackSkin(
    id: 'sunset',
    colors: [Color(0xFFFFA726), Color(0xFFF4511E), Color(0xFFC2185B)],
    pattern: CardBackPattern.rays,
    patternColor: Color(0x2EFFFFFF),
    borderColor: Color(0x80FFFFFF),
    unlockedBy: 'klondike.fastWin',
  ),
  CardBackSkin(
    id: 'midnight',
    colors: [Color(0xFF1F2A44), Color(0xFF0A0E1A), Color(0xFF2B3A5C)],
    pattern: CardBackPattern.stars,
    patternColor: Color(0xCCFFF1CC),
    borderColor: Color(0x4DFFFFFF),
    unlockedBy: 'klondike.noUndoWin',
  ),
  CardBackSkin(
    id: 'royal',
    colors: [Color(0xFF7B1FA2), Color(0xFF4A148C), Color(0xFF6A1B9A)],
    pattern: CardBackPattern.dots,
    patternColor: Color(0x80FFD54F),
    borderColor: Color(0xB3FFD54F),
    unlockedBy: 'klondike.streak3',
  ),
  CardBackSkin(
    id: 'gold',
    colors: [
      Color(0xFFFFE082),
      Color(0xFFD4A017),
      Color(0xFFFFE9A8),
      Color(0xFFB8860B),
    ],
    pattern: CardBackPattern.rings,
    patternColor: Color(0x5C6D4C00),
    borderColor: Color(0x996D4C00),
    emblem: Icons.star_rounded,
    unlockedBy: 'klondike.wins50',
  ),
  CardBackSkin(
    id: 'obsidian',
    colors: [Color(0xFF3B3E44), Color(0xFF141518), Color(0xFF2C2F34)],
    pattern: CardBackPattern.chevrons,
    patternColor: Color(0x8CC8CDD4),
    borderColor: Color(0xB3D9DDE3),
    unlockedBy: 'klondike.hardWin',
  ),
  CardBackSkin(
    id: 'azure',
    colors: [Color(0xFF8FD8FF), Color(0xFF2A9FE0), Color(0xFF0B6FB8)],
    pattern: CardBackPattern.grid,
    patternColor: Color(0x5CFFFFFF),
    borderColor: Color(0x99FFFFFF),
    unlockedBy: 'freecell.firstWin',
  ),
  CardBackSkin(
    id: 'circuit',
    colors: [Color(0xFF0B4F4A), Color(0xFF032623), Color(0xFF0A3D39)],
    pattern: CardBackPattern.circuit,
    patternColor: Color(0x9952E0C4),
    borderColor: Color(0x8052E0C4),
    accentColor: Color(0xFFB2FFF0),
    unlockedBy: 'freecell.wins10',
  ),
  CardBackSkin(
    id: 'labyrinth',
    colors: [Color(0xFF9A9CA1), Color(0xFF5E6166), Color(0xFF85888D)],
    pattern: CardBackPattern.maze,
    patternColor: Color(0xE6E9E6DF),
    borderColor: Color(0x99F2EFE8),
    accentColor: Color(0xFFFFC107),
    unlockedBy: 'freecell.hardWin',
  ),
  CardBackSkin(
    id: 'ivory',
    colors: [Color(0xFFFFFAEE), Color(0xFFEFE2C4), Color(0xFFFAF1DC)],
    pattern: CardBackPattern.engraved,
    patternColor: Color(0xFF9A7B4F),
    borderColor: Color(0xFF9A7B4F),
    accentColor: Color(0xFF9E1B32),
    unlockedBy: 'freecell.noUndoWin',
  ),
  CardBackSkin(
    id: 'zen',
    colors: [Color(0xFFEFE3C6), Color(0xFFD9C79F), Color(0xFFE6D6B2)],
    pattern: CardBackPattern.ripples,
    patternColor: Color(0x66957A4A),
    borderColor: Color(0x80957A4A),
    accentColor: Color(0xFF6E6A64),
    unlockedBy: 'freecell.oneCellWin',
  ),
  CardBackSkin(
    id: 'lightning',
    colors: [Color(0xFF15204A), Color(0xFF070B1F), Color(0xFF1B2A5E)],
    pattern: CardBackPattern.bolts,
    patternColor: Color(0x38FFD740),
    borderColor: Color(0x99FFD740),
    accentColor: Color(0xFFFFD740),
    unlockedBy: 'freecell.fastWin',
  ),
  CardBackSkin(
    id: 'web',
    colors: [Color(0xFF26262B), Color(0xFF0B0B0D), Color(0xFF1C1C21)],
    pattern: CardBackPattern.web,
    patternColor: Color(0xB3D5D9E0),
    borderColor: Color(0x66D5D9E0),
    accentColor: Color(0xFFB71C1C),
    unlockedBy: 'spider.firstWin',
  ),
  CardBackSkin(
    id: 'twilight',
    colors: [
      Color(0xFF241046),
      Color(0xFF5B2A86),
      Color(0xFFC2507A),
      Color(0xFFFF9A4D),
    ],
    gradientBegin: Alignment.topCenter,
    gradientEnd: Alignment.bottomCenter,
    pattern: CardBackPattern.moon,
    patternColor: Color(0xFF1A0A2E),
    borderColor: Color(0x80FFE9C2),
    accentColor: Color(0xFFFFF0C8),
    unlockedBy: 'spider.twoSuitsWin',
  ),
  CardBackSkin(
    id: 'venom',
    colors: [Color(0xFF12301A), Color(0xFF030805), Color(0xFF0E2614)],
    pattern: CardBackPattern.scales,
    patternColor: Color(0xFF76FF03),
    borderColor: Color(0x8076FF03),
    accentColor: Color(0xFFB2FF59),
    unlockedBy: 'spider.fourSuitsWin',
  ),
  CardBackSkin(
    id: 'silk',
    colors: [Color(0xFFF8EAD2), Color(0xFFDDBF94), Color(0xFFF1DCBC)],
    pattern: CardBackPattern.sheen,
    patternColor: Color(0x8CFFFFFF),
    borderColor: Color(0xB3FFFFFF),
    accentColor: Color(0x33704B1C),
    unlockedBy: 'spider.wins10',
  ),
  CardBackSkin(
    id: 'steel',
    colors: [
      Color(0xFFDDE1E6),
      Color(0xFF8C939B),
      Color(0xFFC7CDD3),
      Color(0xFF6E767E),
    ],
    pattern: CardBackPattern.rivets,
    patternColor: Color(0x26FFFFFF),
    borderColor: Color(0x80FFFFFF),
    accentColor: Color(0x1F000000),
    unlockedBy: 'spider.noUndoWin',
  ),
  CardBackSkin(
    id: 'amber',
    colors: [Color(0xFFFFB627), Color(0xFFD47800), Color(0xFFF29A12)],
    pattern: CardBackPattern.honeycomb,
    patternColor: Color(0x99733A00),
    borderColor: Color(0x99FFF1C4),
    accentColor: Color(0x66FFE7A3),
    unlockedBy: 'spider.streak3',
  ),
  CardBackSkin(
    id: 'prism',
    colors: [Color(0xFF2B2B31), Color(0xFF111114), Color(0xFF26262C)],
    pattern: CardBackPattern.bands,
    patternColor: Color(0x80FFFFFF),
    borderColor: Color(0xCCFFFFFF),
    unlockedBy: 'all.everyGame',
  ),
  CardBackSkin(
    id: 'platinum',
    colors: [Color(0xFFF7F8FA), Color(0xFFCDD3DA), Color(0xFFEEF1F4)],
    pattern: CardBackPattern.guilloche,
    patternColor: Color(0x99657384),
    borderColor: Color(0x99657384),
    accentColor: Color(0xFF8A96A6),
    unlockedBy: 'all.wins100',
  ),
  CardBackSkin(
    id: 'cosmos',
    colors: [Color(0xFF1A0F3A), Color(0xFF05030F), Color(0xFF130B2E)],
    pattern: CardBackPattern.nebula,
    patternColor: Color(0xE6FFFFFF),
    borderColor: Color(0x66C8B8FF),
    accentColor: Color(0xFFFFC77D),
    unlockedBy: 'all.hours10',
  ),
];

/// The skin with [id], or [classicCardBack] when there is none (for example a
/// skin saved by a newer app version).
CardBackSkin cardBackById(String id) => cardBacks.firstWhere(
  (skin) => skin.id == id,
  orElse: () => classicCardBack,
);

/// The back of a face-down card [width] pixels wide. It fills its parent,
/// which is `width x width * 1.4`.
class CardBackView extends StatelessWidget {
  const CardBackView({super.key, required this.skin, required this.width});

  final CardBackSkin skin;
  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.1),
        gradient: LinearGradient(
          begin: skin.gradientBegin,
          end: skin.gradientEnd,
          colors: skin.colors,
        ),
      ),
      child: CustomPaint(
        painter: _PatternPainter(skin, width),
        child: Padding(
          padding: EdgeInsets.all(width * 0.07),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: skin.borderColor, width: 1),
              borderRadius: BorderRadius.circular(width * 0.06),
            ),
            child: Center(
              child: skin.emblem == null
                  ? null
                  : Icon(
                      skin.emblem,
                      color: skin.patternColor,
                      size: width * 0.4,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws [CardBackSkin.pattern] inside the inner border, in proportion to the
/// card width, so a back looks the same at every card size.
class _PatternPainter extends CustomPainter {
  _PatternPainter(this.skin, this.width);

  final CardBackSkin skin;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (skin.pattern == CardBackPattern.none) return;
    final inner = (Offset.zero & size).deflate(width * 0.07);
    canvas.clipRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(width * 0.06)),
    );
    final stroke = Paint()
      ..color = skin.patternColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, width * 0.02);
    final fill = Paint()..color = skin.patternColor;
    switch (skin.pattern) {
      case CardBackPattern.none:
        break;
      case CardBackPattern.stripes:
        _stripes(canvas, size, stroke);
      case CardBackPattern.lattice:
        _lattice(canvas, size, stroke, fill);
      case CardBackPattern.waves:
        _waves(canvas, size, stroke);
      case CardBackPattern.rays:
        _rays(canvas, size, fill);
      case CardBackPattern.stars:
        _stars(canvas, inner, fill);
      case CardBackPattern.dots:
        _dots(canvas, inner, fill);
      case CardBackPattern.rings:
        _rings(canvas, size, stroke);
      case CardBackPattern.chevrons:
        _chevrons(canvas, size, stroke);
      case CardBackPattern.grid:
        _grid(canvas, inner, stroke);
      case CardBackPattern.circuit:
        _circuit(canvas, inner, stroke);
      case CardBackPattern.maze:
        _maze(canvas, inner, stroke);
      case CardBackPattern.engraved:
        _engraved(canvas, inner, stroke, fill);
      case CardBackPattern.ripples:
        _ripples(canvas, inner, stroke);
      case CardBackPattern.bolts:
        _bolts(canvas, inner, fill);
      case CardBackPattern.web:
        _web(canvas, inner, stroke, fill);
      case CardBackPattern.moon:
        _moon(canvas, inner, fill);
      case CardBackPattern.scales:
        _scales(canvas, inner, stroke);
      case CardBackPattern.sheen:
        _sheen(canvas, inner);
      case CardBackPattern.rivets:
        _rivets(canvas, inner, stroke);
      case CardBackPattern.honeycomb:
        _honeycomb(canvas, inner, stroke);
      case CardBackPattern.bands:
        _bands(canvas, inner, stroke);
      case CardBackPattern.guilloche:
        _guilloche(canvas, inner, stroke);
      case CardBackPattern.nebula:
        _nebula(canvas, inner, fill);
    }
  }

  void _stripes(Canvas canvas, Size size, Paint paint) {
    final step = width / 7;
    paint.strokeWidth = step * 0.4;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  /// Diamonds with the card proportions, and a dot in each one.
  void _lattice(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final cellWidth = width / 4;
    final cellHeight = cellWidth * 1.4;
    final run = size.height * cellWidth / cellHeight;
    for (var x = -run; x < size.width + run; x += cellWidth) {
      canvas
        ..drawLine(Offset(x, 0), Offset(x + run, size.height), stroke)
        ..drawLine(Offset(x, 0), Offset(x - run, size.height), stroke);
    }
    final dot = width * 0.022;
    for (var row = 0; row * cellHeight / 2 <= size.height; row++) {
      for (
        var col = row.isEven ? 1 : 0;
        col * cellWidth / 2 <= size.width;
        col += 2
      ) {
        canvas.drawCircle(
          Offset(col * cellWidth / 2, row * cellHeight / 2),
          dot,
          fill,
        );
      }
    }
  }

  void _waves(Canvas canvas, Size size, Paint paint) {
    final step = width / 6;
    final length = width / 4;
    final amplitude = width / 18;
    for (var y = step / 2; y < size.height + step; y += step) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += length) {
        path
          ..quadraticBezierTo(x + length / 4, y - amplitude, x + length / 2, y)
          ..quadraticBezierTo(x + length * 3 / 4, y + amplitude, x + length, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// A sunburst of wedges from the middle of the card.
  void _rays(Canvas canvas, Size size, Paint paint) {
    const count = 16;
    final center = size.center(Offset.zero);
    final reach = size.longestSide;
    for (var i = 0; i < count; i++) {
      final start = i * 2 * pi / count;
      final end = start + pi / count;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + reach * cos(start),
            center.dy + reach * sin(start),
          )
          ..lineTo(center.dx + reach * cos(end), center.dy + reach * sin(end))
          ..close(),
        paint,
      );
    }
  }

  /// A night sky: stars of two sizes.
  void _stars(Canvas canvas, Rect inner, Paint paint) {
    final big = width * 0.07;
    _staggered(inner.deflate(big * 1.3), inner.width / 3, (point, index) {
      final radius = index % 3 == 0 ? big : width * 0.04;
      canvas.drawPath(_star(point, radius), paint);
    });
  }

  static Path _star(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final angle = -pi / 2 + i * pi / 5;
      final point = center + Offset(r * cos(angle), r * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _dots(Canvas canvas, Rect inner, Paint paint) {
    final radius = width * 0.028;
    _staggered(
      inner.deflate(radius * 1.8),
      inner.width / 5,
      (point, _) => canvas.drawCircle(point, radius, paint),
    );
  }

  /// Calls [draw] at the points of a staggered grid centered in [area], and
  /// only inside it, so no shape is cut by the border. Rows are [step] / 2
  /// apart and every other row is shifted by half a step.
  static void _staggered(
    Rect area,
    double step,
    void Function(Offset point, int index) draw,
  ) {
    final rows = (area.height / step).ceil();
    final cols = (area.width / step).ceil();
    for (var row = -rows; row <= rows; row++) {
      for (var col = -cols; col <= cols; col++) {
        final shift = row.isOdd ? 0.5 : 0;
        final point =
            area.center + Offset((col + shift) * step, row * step / 2);
        if (area.contains(point)) draw(point, row + col);
      }
    }
  }

  void _rings(Canvas canvas, Size size, Paint paint) {
    final center = size.center(Offset.zero);
    final step = width / 11;
    final reach = size.longestSide;
    for (var radius = step * 3.5; radius < reach; radius += step) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  /// Rows of chevrons, as in a herringbone weave, centered on the card.
  void _chevrons(Canvas canvas, Size size, Paint paint) {
    final step = width / 4;
    final rise = step / 2;
    final gap = width / 5;
    paint.strokeJoin = StrokeJoin.miter;
    final left = size.width / 2 % step - step;
    for (var y = size.height / 2 % gap - gap; y < size.height; y += gap) {
      final path = Path()..moveTo(left, y);
      for (var x = left; x < size.width; x += step) {
        path
          ..lineTo(x + step / 2, y + rise)
          ..lineTo(x + step, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// A thin line, at least [minimum] pixels wide.
  double _hairline(double ratio, [double minimum = 0.6]) =>
      max(minimum, width * ratio);

  /// A fine diagonal grid under a soft glow, like a clear sky.
  void _grid(Canvas canvas, Rect inner, Paint stroke) {
    final center = inner.center;
    final half = inner.height / 2;
    final step = width / 9;
    final count = ((inner.width / 2 + half) / step).ceil();
    final path = Path();
    for (var i = -count; i <= count; i++) {
      final x = center.dx + i * step;
      path
        ..moveTo(x - half, inner.top)
        ..lineTo(x + half, inner.bottom)
        ..moveTo(x + half, inner.top)
        ..lineTo(x - half, inner.bottom);
    }
    canvas.drawPath(path, stroke..strokeWidth = _hairline(0.009));
    canvas.drawRect(
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.6),
          radius: 0.9,
          colors: const [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(inner),
    );
  }

  /// Traces of one quarter of [_circuit], in tenths of the inner width from
  /// the middle of the card; each one ends on a pad.
  static const _traces = [
    [
      Offset(0.5, -1.7),
      Offset(0.5, -3.2),
      Offset(1.6, -4.3),
      Offset(1.6, -5.9),
    ],
    [Offset(1.2, -1.7), Offset(1.2, -2.6), Offset(3.2, -4.6)],
    [
      Offset(1.7, -0.5),
      Offset(2.9, -0.5),
      Offset(3.9, -1.5),
      Offset(3.9, -3.1),
    ],
    [Offset(1.7, -1.2), Offset(2.4, -1.2), Offset(2.4, -2.4)],
    [Offset(0, -1.7), Offset(0, -6.4)],
    [Offset(1.7, 0), Offset(4.1, 0)],
  ];

  /// Vias of one quarter of [_circuit], as [_traces].
  static const _vias = [
    Offset(3.2, -6.2),
    Offset(4.1, -4.9),
    Offset(0.8, -6.3),
  ];

  /// A chip in the middle, its traces running out to pads, mirrored to the
  /// four quarters of the card.
  void _circuit(Canvas canvas, Rect inner, Paint stroke) {
    final unit = inner.width / 10;
    final center = inner.center;
    final traces = Path();
    final pads = Path();
    final holes = Path();
    for (final (sx, sy) in const [(1, 1), (-1, 1), (1, -1), (-1, -1)]) {
      Offset at(Offset point) =>
          center + Offset(point.dx * sx * unit, point.dy * sy * unit);
      for (final trace in _traces) {
        final start = at(trace.first);
        traces.moveTo(start.dx, start.dy);
        for (final point in trace.skip(1)) {
          final end = at(point);
          traces.lineTo(end.dx, end.dy);
        }
        final end = at(trace.last);
        pads.addOval(Rect.fromCircle(center: end, radius: unit * 0.42));
        holes.addOval(Rect.fromCircle(center: end, radius: unit * 0.17));
      }
      for (final via in _vias) {
        pads.addOval(Rect.fromCircle(center: at(via), radius: unit * 0.3));
        holes.addOval(Rect.fromCircle(center: at(via), radius: unit * 0.12));
      }
    }
    stroke
      ..strokeWidth = max(0.8, unit * 0.26)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(traces, stroke)
      ..drawPath(pads, Paint()..color = skin.accentColor)
      ..drawPath(holes, Paint()..color = skin.colors[1]);
    final chip = RRect.fromRectAndRadius(
      Rect.fromCircle(center: center, radius: unit * 1.7),
      Radius.circular(unit * 0.3),
    );
    canvas
      ..drawRRect(chip, Paint()..color = skin.colors[1])
      ..drawRRect(chip, stroke..strokeWidth = max(0.8, unit * 0.2))
      ..drawCircle(
        center + Offset(-unit, -unit),
        unit * 0.22,
        Paint()..color = skin.accentColor,
      )
      ..drawRRect(
        chip.deflate(unit * 0.55),
        stroke..strokeWidth = max(0.6, unit * 0.1),
      );
  }

  static const _mazeColumns = 7;
  static const _mazeRows = 10;

  /// The walls of a maze of 7 x 10 cells, built once: each wall goes from a
  /// corner of the grid to the next one.
  static final List<(Offset, Offset)> _mazeWalls = _buildMaze();

  static List<(Offset, Offset)> _buildMaze() {
    const columns = _mazeColumns;
    const rows = _mazeRows;
    final random = DealRandom(2026);
    // Open passages to the east and to the south of each cell.
    final east = List.filled(columns * rows, false);
    final south = List.filled(columns * rows, false);
    final visited = List.filled(columns * rows, false);
    final stack = [0];
    visited[0] = true;
    while (stack.isNotEmpty) {
      final cell = stack.last;
      final (x, y) = (cell % columns, cell ~/ columns);
      final next = [
        if (x > 0 && !visited[cell - 1]) cell - 1,
        if (x < columns - 1 && !visited[cell + 1]) cell + 1,
        if (y > 0 && !visited[cell - columns]) cell - columns,
        if (y < rows - 1 && !visited[cell + columns]) cell + columns,
      ];
      if (next.isEmpty) {
        stack.removeLast();
        continue;
      }
      final to = next[random.nextInt(next.length)];
      switch (to - cell) {
        case 1:
          east[cell] = true;
        case -1:
          east[to] = true;
        case columns:
          south[cell] = true;
        default:
          south[to] = true;
      }
      visited[to] = true;
      stack.add(to);
    }
    // The way in and out, in the middle of the top and bottom walls.
    const door = columns ~/ 2;
    return [
      for (var x = 0; x < columns; x++)
        if (x != door) (Offset(x.toDouble(), 0), Offset(x + 1.0, 0)),
      for (var y = 0; y < rows; y++)
        (Offset(0, y.toDouble()), Offset(0, y + 1.0)),
      // No passage leaves the grid: the last column and row get their outer
      // walls here.
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < columns; x++) ...[
          if (!east[y * columns + x])
            (Offset(x + 1.0, y.toDouble()), Offset(x + 1.0, y + 1.0)),
          if (!south[y * columns + x] && (y < rows - 1 || x != door))
            (Offset(x.toDouble(), y + 1.0), Offset(x + 1.0, y + 1.0)),
        ],
    ];
  }

  /// A maze carved in stone, with a gem at its heart.
  void _maze(Canvas canvas, Rect inner, Paint stroke) {
    final area = inner.deflate(width * 0.06);
    final cell = min(area.width / _mazeColumns, area.height / _mazeRows);
    final origin =
        area.center - Offset(_mazeColumns * cell / 2, _mazeRows * cell / 2);
    final walls = Path();
    for (final (from, to) in _mazeWalls) {
      final start = origin + from * cell;
      final end = origin + to * cell;
      walls
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy);
    }
    stroke
      ..strokeWidth = cell * 0.3
      ..strokeCap = StrokeCap.square;
    final shadow = Offset(cell * 0.09, cell * 0.11);
    canvas
      ..drawPath(
        walls.shift(shadow),
        Paint()
          ..color = const Color(0x59000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.strokeWidth
          ..strokeCap = StrokeCap.square,
      )
      ..drawPath(walls, stroke);
    canvas.drawPath(
      _diamond(
        origin + Offset(3.5 * cell, 4.5 * cell),
        cell * 0.24,
        cell * 0.3,
      ),
      Paint()..color = skin.accentColor,
    );
  }

  /// A casino back: an engraved double frame with corner diamonds and a
  /// medallion in the middle.
  void _engraved(Canvas canvas, Rect inner, Paint stroke, Paint fill) {
    final hatch = Path();
    final step = width / 22;
    for (var x = inner.left - inner.height; x < inner.right; x += step) {
      hatch
        ..moveTo(x, inner.bottom)
        ..lineTo(x + inner.height, inner.top);
    }
    canvas.drawPath(
      hatch,
      Paint()
        ..color = skin.patternColor.withAlpha(0x1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hairline(0.006, 0.5),
    );
    final outer = inner.deflate(width * 0.04);
    final innerFrame = inner.deflate(width * 0.07);
    final radius = Radius.circular(width * 0.04);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(outer, radius),
        stroke..strokeWidth = _hairline(0.02, 1),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(innerFrame, radius),
        Paint()
          ..color = skin.patternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _hairline(0.007, 0.5),
      );
    final accent = Paint()..color = skin.accentColor;
    final corner = width * 0.045;
    for (final point in [
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      canvas.drawPath(_diamond(point, corner * 0.8, corner), accent);
    }
    final center = inner.center;
    final ring = width * 0.2;
    canvas
      ..drawCircle(center, ring, Paint()..color = skin.colors.first)
      ..drawCircle(center, ring, stroke..strokeWidth = _hairline(0.016, 1))
      ..drawCircle(
        center,
        ring * 0.84,
        Paint()
          ..color = skin.patternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _hairline(0.006, 0.5),
      )
      ..drawPath(_diamond(center, ring * 0.46, ring * 0.62), accent);
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      canvas.drawCircle(
        center + Offset(cos(angle), sin(angle)) * ring * 1.22,
        width * 0.014,
        fill,
      );
    }
  }

  static Path _diamond(Offset center, double halfWidth, double halfHeight) =>
      Path()
        ..moveTo(center.dx, center.dy - halfHeight)
        ..lineTo(center.dx + halfWidth, center.dy)
        ..lineTo(center.dx, center.dy + halfHeight)
        ..lineTo(center.dx - halfWidth, center.dy)
        ..close();

  /// A raked sand garden: lines around two stones, ringed by ripples.
  void _ripples(Canvas canvas, Rect inner, Paint stroke) {
    final gap = width / 15;
    final stones = [
      (
        inner.topLeft + Offset(inner.width * 0.36, inner.height * 0.62),
        width * 0.1,
        4,
      ),
      (
        inner.topLeft + Offset(inner.width * 0.74, inner.height * 0.22),
        width * 0.055,
        3,
      ),
    ];
    final grooves = Path();
    final rakedArea = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(inner);
    for (final (center, radius, rings) in stones) {
      for (var ring = 1; ring <= rings; ring++) {
        grooves.addOval(
          Rect.fromCircle(center: center, radius: radius + ring * gap),
        );
      }
      rakedArea.addOval(
        Rect.fromCircle(center: center, radius: radius + (rings + 0.5) * gap),
      );
    }
    final lines = Path();
    for (var y = inner.top + gap / 2; y < inner.bottom; y += gap) {
      lines
        ..moveTo(inner.left, y)
        ..lineTo(inner.right, y);
    }
    final lineWidth = _hairline(0.012, 0.8);
    final light = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    stroke.strokeWidth = lineWidth;
    final shift = Offset(0, lineWidth * 0.9);
    canvas
      ..drawPath(grooves.shift(shift), light)
      ..drawPath(grooves, stroke)
      ..save()
      ..clipPath(rakedArea)
      ..drawPath(lines.shift(shift), light)
      ..drawPath(lines, stroke)
      ..restore();
    for (final (center, radius, _) in stones) {
      final rock = Rect.fromCenter(
        center: center,
        width: radius * 2.3,
        height: radius * 1.8,
      );
      canvas
        ..drawOval(
          rock.shift(Offset(radius * 0.15, radius * 0.25)),
          Paint()..color = const Color(0x40000000),
        )
        ..drawOval(
          rock,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.5),
              colors: [
                Color.lerp(skin.accentColor, const Color(0xFFFFFFFF), 0.35)!,
                skin.accentColor,
                Color.lerp(skin.accentColor, const Color(0xFF000000), 0.35)!,
              ],
            ).createShader(rock),
        );
    }
  }

  /// A lightning bolt one unit tall, centered on the origin.
  static const _bolt = [
    Offset(0.06, -0.5),
    Offset(0.3, -0.5),
    Offset(0.08, -0.1),
    Offset(0.26, -0.1),
    Offset(-0.2, 0.5),
    Offset(-0.03, 0.04),
    Offset(-0.22, 0.04),
  ];

  static Path _boltPath(Offset center, double height, [double tilt = 0]) {
    final path = Path();
    for (final (i, point) in _bolt.indexed) {
      final turned = Offset(
        point.dx * cos(tilt) - point.dy * sin(tilt),
        point.dx * sin(tilt) + point.dy * cos(tilt),
      );
      final at = center + turned * height;
      i == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    return path..close();
  }

  /// A big glowing bolt in a storm of small ones.
  void _bolts(Canvas canvas, Rect inner, Paint fill) {
    final center = inner.center;
    final small = Path();
    _staggered(inner.deflate(width * 0.06), inner.width / 2.6, (point, index) {
      if ((point - center).distance < width * 0.42) return;
      small.addPath(
        _boltPath(point, width * 0.17, index.isEven ? 0.25 : -0.15),
        Offset.zero,
      );
    });
    canvas.drawPath(small, fill);
    final glow = Rect.fromCircle(center: center, radius: width * 0.5);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            skin.accentColor.withAlpha(0x70),
            skin.accentColor.withAlpha(0),
          ],
        ).createShader(glow),
    );
    final bolt = _boltPath(center, width * 0.68, 0.12);
    canvas
      ..drawPath(bolt, Paint()..color = skin.accentColor)
      ..drawPath(
        bolt,
        Paint()
          ..color = const Color(0xFFFF8F00)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = _hairline(0.012, 0.8),
      );
  }

  /// Spokes and sagging threads of a web whose center is [origin], from
  /// the angle [from] to [to].
  static Path _webPath(
    Offset origin,
    double from,
    double to,
    int spokes,
    List<double> radii,
    double reach,
  ) {
    final path = Path();
    final angles = [
      for (var i = 0; i < spokes; i++) from + (to - from) * i / (spokes - 1),
    ];
    for (final angle in angles) {
      final end = origin + Offset(cos(angle), sin(angle)) * reach;
      path
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(end.dx, end.dy);
    }
    for (final radius in radii) {
      for (var i = 0; i < spokes - 1; i++) {
        final a = origin + Offset(cos(angles[i]), sin(angles[i])) * radius;
        final b =
            origin + Offset(cos(angles[i + 1]), sin(angles[i + 1])) * radius;
        final sag = origin + ((a + b) / 2 - origin) * 0.86;
        path
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(sag.dx, sag.dy, b.dx, b.dy);
      }
    }
    return path;
  }

  /// A web spun from the top-left corner, a small one in the opposite
  /// corner, and its spider hanging by a thread.
  void _web(Canvas canvas, Rect inner, Paint stroke, Paint fill) {
    final reach = inner.longestSide * 1.3;
    final big = _webPath(inner.topLeft, 0, pi / 2, 8, [
      for (var k = 1; k <= 9; k++) width * (0.08 + 0.13 * k + 0.012 * k * k),
    ], reach);
    final small = _webPath(inner.bottomRight, pi, pi * 1.5, 5, [
      for (var k = 1; k <= 3; k++) width * 0.08 * k,
    ], width * 0.4);
    stroke.strokeWidth = _hairline(0.009);
    canvas
      ..drawPath(big, stroke)
      ..drawPath(small, stroke);
    final spider =
        inner.topLeft + Offset(inner.width * 0.7, inner.height * 0.7);
    final threadTop =
        inner.topLeft + Offset(inner.width * 0.7, inner.height * 0.32);
    final legs = Path();
    final leg = width * 0.07;
    // Four legs on each side, from the front ones up to the back ones down.
    for (final side in const [-1.0, 1.0]) {
      for (var i = 0; i < 4; i++) {
        final angle = -0.9 + i * 0.6;
        final knee =
            spider +
            Offset(side * cos(angle), -sin(angle) * 0.8 - 0.3) * leg * 0.6;
        final foot = knee + Offset(side * leg * 0.45, leg * (0.15 + i * 0.12));
        legs
          ..moveTo(spider.dx, spider.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy);
      }
    }
    canvas
      ..drawLine(threadTop, spider, stroke..strokeWidth = _hairline(0.006, 0.5))
      ..drawPath(legs, stroke..strokeWidth = _hairline(0.012, 0.7))
      ..drawCircle(spider + Offset(0, width * 0.045), width * 0.045, fill)
      ..drawCircle(spider, width * 0.028, fill)
      ..drawCircle(
        spider + Offset(0, width * 0.05),
        width * 0.016,
        Paint()..color = skin.accentColor,
      );
  }

  /// A crescent moon in an evening sky, over dark hills.
  void _moon(Canvas canvas, Rect inner, Paint fill) {
    final moon =
        inner.topLeft + Offset(inner.width * 0.64, inner.height * 0.27);
    final radius = width * 0.15;
    final glow = Rect.fromCircle(center: moon, radius: radius * 3);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            skin.accentColor.withAlpha(0x59),
            skin.accentColor.withAlpha(0),
          ],
        ).createShader(glow),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: moon + Offset(radius * 0.45, -radius * 0.3),
          radius: radius * 0.86,
        ),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = skin.accentColor);
    final sparkles = Path();
    for (final (x, y, size) in const [
      (0.18, 0.1, 1.0),
      (0.36, 0.3, 0.6),
      (0.12, 0.42, 0.7),
      (0.86, 0.5, 0.6),
      (0.42, 0.08, 0.55),
      (0.9, 0.12, 0.8),
      (0.6, 0.5, 0.5),
    ]) {
      sparkles.addPath(
        _sparkle(
          inner.topLeft + Offset(inner.width * x, inner.height * y),
          width * 0.04 * size,
        ),
        Offset.zero,
      );
    }
    canvas.drawPath(
      sparkles,
      Paint()..color = skin.accentColor.withAlpha(0xE6),
    );
    Path hills(double base, List<(double, double)> tops) {
      final path = Path()..moveTo(inner.left, inner.bottom);
      path.lineTo(inner.left, inner.top + inner.height * base);
      var x = inner.left;
      for (final (top, length) in tops) {
        final next = x + inner.width * length;
        path.quadraticBezierTo(
          (x + next) / 2,
          inner.top + inner.height * top,
          next,
          inner.top + inner.height * base,
        );
        x = next;
      }
      return path
        ..lineTo(inner.right, inner.bottom)
        ..close();
    }

    canvas
      ..drawPath(
        hills(0.86, const [(0.72, 0.45), (0.78, 0.35), (0.7, 0.4)]),
        Paint()..color = skin.patternColor.withAlpha(0x8C),
      )
      ..drawPath(hills(0.92, const [(0.8, 0.6), (0.84, 0.55)]), fill);
  }

  /// A star with four thin points.
  static Path _sparkle(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? radius : radius * 0.28;
      final angle = -pi / 2 + i * pi / 4;
      final point = center + Offset(r * cos(angle), r * sin(angle));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Centers of a grid of hexagons of [radius] over [area]: pointy-top
  /// (in rows), or flat-top (in columns).
  static List<Offset> _hexCenters(
    Rect area,
    double radius, {
    bool flat = false,
  }) {
    final across = sqrt(3) * radius;
    final along = 1.5 * radius;
    final centers = <Offset>[];
    final rows = ((flat ? area.width : area.height) / along / 2).ceil() + 1;
    final cols = ((flat ? area.height : area.width) / across / 2).ceil() + 1;
    for (var row = -rows; row <= rows; row++) {
      for (var col = -cols; col <= cols; col++) {
        final shift = row.isOdd ? 0.5 : 0.0;
        final a = (col + shift) * across;
        final b = row * along;
        centers.add(area.center + (flat ? Offset(b, a) : Offset(a, b)));
      }
    }
    return centers;
  }

  static Path _hexagon(Offset center, double radius, {bool flat = false}) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (flat ? 0 : pi / 6) + i * pi / 3;
      final point = center + Offset(cos(angle), sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Glossy hexagon scales, brighter at the top.
  void _scales(Canvas canvas, Rect inner, Paint stroke) {
    final radius = width / 10;
    final scales = Path();
    final shines = Path();
    for (final center in _hexCenters(inner, radius)) {
      scales.addPath(_hexagon(center, radius * 0.86), Offset.zero);
      shines.addOval(
        Rect.fromCenter(
          center: center + Offset(-radius * 0.2, -radius * 0.3),
          width: radius * 0.6,
          height: radius * 0.34,
        ),
      );
    }
    canvas
      ..drawPath(
        scales,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              skin.patternColor.withAlpha(0x59),
              skin.patternColor.withAlpha(0x14),
            ],
          ).createShader(inner),
      )
      ..drawPath(
        scales,
        stroke
          ..color = skin.patternColor.withAlpha(0x8C)
          ..strokeWidth = _hairline(0.01),
      )
      ..drawPath(shines, Paint()..color = skin.accentColor.withAlpha(0x2E));
  }

  /// Soft folds of satin flowing across the card: each fold is a light
  /// crest over a shadow, drawn as thin strips that follow the wave.
  void _sheen(Canvas canvas, Rect inner) {
    const levels = 6;
    final step = width * 0.02;
    final reach = inner.longestSide;
    final crests = [for (var i = 0; i < levels; i++) Path()];
    final shadows = [for (var i = 0; i < levels; i++) Path()];
    for (final (i, offset) in const [-0.6, -0.27, 0.05, 0.38, 0.7].indexed) {
      final phase = i * 1.9;
      void addWave(Path path, double y) {
        for (var x = -reach; x <= reach; x += width / 20) {
          final at = Offset(x, y + width * 0.1 * sin(x / width * 2.6 + phase));
          x == -reach ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
        }
      }

      for (var j = 1 - levels; j < levels; j++) {
        final y = offset * reach + j * step;
        addWave(crests[j.abs()], y);
        addWave(shadows[j.abs()], y + levels * step * 1.6);
      }
    }
    final center = inner.center;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-0.55);
    for (var level = 0; level < levels; level++) {
      final strength = 1 - level / levels;
      for (final (paths, color) in [
        (shadows, skin.accentColor),
        (crests, skin.patternColor),
      ]) {
        canvas.drawPath(
          paths[level],
          Paint()
            ..color = color.withValues(alpha: color.a * strength * strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = step * 1.05,
        );
      }
    }
    canvas.restore();
  }

  /// Brushed metal: fine horizontal streaks, a stamped panel and a rivet in
  /// each corner.
  void _rivets(Canvas canvas, Rect inner, Paint stroke) {
    final random = DealRandom(7);
    final light = Path();
    final dark = Path();
    final step = width / 48;
    for (var y = inner.top; y < inner.bottom; y += step) {
      final start = inner.left + random.nextInt(100) / 100 * inner.width * 0.5;
      final end = start + inner.width * (0.4 + random.nextInt(100) / 100);
      (random.nextInt(2) == 0 ? light : dark)
        ..moveTo(start - inner.width * 0.3, y)
        ..lineTo(end, y);
    }
    final streak = _hairline(0.008, 0.5);
    canvas
      ..drawPath(light, stroke..strokeWidth = streak)
      ..drawPath(
        dark,
        Paint()
          ..color = skin.accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = streak,
      );
    final panel = RRect.fromRectAndRadius(
      inner.deflate(width * 0.16),
      Radius.circular(width * 0.05),
    );
    final groove = _hairline(0.014, 0.8);
    canvas
      ..drawRRect(
        panel.shift(Offset(groove, groove)),
        Paint()
          ..color = const Color(0x8CFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = groove,
      )
      ..drawRRect(
        panel,
        Paint()
          ..color = const Color(0x59000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = groove,
      );
    final radius = width * 0.042;
    final inset = width * 0.085;
    for (final corner in [
      inner.topLeft + Offset(inset, inset),
      inner.topRight + Offset(-inset, inset),
      inner.bottomLeft + Offset(inset, -inset),
      inner.bottomRight + Offset(-inset, -inset),
    ]) {
      final head = Rect.fromCircle(center: corner, radius: radius);
      canvas
        ..drawCircle(
          corner + Offset(radius * 0.25, radius * 0.35),
          radius * 1.05,
          Paint()..color = const Color(0x66000000),
        )
        ..drawOval(
          head,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.45, -0.5),
              colors: [Color(0xFFFBFCFD), Color(0xFFADB4BB), Color(0xFF5F666D)],
              stops: [0, 0.55, 1],
            ).createShader(head),
        );
    }
  }

  /// A honeycomb, with some cells full of honey.
  void _honeycomb(Canvas canvas, Rect inner, Paint stroke) {
    final radius = width / 8.5;
    final cells = Path();
    final honey = Path();
    for (final (i, center) in _hexCenters(inner, radius, flat: true).indexed) {
      final hexagon = _hexagon(center, radius * 0.9, flat: true);
      cells.addPath(hexagon, Offset.zero);
      if ((i * 7) % 5 < 2) honey.addPath(hexagon, Offset.zero);
    }
    canvas
      ..drawPath(honey, Paint()..color = skin.accentColor)
      ..drawPath(
        cells,
        stroke
          ..strokeWidth = max(1, radius * 0.16)
          ..strokeJoin = StrokeJoin.round,
      );
    canvas.drawRect(
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 0.9,
          colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
        ).createShader(inner),
    );
  }

  static const _rainbow = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF3949AB),
    Color(0xFF8E24AA),
  ];

  /// Rainbow bands across the card, with a gloss on top.
  void _bands(Canvas canvas, Rect inner, Paint stroke) {
    final center = inner.center;
    final reach = inner.longestSide;
    final band = (inner.width + inner.height) / sqrt2 / _rainbow.length;
    final first = -band * _rainbow.length / 2;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(-pi / 4);
    final edges = Path();
    for (final (i, color) in _rainbow.indexed) {
      final x = first + i * band;
      canvas.drawRect(
        Rect.fromLTWH(x, -reach, band + 0.5, reach * 2),
        Paint()..color = color,
      );
      if (i > 0) {
        edges
          ..moveTo(x, -reach)
          ..lineTo(x, reach);
      }
    }
    canvas
      ..drawPath(edges, stroke..strokeWidth = _hairline(0.012, 0.6))
      ..restore()
      ..drawRect(
        inner,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x59FFFFFF), Color(0x00FFFFFF), Color(0x26000000)],
            stops: [0, 0.5, 1],
          ).createShader(inner),
      );
  }

  /// Guilloché: a rosette of overlapping circles, framed by two woven waves.
  void _guilloche(Canvas canvas, Rect inner, Paint stroke) {
    final center = inner.center;
    final rosette = Path();
    const loops = 30;
    for (var i = 0; i < loops; i++) {
      final angle = i * 2 * pi / loops;
      rosette.addOval(
        Rect.fromCircle(
          center: center + Offset(cos(angle), sin(angle)) * width * 0.1,
          radius: width * 0.19,
        ),
      );
    }
    final waves = Path();
    for (final phase in const [0.0, pi]) {
      for (var i = 0; i <= 120; i++) {
        final angle = i * 2 * pi / 120;
        final r = width * (0.335 + 0.03 * sin(angle * 12 + phase));
        final point = center + Offset(cos(angle) * r, sin(angle) * r * 1.38);
        i == 0
            ? waves.moveTo(point.dx, point.dy)
            : waves.lineTo(point.dx, point.dy);
      }
    }
    final rims = Path()
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: width * 0.6,
          height: width * 0.6 * 1.38,
        ),
      )
      ..addOval(
        Rect.fromCenter(
          center: center,
          width: width * 0.78,
          height: width * 0.78 * 1.38,
        ),
      );
    final line = _hairline(0.006, 0.45);
    canvas
      ..drawPath(rosette, stroke..strokeWidth = line)
      ..drawPath(waves, stroke)
      ..drawPath(
        rims,
        Paint()
          ..color = skin.accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = line,
      );
  }

  /// Deep space: glowing clouds, a few stars and a ringed planet.
  void _nebula(Canvas canvas, Rect inner, Paint fill) {
    for (final (x, y, radius, color) in const [
      (0.25, 0.3, 0.75, Color(0x80C2185B)),
      (0.8, 0.75, 0.85, Color(0x806A3FD0)),
      (0.55, 0.45, 0.45, Color(0x4D26C6DA)),
    ]) {
      final cloud = Rect.fromCircle(
        center: inner.topLeft + Offset(inner.width * x, inner.height * y),
        radius: width * radius,
      );
      canvas.drawOval(
        cloud,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withAlpha(0)])
              .createShader(cloud),
      );
    }
    final stars = Path();
    for (final (x, y, size) in const [
      (0.12, 0.08, 1.0),
      (0.3, 0.2, 0.6),
      (0.78, 0.12, 0.8),
      (0.9, 0.34, 0.6),
      (0.08, 0.55, 0.7),
      (0.22, 0.82, 0.9),
      (0.48, 0.94, 0.6),
      (0.92, 0.9, 0.7),
      (0.62, 0.22, 0.5),
    ]) {
      stars.addOval(
        Rect.fromCircle(
          center: inner.topLeft + Offset(inner.width * x, inner.height * y),
          radius: max(0.5, width * 0.012 * size),
        ),
      );
    }
    canvas
      ..drawPath(stars, fill)
      ..drawPath(
        _sparkle(
          inner.topLeft + Offset(inner.width * 0.24, inner.height * 0.36),
          width * 0.06,
        ),
        fill,
      )
      ..drawPath(
        _sparkle(
          inner.topLeft + Offset(inner.width * 0.84, inner.height * 0.6),
          width * 0.04,
        ),
        fill,
      );
    final planet =
        inner.topLeft + Offset(inner.width * 0.56, inner.height * 0.57);
    final radius = width * 0.15;
    final ring = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 3.6,
      height: radius * 0.95,
    );
    final ringPaint = Paint()
      ..color = skin.accentColor.withAlpha(0xD9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, radius * 0.16);
    void drawRing({required bool front}) {
      canvas
        ..save()
        ..translate(planet.dx, planet.dy)
        ..rotate(-0.38)
        ..clipRect(
          Rect.fromLTRB(
            -radius * 3,
            front ? 0 : -radius * 3,
            radius * 3,
            front ? radius * 3 : 0,
          ),
        )
        ..drawOval(ring, ringPaint)
        ..restore();
    }

    drawRing(front: false);
    final body = Rect.fromCircle(center: planet, radius: radius);
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.5),
          radius: 1.1,
          colors: [
            Color.lerp(skin.accentColor, const Color(0xFFFFFFFF), 0.5)!,
            skin.accentColor,
            const Color(0xFF8A3B12),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(body),
    );
    drawRing(front: true);
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.skin != skin || old.width != width;
}
