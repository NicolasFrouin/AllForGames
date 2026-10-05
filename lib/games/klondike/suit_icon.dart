import 'package:material_ui/material_ui.dart';

import 'playing_card.dart';

/// Draws a suit as a vector shape. Text symbols like ♥ show as color emoji
/// on some platforms, which ignores the text color.
class SuitIcon extends StatelessWidget {
  const SuitIcon(this.suit, {super.key, required this.size, this.color});

  final Suit suit;
  final double size;

  /// Defaults to red or black from the suit.
  final Color? color;

  static const red = Color(0xFFC62828);
  static const black = Color(0xFF1B1B1F);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SuitPainter(suit, color ?? (suit.isRed ? red : black)),
    );
  }
}

class _SuitPainter extends CustomPainter {
  const _SuitPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 1);
    // Clubs and spades overlap shapes: one layer keeps a faded color even.
    final faded = color.a < 1;
    if (faded) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, color.a),
      );
    }
    canvas.scale(size.width, size.height);
    switch (suit) {
      case Suit.diamonds:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0)
            ..lineTo(0.88, 0.5)
            ..lineTo(0.5, 1)
            ..lineTo(0.12, 0.5)
            ..close(),
          paint,
        );
      case Suit.hearts:
        canvas.drawPath(
          Path()
            ..moveTo(0.5, 0.95)
            ..cubicTo(0.15, 0.7, 0, 0.5, 0, 0.3)
            ..cubicTo(0, 0.12, 0.13, 0.04, 0.27, 0.04)
            ..cubicTo(0.38, 0.04, 0.46, 0.12, 0.5, 0.22)
            ..cubicTo(0.54, 0.12, 0.62, 0.04, 0.73, 0.04)
            ..cubicTo(0.87, 0.04, 1, 0.12, 1, 0.3)
            ..cubicTo(1, 0.5, 0.85, 0.7, 0.5, 0.95)
            ..close(),
          paint,
        );
      case Suit.spades:
        canvas
          ..drawPath(
            Path()
              ..moveTo(0.5, 0.02)
              ..cubicTo(0.85, 0.3, 1, 0.45, 1, 0.62)
              ..cubicTo(1, 0.78, 0.88, 0.86, 0.75, 0.86)
              ..cubicTo(0.64, 0.86, 0.55, 0.8, 0.5, 0.7)
              ..cubicTo(0.45, 0.8, 0.36, 0.86, 0.25, 0.86)
              ..cubicTo(0.12, 0.86, 0, 0.78, 0, 0.62)
              ..cubicTo(0, 0.45, 0.15, 0.3, 0.5, 0.02)
              ..close(),
            paint,
          )
          ..drawPath(_stem, paint);
      case Suit.clubs:
        canvas
          ..drawCircle(const Offset(0.5, 0.27), 0.22, paint)
          ..drawCircle(const Offset(0.26, 0.6), 0.22, paint)
          ..drawCircle(const Offset(0.74, 0.6), 0.22, paint)
          ..drawCircle(const Offset(0.5, 0.52), 0.14, paint)
          ..drawPath(_stem, paint);
    }
    if (faded) canvas.restore();
  }

  static final _stem = Path()
    ..moveTo(0.47, 0.6)
    ..quadraticBezierTo(0.46, 0.88, 0.3, 0.98)
    ..lineTo(0.7, 0.98)
    ..quadraticBezierTo(0.54, 0.88, 0.53, 0.6)
    ..close();

  @override
  bool shouldRepaint(_SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}
