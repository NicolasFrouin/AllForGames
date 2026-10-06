import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';

enum CellMotionKind {
  /// A new board: the cover pops in.
  deal,

  /// The cover lifts off, then the number pops in.
  reveal,

  /// A flag pops in.
  flag,

  /// A flag shrinks away.
  unflag,

  /// A lost game shows a mine: the cover lifts, the mine pops in with a
  /// small shake and a burst.
  mine,

  /// The mine the player opened: a bigger burst.
  exploded,

  /// A lost game crosses a flag that had no mine.
  wrongFlag,

  /// A tap that does nothing: the cell shakes its head.
  shake,

  /// A hint: the cell glows three times.
  hint,
}

/// How a cell looks at a moment of its motion: its [cover] (opacity of the
/// raised cover, and its [coverScale]), the scale of its [mark] (number,
/// mine, flag or cross), a [shake] (fraction of the cell width), the
/// progress of a [burst] ring (null when none) and a hint [glow] (0 to 1).
class CellPose {
  const CellPose({
    this.cover = 1,
    this.coverScale = 1,
    this.mark = 1,
    this.shake = 0,
    this.burst,
    this.glow = 0,
  });

  final double cover;
  final double coverScale;
  final double mark;
  final double shake;
  final double? burst;
  final double glow;
}

/// One motion of a cell on the board's timeline, in milliseconds. Every
/// motion ends: tests wait for them with `pumpAndSettle`.
class CellMotion {
  const CellMotion(this.kind, {required this.start, required this.duration});

  final CellMotionKind kind;
  final double start;
  final double duration;

  double get end => start + duration;

  /// The same motion on a timeline that starts [by] ms later.
  CellMotion shifted(double by) =>
      CellMotion(kind, start: start - by, duration: duration);

  CellPose poseAt(double time) {
    final waiting = time < start;
    final t = duration <= 0 ? 1.0 : ((time - start) / duration).clamp(0.0, 1.0);
    // The cover lifts in the first part, the mark pops in the second.
    double lift(double end) => Curves.easeIn.transform(min(t / end, 1));
    double pop(double from) =>
        t <= from ? 0 : Curves.easeOutBack.transform((t - from) / (1 - from));
    switch (kind) {
      case CellMotionKind.deal:
        if (waiting) return const CellPose(cover: 0);
        final p = Curves.easeOutBack.transform(t);
        return CellPose(
          cover: min(t * 3, 1),
          coverScale: lerpDouble(0.4, 1, p)!,
        );
      case CellMotionKind.reveal:
        if (waiting) return const CellPose(mark: 0);
        return CellPose(
          cover: 1 - lift(0.6),
          coverScale: lerpDouble(1, 0.55, lift(0.6))!,
          mark: pop(0.35),
        );
      case CellMotionKind.flag:
        return CellPose(mark: waiting ? 0 : Curves.easeOutBack.transform(t));
      case CellMotionKind.unflag:
        return CellPose(mark: 1 - Curves.easeIn.transform(t));
      case CellMotionKind.mine || CellMotionKind.exploded:
        if (waiting) return const CellPose(mark: 0);
        final burstFrom = kind == CellMotionKind.exploded ? 0.1 : 0.3;
        return CellPose(
          cover: 1 - lift(0.3),
          coverScale: lerpDouble(1, 0.55, lift(0.3))!,
          mark: pop(0.2),
          shake: sin(t * pi * 6) * 0.06 * (1 - t),
          burst: t < burstFrom ? null : (t - burstFrom) / (1 - burstFrom),
        );
      case CellMotionKind.wrongFlag:
        return CellPose(mark: waiting ? 0 : Curves.easeOutBack.transform(t));
      case CellMotionKind.shake:
        return CellPose(shake: sin(t * pi * 6) * 0.1 * (1 - t));
      case CellMotionKind.hint:
        return CellPose(glow: waiting ? 0 : (1 - cos(2 * pi * 3 * t)) / 2);
    }
  }
}
