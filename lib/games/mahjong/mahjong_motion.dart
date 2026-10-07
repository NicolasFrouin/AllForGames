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

  /// Tray mode: the tile flies on an arc to the tile of the tray it clears,
  /// then [pop]s with it.
  collect,

  /// Tray mode: a tile of a cleared pair swells, then shrinks and fades
  /// away.
  pop,

  /// Tray mode: the tile slides to its new place in the tray.
  slide,

  /// A face-down tile turns over (or back): it rises a little and swells.
  turn,

  /// Discs mode: a disc no tile lies on any more rises and fades away.
  escape,
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

  /// Share of a [TileMotionKind.collect] spent flying, before the pop.
  static const collectFlight = 0.6;

  /// Whether the tile leaves the board's paint order at [time]: it is in
  /// the air, above the others.
  bool isAirborneAt(double time) =>
      (kind == TileMotionKind.fly ||
          kind == TileMotionKind.vanish ||
          kind == TileMotionKind.collect ||
          kind == TileMotionKind.escape) &&
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
        return _flight(t);
      case TileMotionKind.collect:
        if (t < collectFlight) return _flight(t / collectFlight);
        return _pop((t - collectFlight) / (1 - collectFlight), to);
      case TileMotionKind.pop:
        return waiting ? const TilePose() : _pop(t, Offset.zero);
      case TileMotionKind.slide:
        return TilePose(
          offset: Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))!,
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
      case TileMotionKind.escape:
        if (waiting) return const TilePose();
        final p = Curves.easeInOutCubic.transform(t);
        return TilePose(
          offset: Offset(0, -height * p),
          scale: 1 + 0.2 * sin(pi * t / 2),
          opacity: t < 0.45 ? 1 : 1 - (t - 0.45) / 0.55,
          elevation: 1,
        );
      case TileMotionKind.turn:
        final lift = sin(pi * t);
        return TilePose(
          offset: Offset(0, -height * lift),
          scale: 1 + 0.1 * lift,
          elevation: lift * 0.5,
        );
    }
  }

  /// From [from] to [to] on an arc of [height], at [t] from 0 to 1.
  TilePose _flight(double t) {
    final p = Curves.easeInOutCubic.transform(t);
    final lift = sin(pi * t);
    return TilePose(
      offset: Offset.lerp(from, to, p)! - Offset(0, height * lift),
      scale: 1 + 0.08 * lift,
      elevation: lift,
    );
  }

  /// A pop at [offset], at [t] from 0 to 1: the tile swells, then shrinks
  /// and fades away.
  static TilePose _pop(double t, Offset offset) {
    const swell = 0.3;
    final scale = t < swell
        ? lerpDouble(1, 1.18, Curves.easeOut.transform(t / swell))!
        : lerpDouble(
            1.18,
            0.3,
            Curves.easeIn.transform((t - swell) / (1 - swell)),
          )!;
    return TilePose(
      offset: offset,
      scale: scale,
      opacity: t < swell ? 1 : 1 - (t - swell) / (1 - swell),
      glow: 1 - t,
      elevation: 1,
    );
  }
}
