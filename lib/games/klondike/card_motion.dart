import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/animation.dart' show Curve, Curves;

enum CardMotionKind {
  /// From one place to another, on an arc.
  fly,

  /// A jump on the spot (win celebration).
  hop,

  /// A short shake on the spot (a tap with no legal move).
  shake,
}

/// How a card looks at one moment of a [CardMotion].
class CardPose {
  const CardPose({
    required this.position,
    required this.faceUp,
    this.scale = 1,
    this.rotation = 0,
    this.flipAngle = 0,
    this.elevation = 0,
  });

  final Offset position;

  /// The face to draw: during a flip it changes at half time.
  final bool faceUp;
  final double scale;

  /// Rotation in the plane of the table, in radians.
  final double rotation;

  /// Rotation around the vertical axis, in radians (a flip).
  final double flipAngle;

  /// 0 on the table, 1 at the top of a flight (for the shadow).
  final double elevation;
}

/// One planned movement of a card. Times are milliseconds on the board
/// timeline; [start] may be negative for a motion that began before.
class CardMotion {
  const CardMotion({
    required this.kind,
    required this.from,
    required this.to,
    required this.start,
    required this.duration,
    required this.faceFrom,
    required this.faceTo,
    this.height = 0,
    this.curve = Curves.easeOutCubic,
    this.flipStart = 0,
    this.flipDuration = 0,
    this.next,
  });

  final CardMotionKind kind;
  final Offset from;
  final Offset to;
  final double start;
  final double duration;

  /// Height of the arc of a flight or of a hop, amplitude of a shake.
  final double height;
  final Curve curve;

  /// Face before and after the motion: different values flip the card.
  final bool faceFrom;
  final bool faceTo;
  final double flipStart;
  final double flipDuration;

  /// A motion that follows this one (for example a hop after a flight).
  final CardMotion? next;

  double get end => max(
    max(start + duration, flipStart + flipDuration),
    next?.end ?? double.negativeInfinity,
  );

  /// This motion, then [then] after it (and after any [next] already there).
  CardMotion followedBy(CardMotion then) => CardMotion(
    kind: kind,
    from: from,
    to: to,
    start: start,
    duration: duration,
    faceFrom: faceFrom,
    faceTo: faceTo,
    height: height,
    curve: curve,
    flipStart: flipStart,
    flipDuration: flipDuration,
    next: next?.followedBy(then) ?? then,
  );

  /// The part of the motion that runs at [t]: this one or a later [next].
  CardMotion segmentAt(double t) => switch (next) {
    final next? when t >= next.start => next.segmentAt(t),
    _ => this,
  };

  /// True while the card is in the air: drawn above the cards on the table.
  bool isFlyingAt(double t) {
    final segment = segmentAt(t);
    return segment.kind != CardMotionKind.shake &&
        t > segment.start &&
        t < segment.start + segment.duration;
  }

  /// True before the motion starts: the card still waits at [from].
  bool isWaitingAt(double t) => t <= start;

  /// The same motion, on a timeline that starts [ms] later.
  CardMotion shifted(double ms) => CardMotion(
    kind: kind,
    from: from,
    to: to,
    start: start - ms,
    duration: duration,
    faceFrom: faceFrom,
    faceTo: faceTo,
    height: height,
    curve: curve,
    flipStart: flipStart - ms,
    flipDuration: flipDuration,
    next: next?.shifted(ms),
  );

  CardPose poseAt(double t) {
    if (next case final next? when t >= next.start) return next.poseAt(t);
    final u = duration <= 0 ? 1.0 : ((t - start) / duration).clamp(0.0, 1.0);
    final wave = sin(pi * u);
    final (faceUp, flipAngle) = _flipAt(t);
    switch (kind) {
      case CardMotionKind.fly:
        // Exact ends, so a landed card is exactly on its pile.
        if (u <= 0 || u >= 1) {
          return CardPose(
            position: u <= 0 ? from : to,
            faceUp: faceUp,
            flipAngle: flipAngle,
          );
        }
        return CardPose(
          position: Offset.lerp(
            from,
            to,
            curve.transform(u),
          )!.translate(0, -height * wave),
          faceUp: faceUp,
          flipAngle: flipAngle,
          scale: height > 0 ? 1 + 0.06 * wave : 1,
          elevation: height > 0 ? wave : 0,
        );
      case CardMotionKind.hop:
        if (u <= 0 || u >= 1) return CardPose(position: to, faceUp: faceUp);
        return CardPose(
          position: to.translate(0, -height * wave),
          faceUp: faceUp,
          scale: 1 + 0.1 * wave,
          rotation: 0.14 * sin(2 * pi * u),
          elevation: wave,
        );
      case CardMotionKind.shake:
        if (u <= 0 || u >= 1) return CardPose(position: to, faceUp: faceUp);
        return CardPose(
          position: to.translate(height * sin(6 * pi * u) * (1 - u), 0),
          faceUp: faceUp,
        );
    }
  }

  /// The face to draw and the flip angle: the card turns edge-on at half
  /// time, then shows its new face.
  (bool, double) _flipAt(double t) {
    if (faceFrom == faceTo) return (faceTo, 0);
    final f = flipDuration <= 0
        ? (t >= flipStart ? 1.0 : 0.0)
        : ((t - flipStart) / flipDuration).clamp(0.0, 1.0);
    if (f <= 0) return (faceFrom, 0);
    if (f >= 1) return (faceTo, 0);
    final eased = Curves.easeInOut.transform(f);
    return eased < 0.5 ? (faceFrom, eased * pi) : (faceTo, (eased - 1) * pi);
  }
}
