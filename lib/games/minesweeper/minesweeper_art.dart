import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../skins/minesweeper_themes.dart';

/// Draws the cells of a board in vector art, for one theme and cell size.
/// It keeps the laid out numbers.
class MinesweeperArt {
  MinesweeperArt(this.theme, this.cell);

  final MinesweeperTheme theme;

  /// Width (and height) of a cell.
  final double cell;
  final _numbers = <int, TextPainter>{};
  final _paint = Paint();

  void dispose() {
    for (final number in _numbers.values) {
      number.dispose();
    }
  }

  /// The raised cover of a hidden cell, scaled around its center.
  void covered(
    Canvas canvas,
    Rect rect, {
    double opacity = 1,
    double scale = 1,
  }) {
    if (opacity <= 0 || scale <= 0) return;
    final face = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    ).deflate(max(1, cell * 0.04) * scale);
    final bevel = max(1.0, cell * theme.bevel) * scale;
    final radius = Radius.circular(cell * theme.corner * scale);
    Color fade(Color color) => color.withValues(alpha: color.a * opacity);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(face, radius),
        _paint..color = fade(theme.coveredShade),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            face.left,
            face.top,
            face.right - bevel,
            face.bottom - bevel,
          ),
          radius,
        ),
        _paint..color = fade(theme.coveredLight),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(face.deflate(bevel), radius * 0.7),
        _paint..color = fade(theme.covered),
      );
  }

  /// A flat open cell; red under the mine the player opened.
  void open(Canvas canvas, Rect rect, {bool exploded = false}) {
    canvas
      ..drawRect(rect, _paint..color = exploded ? theme.exploded : theme.open)
      ..drawRect(
        rect.deflate(0.25),
        _paint
          ..color = theme.openLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    _paint.style = PaintingStyle.fill;
  }

  /// The number of mines around a cell, from 1 to 8.
  void number(Canvas canvas, Rect rect, int count, {double scale = 1}) {
    if (scale <= 0) return;
    final text = _numbers.putIfAbsent(
      count,
      () => TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            color: theme.numbers[count - 1],
            fontSize: cell * 0.62,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(),
    );
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(scale);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  /// A round mine with spikes and a shine.
  void mine(Canvas canvas, Rect rect, {double scale = 1}) {
    if (scale <= 0) return;
    final center = rect.center;
    final r = cell * 0.22 * scale;
    final spike = cell * 0.34 * scale;
    _paint
      ..color = theme.mine
      ..strokeWidth = cell * 0.075 * scale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final direction = Offset.fromDirection(i * pi / 4, spike);
      canvas.drawLine(center - direction, center + direction, _paint);
    }
    canvas
      ..drawCircle(center, r, _paint)
      ..drawCircle(
        center - Offset(r, r) * 0.35,
        r * 0.3,
        _paint..color = theme.mineShine.withValues(alpha: 0.85),
      );
  }

  /// A flag on its pole, scaled from its base.
  void flag(Canvas canvas, Rect rect, {double scale = 1}) {
    if (scale <= 0) return;
    final base = rect.center + Offset(0, cell * 0.26);
    canvas
      ..save()
      ..translate(base.dx, base.dy)
      ..scale(scale);
    final s = cell;
    _paint
      ..color = theme.flagPole
      ..strokeWidth = max(1.0, s * 0.06)
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(s * 0.06, 0), Offset(s * 0.06, -s * 0.52), _paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * 0.04, -s * 0.01),
            width: s * 0.4,
            height: s * 0.08,
          ),
          Radius.circular(s * 0.03),
        ),
        _paint,
      )
      ..drawPath(
        Path()
          ..moveTo(s * 0.08, -s * 0.54)
          ..lineTo(s * 0.08, -s * 0.24)
          ..lineTo(-s * 0.26, -s * 0.39)
          ..close(),
        _paint..color = theme.flag,
      )
      ..restore();
  }

  /// A cross over a wrong flag.
  void cross(Canvas canvas, Rect rect, {double scale = 1}) {
    if (scale <= 0) return;
    final d = cell * 0.3 * scale;
    final c = rect.center;
    _paint
      ..color = theme.cross
      ..strokeWidth = cell * 0.09 * scale
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(c - Offset(d, d), c + Offset(d, d), _paint)
      ..drawLine(c + Offset(d, -d), c - Offset(d, -d), _paint);
  }

  /// The glow of a hinted cell, from 0 to 1.
  void glow(Canvas canvas, Rect rect, double amount) {
    if (amount <= 0) return;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(cell * 0.05),
      Radius.circular(cell * 0.18),
    );
    canvas
      ..drawRRect(
        rrect,
        _paint..color = theme.accent.withValues(alpha: 0.35 * amount),
      )
      ..drawRRect(
        rrect,
        _paint
          ..color = theme.accent.withValues(alpha: amount)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, cell * 0.1),
      );
    _paint.style = PaintingStyle.fill;
  }

  /// A ring that spreads and fades, [progress] from 0 to 1.
  void burst(Canvas canvas, Rect rect, double progress, {bool big = false}) {
    final reach = big ? 2.4 : 1.1;
    canvas.drawCircle(
      rect.center,
      cell * (0.3 + reach * Curves.easeOut.transform(progress)),
      _paint
        ..color = (big ? theme.exploded : theme.accent).withValues(
          alpha: 1 - progress,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * (big ? 0.16 : 0.08) * (1 - progress),
    );
    _paint.style = PaintingStyle.fill;
  }
}
