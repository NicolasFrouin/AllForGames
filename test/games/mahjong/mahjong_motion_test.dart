import 'package:all_for_games/games/mahjong/mahjong_board.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

TileMotion motion(TileMotionKind kind, {Offset from = Offset.zero}) =>
    TileMotion(
      kind: kind,
      start: 100,
      duration: 400,
      from: from,
      to: const Offset(30, 0),
      height: 20,
    );

void main() {
  group('motions', () {
    test('a dropped tile is hidden until its turn, then lands in place', () {
      final drop = motion(TileMotionKind.drop);

      expect(drop.poseAt(50).opacity, 0);
      expect(drop.poseAt(150).offset.dy, lessThan(0), reason: 'falling');
      final landed = drop.poseAt(drop.end);
      expect(
        (landed.offset, landed.scale, landed.opacity),
        (Offset.zero, 1.0, 1.0),
      );
    });

    test('a matched tile flies toward its partner and is gone at the end', () {
      final vanish = motion(TileMotionKind.vanish);

      expect(vanish.poseAt(0).opacity, 1);
      final end = vanish.poseAt(vanish.end);
      expect(end.offset, const Offset(30, 0));
      expect(end.opacity, 0);
      expect(end.scale, lessThan(1));
    });

    test('a shuffled tile flies on an arc to its new place', () {
      final fly = motion(TileMotionKind.fly, from: const Offset(-50, 40));

      expect(fly.poseAt(100).offset, const Offset(-50, 40));
      expect(fly.poseAt(300).elevation, closeTo(1, 0.01));
      expect(fly.isAirborneAt(300), isTrue);
      expect(fly.isAirborneAt(600), isFalse);
      expect(
        (fly.poseAt(500).offset - const Offset(30, 0)).distance,
        closeTo(0, 1e-9),
      );
    });

    test('a hint pulses three times, then stops', () {
      final pulse = motion(TileMotionKind.pulse);
      final glows = [
        for (var t = 100.0; t <= 500; t += 400 / 12) pulse.poseAt(t).glow,
      ];

      expect(glows.where((glow) => glow > 0.9), hasLength(3));
      expect(pulse.poseAt(pulse.end).glow, closeTo(0, 1e-9));
      expect(pulse.poseAt(2000).glow, closeTo(0, 1e-9));
    });

    test('a shake ends where it started', () {
      final shake = motion(TileMotionKind.shake);

      expect(shake.poseAt(180).offset, isNot(Offset.zero));
      expect(shake.poseAt(shake.end).offset.dx, closeTo(0, 1e-9));
    });

    test('shifted motions keep their pose at the same moment', () {
      final fly = motion(TileMotionKind.fly, from: const Offset(-50, 40));

      expect(fly.shifted(200).poseAt(100).offset, fly.poseAt(300).offset);
    });
  });

  group('flips', () {
    test('a turn goes to a quarter turn, then comes back from the other '
        'side: the face is never mirrored', () {
      final turn = motion(TileMotionKind.turn);
      final mid = turn.flipMid!;
      expect(mid, 300);

      expect(turn.poseAt(100).flipAngle, 0);
      expect(turn.poseAt(mid - 20).flipAngle, inExclusiveRange(1.2, 1.5708));
      expect(turn.poseAt(mid + 20).flipAngle, inExclusiveRange(-1.5708, -1.2));
      final end = turn.poseAt(turn.end);
      expect((end.flipAngle, end.offset, end.scale), (0.0, Offset.zero, 1.0));
    });

    test('a tile taken at once flips where it lies, then plays its motion', () {
      final vanish = motion(
        TileMotionKind.vanish,
        from: const Offset(5, 0),
      ).turnedFirst(500);
      expect(vanish.end, 1000);
      expect(vanish.flipMid, 100 + TileMotion.flipDuration / 2);

      final flipping = vanish.poseAt(250);
      expect(flipping.flipAngle, isNot(0));
      expect(flipping.offset, const Offset(5, 0), reason: 'in its place');
      expect(flipping.opacity, 1);
      // After the flip, the face shows still until the motion starts.
      expect(vanish.poseAt(560).flipAngle, 0);

      final after = motion(
        TileMotionKind.vanish,
        from: const Offset(5, 0),
      ).shifted(-500);
      for (final time in [650.0, 800.0, 1000.0]) {
        expect(vanish.poseAt(time).offset, after.poseAt(time).offset);
        expect(vanish.poseAt(time).opacity, after.poseAt(time).opacity);
      }
      expect(vanish.shifted(50).flipMid, vanish.flipMid! - 50);
    });

    test('a motion without a flip has no side to swap', () {
      expect(motion(TileMotionKind.fly).flipMid, isNull);
    });
  });

  group('board geometry', () {
    test('a tall phone swaps the Turtle, a wide screen does not', () {
      expect(
        MahjongBoardGeometry.prefersTransposed(
          const Size(360, 520),
          turtleLayout,
        ),
        isTrue,
      );
      expect(
        MahjongBoardGeometry.prefersTransposed(
          const Size(1280, 700),
          turtleLayout,
        ),
        isFalse,
      );
    });

    test('the board fits its room, tiles taller than wide', () {
      for (final size in const [Size(360, 520), Size(1280, 700)]) {
        for (final layout in [turtleLayout, turtleLayout.toTransposed()]) {
          final geometry = MahjongBoardGeometry.fit(size, layout);

          expect(geometry.size.width, lessThanOrEqualTo(size.width + 0.01));
          expect(geometry.size.height, lessThanOrEqualTo(size.height + 0.01));
          expect(geometry.tileHeight, greaterThan(geometry.tileWidth));
          for (final p in layout.positions) {
            final rect = geometry.faceRect(p);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(
              rect.bottom + geometry.depth,
              lessThanOrEqualTo(geometry.size.height + 0.01),
            );
          }
        }
      }
    });
  });
}
