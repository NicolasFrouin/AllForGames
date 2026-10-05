import 'dart:math';

import 'package:material_ui/material_ui.dart';

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
}

/// The look of the face-down cards.
class CardBackSkin {
  const CardBackSkin({
    required this.id,
    required this.colors,
    this.pattern = CardBackPattern.none,
    this.patternColor = const Color(0x33FFFFFF),
    this.borderColor = const Color(0x66FFFFFF),
    this.emblem,
    this.unlockedBy,
  });

  final String id;

  /// Background gradient, from the top-left to the bottom-right corner.
  final List<Color> colors;
  final CardBackPattern pattern;

  /// Color of the pattern and of the [emblem].
  final Color patternColor;

  /// Color of the thin inner border.
  final Color borderColor;

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
];

/// The skin with [id], or [classicCardBack] when there is none (for example a
/// skin saved by a newer app version).
CardBackSkin cardBackById(String id) => cardBacks.firstWhere(
  (skin) => skin.id == id,
  orElse: () => classicCardBack,
);

/// The skin that the achievement [achievementId] unlocks, if any.
CardBackSkin? cardBackUnlockedBy(String achievementId) {
  for (final skin in cardBacks) {
    if (skin.unlockedBy == achievementId) return skin;
  }
  return null;
}

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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.skin != skin || old.width != width;
}
