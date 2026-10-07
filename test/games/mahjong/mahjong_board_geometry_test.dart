import 'dart:ui';

import 'package:all_for_games/games/mahjong/mahjong_board.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

const _eps = 0.001;

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - _eps &&
    inner.top >= outer.top - _eps &&
    inner.right <= outer.right + _eps &&
    inner.bottom <= outer.bottom + _eps;

void main() {
  // A phone held upright, a wide window, and a short one.
  const rooms = [Size(400, 700), Size(1200, 700), Size(900, 260)];
  for (final difficulty in MahjongDifficulty.values) {
    for (final room in rooms) {
      for (final side in MahjongTraySide.values) {
        test('${difficulty.name} in $room: the tray fits on the ${side.name} '
            'of the tiles', () {
          final layout = difficulty.layout();
          final geometry = MahjongBoardGeometry.fit(room, layout, tray: side);
          final faces = layout.positions
              .map(geometry.faceRect)
              .reduce((a, b) => a.expandToInclude(b));
          // The tiles show their thickness below and to the right.
          final tiles = Rect.fromLTRB(
            faces.left,
            faces.top,
            faces.right + geometry.depth,
            faces.bottom + geometry.depth,
          );
          final tray = geometry.trayRect!;
          final slots = geometry.traySlots;

          expect(geometry.size.width, lessThanOrEqualTo(room.width + _eps));
          expect(geometry.size.height, lessThanOrEqualTo(room.height + _eps));
          final whole = Offset.zero & geometry.size;
          expect(_inside(tiles, whole), isTrue, reason: '$tiles in $whole');
          expect(_inside(tray, whole), isTrue, reason: '$tray in $whole');
          expect(switch (side) {
            MahjongTraySide.top => tray.bottom < tiles.top,
            MahjongTraySide.bottom => tray.top > tiles.bottom,
            MahjongTraySide.left => tray.right < tiles.left,
            MahjongTraySide.right => tray.left > tiles.right,
          }, isTrue);
          final across =
              side == MahjongTraySide.left || side == MahjongTraySide.right
              ? [for (final slot in slots) slot.left]
              : [for (final slot in slots) slot.top];
          expect(across.toSet(), hasLength(1), reason: 'places in a line');
          for (final slot in slots) {
            expect(_inside(slot, tray), isTrue);
          }
        });
      }
    }
  }
}
