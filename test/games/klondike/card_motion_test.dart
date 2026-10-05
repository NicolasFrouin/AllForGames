import 'package:all_for_games/games/klondike/card_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

CardMotion flight({
  double start = 100,
  bool faceFrom = true,
  bool faceTo = true,
  Curve curve = Curves.easeOutCubic,
  CardMotion? next,
}) => CardMotion(
  kind: CardMotionKind.fly,
  from: const Offset(10, 20),
  to: const Offset(210, 320),
  start: start,
  duration: 300,
  height: 40,
  faceFrom: faceFrom,
  faceTo: faceTo,
  flipStart: start,
  flipDuration: 300,
  curve: curve,
  next: next,
);

void main() {
  test('a flight waits at its start and lands exactly on its target', () {
    final motion = flight();
    expect(motion.poseAt(0).position, const Offset(10, 20));
    expect(motion.poseAt(100).position, const Offset(10, 20));
    // Exact, so a landed card is exactly on its pile (no rounding from the arc).
    expect(motion.poseAt(400).position, const Offset(210, 320));
    expect(motion.poseAt(1000).position, const Offset(210, 320));
    expect(motion.end, 400);
  });

  test('a flight rises above the straight line and lifts the card', () {
    final middle = flight(curve: Curves.linear).poseAt(250);
    final straight = Offset.lerp(
      const Offset(10, 20),
      const Offset(210, 320),
      0.5,
    )!;
    expect(middle.position.dy, lessThan(straight.dy));
    expect(middle.scale, greaterThan(1));
    expect(middle.elevation, greaterThan(0.9));
  });

  test('a flip shows the old face, then the new one after half time', () {
    final motion = flight(faceFrom: false, faceTo: true);
    expect(motion.poseAt(100).faceUp, isFalse);
    expect(motion.poseAt(200).faceUp, isFalse);
    expect(motion.poseAt(300).faceUp, isTrue);
    expect(motion.poseAt(400).faceUp, isTrue);
    expect(motion.poseAt(400).flipAngle, 0);
  });

  test('a shifted motion goes on along the same path', () {
    final motion = flight();
    final shifted = motion.shifted(180);
    for (final t in [0.0, 50.0, 120.0, 400.0]) {
      expect(
        shifted.poseAt(t).position,
        motion.poseAt(t + 180).position,
        reason: 't=$t',
      );
    }
  });

  test('waiting, flying, then resting; a hop after a flight flies again', () {
    final hop = CardMotion(
      kind: CardMotionKind.hop,
      from: const Offset(210, 320),
      to: const Offset(210, 320),
      start: 600,
      duration: 500,
      height: 50,
      faceFrom: true,
      faceTo: true,
    );
    final motion = flight(next: hop);
    expect(motion.isWaitingAt(50), isTrue);
    expect(motion.isFlyingAt(250), isTrue);
    expect(motion.isFlyingAt(500), isFalse);
    expect(motion.poseAt(500).position, const Offset(210, 320));
    expect(motion.isFlyingAt(850), isTrue);
    expect(motion.segmentAt(850).start, 600);
    expect(motion.poseAt(850).position.dy, lessThan(320));
    expect(motion.poseAt(1100).position, const Offset(210, 320));
    expect(motion.end, 1100);
  });

  test('a shake stays on the table and ends where it began', () {
    const motion = CardMotion(
      kind: CardMotionKind.shake,
      from: Offset(5, 5),
      to: Offset(5, 5),
      start: 0,
      duration: 380,
      height: 8,
      faceFrom: true,
      faceTo: true,
    );
    expect(motion.isFlyingAt(100), isFalse);
    expect(motion.poseAt(100).position.dy, 5);
    expect(motion.poseAt(380).position, const Offset(5, 5));
  });
}
