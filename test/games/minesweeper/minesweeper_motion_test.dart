import 'package:all_for_games/games/minesweeper/minesweeper_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CellPose pose(CellMotionKind kind, double time) =>
      CellMotion(kind, start: 100, duration: 200).poseAt(time);

  test('a reveal waits covered, then ends open with its number shown', () {
    final waiting = pose(CellMotionKind.reveal, 50);
    expect((waiting.cover, waiting.coverScale, waiting.mark), (1, 1, 0));

    final done = pose(CellMotionKind.reveal, 300);
    expect(done.cover, 0);
    expect(done.mark, closeTo(1, 1e-9));
  });

  test('every motion ends at rest: no shake, no burst left', () {
    for (final kind in CellMotionKind.values) {
      final end = pose(kind, 300);
      expect(end.shake, closeTo(0, 1e-9), reason: '$kind');
      expect(end.burst ?? 1, 1, reason: '$kind');
      expect(end.glow, closeTo(0, 1e-9), reason: '$kind');
    }
  });

  test('a flag pops in, a flag taken back shrinks away', () {
    expect(pose(CellMotionKind.flag, 100).mark, 0);
    expect(pose(CellMotionKind.flag, 300).mark, closeTo(1, 1e-9));
    expect(pose(CellMotionKind.unflag, 300).mark, 0);
  });

  test('a mine of a lost game bursts once its cover is off', () {
    final early = pose(CellMotionKind.mine, 110);
    expect(early.burst, isNull);
    final later = pose(CellMotionKind.mine, 220);
    expect(later.cover, 0);
    expect(later.burst, inExclusiveRange(0, 1));
  });
}
