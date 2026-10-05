import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Vertices;

import 'package:flutter/foundation.dart' show ValueListenable;
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

/// Bursts of confetti, one per origin, on the table timeline (milliseconds).
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

  /// Draws the pieces in the air at [t] in one call: each piece is a
  /// rectangle of two triangles, turned and squeezed on the CPU.
  void paint(Canvas canvas, double t) {
    final positions = Float32List(_pieces.length * 8);
    final colors = Int32List(_pieces.length * 4);
    var count = 0;
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
      final angle = piece.phase + piece.spin * age;
      // Turning over in the air: the piece gets thin, then wide again.
      final squeeze = cos(piece.phase + piece.flutter * age);
      // The two sides of the rectangle from its corner, turned by angle.
      final widthX = cos(angle) * piece.size.width * squeeze;
      final widthY = sin(angle) * piece.size.width * squeeze;
      final heightX = -sin(angle) * piece.size.height;
      final heightY = cos(angle) * piece.size.height;
      final p = count * 8;
      positions
        ..[p] = position.dx
        ..[p + 1] = position.dy
        ..[p + 2] = position.dx + widthX
        ..[p + 3] = position.dy + widthY
        ..[p + 4] = position.dx + widthX + heightX
        ..[p + 5] = position.dy + widthY + heightY
        ..[p + 6] = position.dx + heightX
        ..[p + 7] = position.dy + heightY;
      final color = piece.color.withValues(alpha: fade).toARGB32();
      colors.fillRange(count * 4, count * 4 + 4, color);
      count++;
    }
    if (count == 0) return;
    final indices = Uint16List(count * 6);
    for (var i = 0, corner = 0; i < indices.length; i += 6, corner += 4) {
      indices
        ..[i] = corner
        ..[i + 1] = corner + 1
        ..[i + 2] = corner + 2
        ..[i + 3] = corner
        ..[i + 4] = corner + 2
        ..[i + 5] = corner + 3;
    }
    final vertices = Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(positions, 0, count * 8),
      colors: Int32List.sublistView(colors, 0, count * 4),
      indices: indices,
    );
    // Only the colors of the vertices.
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }
}

/// Paints [confetti] at the time of [clock], repainting when it ticks.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.confetti, this.clock, {this.origin = Offset.zero})
    : super(repaint: clock);

  final Confetti confetti;
  final ValueListenable<double> clock;

  /// Where the table is: the bursts start from table positions.
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy);
    confetti.paint(canvas, clock.value);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.confetti != confetti ||
      oldDelegate.clock != clock ||
      oldDelegate.origin != origin;
}
