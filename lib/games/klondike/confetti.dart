import 'dart:math';

import 'package:material_ui/material_ui.dart';

const _colors = [
  Color(0xFFFFD54F),
  Color(0xFFEF5350),
  Color(0xFF66BB6A),
  Color(0xFF42A5F5),
  Color(0xFFAB47BC),
  Color(0xFFFFA726),
  Color(0xFFFAFAFA),
];

class _Piece {
  _Piece(Random random, this.origin, this.start, double scale)
    : velocity = Offset(
        (random.nextDouble() - 0.5) * 0.9 * scale,
        -(0.35 + random.nextDouble() * 0.4) * scale,
      ),
      spin = (random.nextDouble() - 0.5) * 0.024,
      flutter = 0.006 + random.nextDouble() * 0.01,
      phase = random.nextDouble() * pi * 2,
      size = Size(
        (6 + random.nextDouble() * 5) * scale,
        (3 + random.nextDouble() * 3) * scale,
      ),
      color = _colors[random.nextInt(_colors.length)];

  final Offset origin;
  final double start;

  /// Pixels per millisecond at launch.
  final Offset velocity;
  final double spin;
  final double flutter;
  final double phase;
  final Size size;
  final Color color;
}

/// Bursts of confetti, one per origin, on the board timeline (milliseconds).
class Confetti {
  Confetti({
    required List<Offset> origins,
    required List<double> starts,
    required double scale,
    int seed = 0,
    int perBurst = 40,
  }) : this._(
         [
           for (final (i, origin) in origins.indexed)
             for (var n = 0; n < perBurst; n++)
               _Piece(
                 Random(seed * 31 + i * 1000 + n),
                 origin,
                 starts[i],
                 scale,
               ),
         ],
         scale,
         0,
       );

  const Confetti._(this._pieces, this._scale, this._shift);

  static const lifetime = 2400.0;

  /// Air drag time constant and gravity (ms, px/ms²): pieces slow down, then
  /// fall and flutter.
  static const _drag = 500.0;
  static const _gravity = 0.0003;

  final List<_Piece> _pieces;
  final double _scale;

  /// How much later the timeline started than when the bursts were planned.
  final double _shift;

  double get end =>
      _pieces.fold(0.0, (end, piece) => max(end, piece.start)) +
      lifetime -
      _shift;

  /// The same bursts, on a timeline that starts [ms] later.
  Confetti shifted(double ms) => Confetti._(_pieces, _scale, _shift + ms);

  void paint(Canvas canvas, double t) {
    final paint = Paint();
    for (final piece in _pieces) {
      final age = t + _shift - piece.start;
      if (age <= 0 || age >= lifetime) continue;
      final slowed = _drag * (1 - exp(-age / _drag));
      final position =
          piece.origin +
          piece.velocity * slowed +
          Offset(0, 0.5 * _gravity * _scale * age * age);
      final fade = age > lifetime * 0.7
          ? 1 - (age - lifetime * 0.7) / (lifetime * 0.3)
          : 1.0;
      paint.color = piece.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(piece.phase + piece.spin * age)
        // Turning over in the air: the piece gets thin, then wide again.
        ..scale(cos(piece.phase + piece.flutter * age), 1)
        ..drawRect(Offset.zero & piece.size, paint)
        ..restore();
    }
  }
}

class ConfettiPainter extends CustomPainter {
  const ConfettiPainter(this.confetti, this.t, {this.origin = Offset.zero});

  final Confetti confetti;
  final double t;

  /// Where the board is: the bursts start from board positions.
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy);
    confetti.paint(canvas, t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.confetti != confetti ||
      oldDelegate.origin != origin;
}
