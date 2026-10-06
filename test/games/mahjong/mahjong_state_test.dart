import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mahjong_test_helpers.dart';

void main() {
  group('a tile is free', () {
    test('at either end of a row, not in the middle', () {
      final state = board(row(4), [dots1, dots2, dots2, dots1]);

      expect(
        [for (var id = 0; id < 4; id++) state.isFree(id)],
        [true, false, false, true],
      );
    });

    test('once a tile beside it is gone', () {
      final state = board(row(3), [dots1, dots2, dots1]).match(0, 2)!;

      expect(state.isFree(1), isTrue);
    });

    test('only without a tile on it, even partly', () {
      // A tile on two tiles, half on each.
      final state = board(layoutOf([(0, 0, 0), (2, 0, 0), (1, 0, 1)]), [
        dots1,
        dots1,
        dots2,
      ]);

      expect(state.isFree(0), isFalse);
      expect(state.isFree(1), isFalse);
      expect(state.isFree(2), isTrue);
    });

    test('next to a tile half a row away, not beside it', () {
      // The Turtle's head: between two rows, it blocks the end of both.
      final state = board(layoutOf([(0, 1, 0), (2, 0, 0), (4, 0, 0)]), [
        dots1,
        dots2,
        dots1,
      ]);

      expect(state.isFree(1), isFalse);
      expect(state.isFree(2), isTrue);
    });
  });

  group('matching', () {
    test('removes two free tiles of the same face', () {
      final state = board(row(3), [dots1, dots2, dots1]);

      final next = state.match(0, 2)!;

      expect(next.tileCount, 1);
      expect(next.positionOf(0), isNull);
      expect(next.positionOf(1), 1);
      expect(state.tileCount, 3, reason: 'immutable');
    });

    test('refuses other faces, blocked tiles and a tile with itself', () {
      final state = board(row(4), [dots1, dots1, dots2, dots2]);

      expect(state.match(0, 3), isNull, reason: 'other faces');
      expect(state.match(0, 1), isNull, reason: 'the second one is blocked');
      expect(state.match(0, 0), isNull);
    });

    test('only tiles of the same face match, flowers and seasons too', () {
      expect(board(row(2), [flower, flower]).match(0, 1), isNotNull);
      expect(board(row(2), [season, season]).match(0, 1), isNotNull);
      expect(board(row(2), [flower, season]).match(0, 1), isNull);
    });

    test('the last pair wins the game', () {
      final state = board(row(2), [bamboo1, bamboo1]).match(0, 1)!;

      expect(state.isWon, isTrue);
      expect(state.isStuck, isFalse);
    });
  });

  test('free pairs are the free tiles that match', () {
    final state = board(row(4), [dots1, dots2, dots1, dots1]);

    // 0 and 3 are free; 1 and 2 are not.
    expect(state.freePairs, [(0, 3)]);
  });

  test('a board with tiles and no free pair is stuck', () {
    // The only partner of the top tile is under it.
    final state = board(layoutOf([(0, 0, 0), (0, 0, 1)]), [dots1, dots1]);

    expect(state.freePairs, isEmpty);
    expect(state.isStuck, isTrue);
  });

  test('an order of pairs clears the board only if each pair is free', () {
    final state = board(row(4), [dots1, dots2, dots2, dots1]);

    expect(state.isSolvedBy([(0, 3), (1, 2)]), isTrue);
    expect(state.isSolvedBy([(1, 2), (0, 3)]), isFalse);
    expect(state.isSolvedBy([(0, 3)]), isFalse, reason: 'tiles are left');
  });

  group('tile faces', () {
    test('36 faces in suit order, with their ranks', () {
      expect(TileFace.of(TileSuit.dots, 1).code, 0);
      expect(TileFace.of(TileSuit.flowers, 1).code, 34);
      expect(TileFace.of(TileSuit.seasons, 1).code, TileFace.count - 1);
      for (var code = 0; code < TileFace.count; code++) {
        final face = TileFace(code);
        expect(TileFace.of(face.suit, face.rank), face);
      }
    });
  });

  group('layouts', () {
    test('the Turtle has 144 tiles on five layers, the pyramid 72', () {
      expect(turtleLayout.length, 144);
      expect(turtleLayout.layers, 5);
      expect(pyramidLayout.length, 72);
      expect(pyramidLayout.layers, 4);
    });

    test('the top of the Turtle lies on the four tiles under it', () {
      final top = turtleLayout.positions.indexOf(const TilePosition(13, 7, 4));
      final under = [
        for (final (i, p) in turtleLayout.positions.indexed)
          if (turtleLayout.above[i].contains(top)) p,
      ];

      expect(under, hasLength(4 + 4 + 4 + 4));
      expect(under.where((p) => p.z == 3), hasLength(4));
    });

    test('transposed, rows become columns, and back', () {
      final transposed = turtleLayout.toTransposed();

      expect(transposed.transposed, isTrue);
      expect(transposed.positions.first, const TilePosition(0, 2, 0));
      expect((transposed.width, transposed.height), (16, 30));
      expect(transposed.toTransposed().positions, turtleLayout.positions);
      expect(
        layoutById('turtle', transposed: true)!.positions,
        transposed.positions,
      );
    });

    test('positions never overlap on a layer', () {
      for (final layout in mahjongLayouts) {
        for (final (i, p) in layout.positions.indexed) {
          for (final q in layout.positions.skip(i + 1)) {
            expect(p.z == q.z && p.overlaps(q), isFalse, reason: '$p $q');
          }
        }
      }
    });
  });
}
