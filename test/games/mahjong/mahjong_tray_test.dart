import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mahjong_test_helpers.dart';

final dots4 = TileFace.of(TileSuit.dots, 4).code;

/// The first faces of the Medium tray deal of seed 1, as the Dart VM deals
/// it. The e2e tests and `deals_on_web_test.dart` check that the web deals
/// the same.
const seed1MediumTrayFaces = [
  8, 27, 27, 28, 1, 31, 17, 20, 32, 34, 16, 19, //
  26, 26, 14, 2, 19, 6, 8, 7, 24, 13, 1, 11,
];

/// A tray game of [faces] in a row, with an empty tray.
TrayState trayRow(List<int> faces) =>
    TrayState(board(row(faces.length), faces), const []);

/// A stack of tiles on one place, the first face at the bottom.
TrayState trayStack(List<int> faces) => TrayState(
  board(layoutOf([for (var z = 0; z < faces.length; z++) (0, 0, z)]), faces),
  const [],
);

TrayDeal trayDeal(MahjongDifficulty difficulty, int seed, {bool t = false}) =>
    generateTrayDeal(difficulty.layout(transposed: t), seed, difficulty.tray);

/// The most tiles the tray holds while [order] is picked from [state].
int mostHeld(TrayState state, List<int> order) {
  var most = 0;
  for (final id in order) {
    state = state.pick(id)!;
    if (state.tray.length > most) most = state.tray.length;
  }
  return most;
}

