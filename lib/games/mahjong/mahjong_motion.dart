import 'dart:math';
import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/animation.dart';

enum TileMotionKind {
  /// A new deal: the tile falls into its place.
  drop,

  /// A shuffle: the tile flies on an arc to its new place.
  fly,

  /// A match: the tile flies toward its partner, shrinks and fades away.
  vanish,

  /// An undone match: the tile comes back.
  appear,

  /// A blocked tile was tapped: it shakes its head.
  shake,

  /// A hint: the tile's halo pulses three times.
  pulse,
}

/// How a tile looks at a moment of its motion: [offset] from its place on
/// the board, its [scale], [opacity], hint [glow] (0 to 1) and [elevation]
/// (0 on the board, 1 at the top of a flight).
class TilePose {
  const TilePose({
    this.offset = Offset.zero,
    this.scale = 1,
    this.opacity = 1,
    this.glow = 0,
    this.elevation = 0,
  });

  final Offset offset;
  final double scale;
  final double opacity;
  final double glow;
  final double elevation;
}

/// One motion of a tile on the board's timeline, in milliseconds. Every
/// motion ends: tests wait for them with `pumpAndSettle`.
class TileMotion {
  const TileMotion({
    required this.kind,
    required this.start,
    required this.duration,
    this.from = Offset.zero,
    this.to = Offset.zero,
    this.height = 0,
  });

  final TileMotionKind kind;
  final double start;
  final double duration;

  /// Offsets from the tile's place at the start and at the end.
  final Offset from;
  final Offset to;

  /// Height of a flight's arc, or size of a drop or a shake.
  final double height;

  double get end => start + duration;

  /// The same motion on a timeline that starts [by] ms later.
  TileMotion shifted(double by) => TileMotion(
    kind: kind,
    start: start - by,
    duration: duration,
    from: from,
    to: to,
    height: height,
  );

  /// Whether the tile leaves the board's paint order at [time]: it is in
  /// the air, above the others.
  bool isAirborneAt(double time) =>
      (kind == TileMotionKind.fly || kind == TileMotionKind.vanish) &&
      time >= start &&
      time < end;

  TilePose poseAt(double time) {
    final t = duration <= 0 ? 1.0 : ((time - start) / duration).clamp(0.0, 1.0);
    final waiting = time < start;
    switch (kind) {
      case TileMotionKind.drop:
        if (waiting) return const TilePose(opacity: 0);
        final p = Curves.easeOutCubic.transform(t);
        return TilePose(
          offset: Offset(0, -height * (1 - p)),
          scale: lerpDouble(1.15, 1, p)!,
          opacity: (t * 2.5).clamp(0.0, 1.0),
        );
      case TileMotionKind.fly:
        final p = Curves.easeInOutCubic.transform(t);
        final lift = sin(pi * t);
        return TilePose(
          offset: Offset.lerp(from, to, p)! - Offset(0, height * lift),
          scale: 1 + 0.08 * lift,
          elevation: lift,
        );
      case TileMotionKind.vanish:
        final p = Curves.easeInCubic.transform(t);
        return TilePose(
          offset: Offset.lerp(from, to, p)!,
          scale: lerpDouble(1.06, 0.55, p)!,
          opacity: t < 0.5 ? 1 : 1 - (t - 0.5) * 2,
          glow: 1 - t,
          elevation: t > 0 ? 1 : 0,
        );
      case TileMotionKind.appear:
        final p = Curves.easeOutBack.transform(t);
        return TilePose(scale: lerpDouble(0.6, 1, p)!, opacity: t);
      case TileMotionKind.shake:
        return TilePose(offset: Offset(sin(t * pi * 6) * height * (1 - t), 0));
      case TileMotionKind.pulse:
        return TilePose(glow: waiting ? 0 : (1 - cos(2 * pi * 3 * t)) / 2);
    }
  }
}