void main() {
  test('tray deals rarely put a tile right on a tile of its face', () {
    // As often as chance would (about 3%); always under the first tile of a
    // blind pair, it was a quarter of the upper tiles on Medium and Hard.
    for (final difficulty in MahjongDifficulty.values) {
      for (final shape in MahjongShape.values) {
        var stacked = 0;
        var upper = 0;
        for (var seed = 1; seed <= 30; seed++) {
          final state = generateTrayDeal(
            difficulty.layoutFor(shape, seed),
            seed,
            difficulty.tray,
          ).state;
          final places = {
            for (final (i, p) in state.layout.positions.indexed) p: i,
          };
          for (final (i, p) in state.layout.positions.indexed) {
            if (p.z == 0) continue;
            upper++;
            final under = places[TilePosition(p.x, p.y, p.z - 1)];
            if (under != null && state.faces[under] == state.faces[i]) {
              stacked++;
            }
          }
        }
        expect(
          stacked / upper,
          lessThan(0.06),
          reason: '${difficulty.name} ${shape.name}',
        );
      }
    }
  });

  group('picking', () {
    test('a free tile goes into the tray, a blocked one cannot', () {
      final state = trayRow([dots1, dots2, dots1]);

      expect(state.pick(1), isNull);
      final next = state.pick(0)!;

      expect(next.tray, [0]);
      expect(next.board.positionOf(0), isNull);
      expect(next.tileCount, 3);
      expect(state.tray, isEmpty, reason: 'immutable');
    });

    test('a tile of a face in the tray clears both', () {
      final state = trayRow([dots1, dots2, dots1]).pick(0)!.pick(2)!;

      expect(state.tray, isEmpty);
      expect(state.tileCount, 1);
      expect(state.board.isFree(1), isTrue);
    });

    test('the tray keeps its order when a pair in it clears', () {
      final state = trayRow([dots1, dots2, dots3, dots2]).pick(0)!.pick(3)!;
      expect(state.tray, [0, 3]);

      expect(state.pick(2)!.pick(1)!.tray, [0, 2]);
    });

    test('four tiles with no pair fill the tray: the game is lost', () {
      final state = trayStack([dots4, dots3, dots2, dots1]);

      final three = state.pick(3)!.pick(2)!.pick(1)!;
      expect(three.isLost, isFalse);
      expect(three.isStuck, isTrue, reason: 'any pick loses');

      final lost = three.pick(0)!;
      expect(lost.isLost, isTrue);
      expect(lost.pick(0), isNull);
    });

    test('the board and the tray empty win the game', () {
      final state = trayRow([dots1, dots1]).pick(0)!;
      expect(state.isWon, isFalse);

      expect(state.pick(1)!.isWon, isTrue);
    });

    test('free matches are the free tiles of a face in the tray', () {
      final state = trayRow([dots1, dots2, dots2, dots1]).pick(0)!;

      expect(state.freeMatches, [3]);
      expect(state.partnerOf(3), 0);
      expect(state.partnerOf(1), isNull);
    });
  });

  test('an order of picks wins only if each tile is free in its turn and '
      'the tray never fills', () {
    final state = trayStack([dots1, dots2, dots3, dots4, dots1, dots2]);

    // From the top: the 2 and the 1 wait, the 4 and the 3 too: full.
    expect(state.isSolvedBy([5, 4, 3, 2, 1, 0]), isFalse);
    expect(
      trayRow([dots1, dots2, dots2, dots1]).isSolvedBy([0, 3, 1, 2]),
      isTrue,
    );
    expect(
      trayRow([dots1, dots2, dots2, dots1]).isSolvedBy([1, 0, 2, 3]),
      isFalse,
    );
    expect(trayRow([dots1, dots1]).isSolvedBy([0]), isFalse);
  });

  group('deals', () {
    test('every deal of every level, both ways, is won by its order, '
        'which never holds more tiles than the level says', () {
      for (final difficulty in MahjongDifficulty.values) {
        for (final transposed in [false, true]) {
          for (var seed = 1; seed <= 40; seed++) {
            final (:state, :solution) = trayDeal(
              difficulty,
              seed,
              t: transposed,
            );
            final start = TrayState(state, const []);
            final reason = '${difficulty.name} $seed $transposed';

            expect(start.isSolvedBy(solution), isTrue, reason: reason);
            expect(
              mostHeld(start, solution),
              lessThanOrEqualTo(difficulty.tray.held),
              reason: reason,
            );
          }
        }
      }
    });

    test('use four tiles of each face', () {
      final turtle = trayDeal(MahjongDifficulty.hard, 3).state.faces;
      for (var face = 0; face < TileFace.count; face++) {
        expect(turtle.where((f) => f == face), hasLength(4), reason: '$face');
      }

      final pyramid = trayDeal(MahjongDifficulty.easy, 3).state.faces;
      expect(pyramid.toSet(), hasLength(18));
      for (final face in pyramid.toSet()) {
        expect(pyramid.where((f) => f == face), hasLength(4), reason: '$face');
      }
    });

    test('a seed always gives the same deal, another seed another one', () {
      final first = trayDeal(MahjongDifficulty.medium, 1);
      expect(
        first.state.faces.take(seed1MediumTrayFaces.length),
        seed1MediumTrayFaces,
      );

      expect(
        trayDeal(MahjongDifficulty.medium, 1).state.faces,
        first.state.faces,
      );
      expect(trayDeal(MahjongDifficulty.medium, 1).solution, first.solution);
      expect(
        trayDeal(MahjongDifficulty.medium, 2).state.faces,
        isNot(first.state.faces),
      );
    });
  });

  group('solver', () {
    test('finds an order that wins a deal, also once tiles wait', () {
      for (var seed = 1; seed <= 10; seed++) {
        final (:state, :solution) = trayDeal(MahjongDifficulty.hard, seed);
        // The first picks of the deal's order, with tiles in the tray.
        var start = TrayState(state, const []);
        for (final id in solution.take(9)) {
          start = start.pick(id)!;
        }

        final found = solveTray(start);

        expect(found, isNotNull, reason: '$seed');
        expect(start.isSolvedBy(found!), isTrue, reason: '$seed');
      }
    });

    test('finds none when four faces must wait on each other', () {
      // To reach the 1 at the bottom, the 4, the 3 and the 2 wait too.
      final state = trayStack([
        dots4,
        dots3,
        dots2,
        dots1,
        dots4,
        dots3,
        dots2,
        dots1,
      ]);

      expect(solveTray(trayStack([dots1, dots2, dots1, dots2])), isNotNull);
      expect(solveTray(state), isNull);
    });
  });
}
