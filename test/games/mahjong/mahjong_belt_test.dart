import 'package:all_for_games/games/mahjong/mahjong_belt.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_solver.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mahjong_test_helpers.dart';

/// A full block of 7 by 7 tiles, with three tiles on its middle row and a
/// stack of four on a place of the belt-to-be. With the belt: 52 tiles.
final block = MahjongLayout('block', [
  for (var y = 0; y < 14; y += 2)
    for (var x = 0; x < 14; x += 2) TilePosition(x, y, 0),
  for (var x = 4; x <= 8; x += 2) TilePosition(x, 6, 1),
  for (var z = 1; z < 4; z++) TilePosition(0, 4, z),
]);

/// A loop of six tiles: 0 1 2 on top, 5 4 3 under them; the belt goes
/// 0 → 1 → 2 → 3 → 4 → 5 → 0.
final loop = MahjongLayout(
  'loop',
  const [
    TilePosition(0, 0, 0),
    TilePosition(2, 0, 0),
    TilePosition(4, 0, 0),
    TilePosition(4, 2, 0),
    TilePosition(2, 2, 0),
    TilePosition(0, 2, 0),
  ],
  belt: const [0, 1, 2, 3, 4, 5],
);

/// The layouts a player can get a belt on, for [seed].
Iterable<MahjongLayout> beltLayouts(int seed) => [
  for (final difficulty in MahjongDifficulty.values)
    for (final shape in MahjongShape.values)
      withBelt(difficulty.layoutFor(shape, seed), clockwise: seed.isEven),
];

void main() {
  group('the belt', () {
    test('is a loop on the table, as wide as the board, one row in from its '
        'top and bottom', () {
      final layout = withBelt(block, clockwise: true);
      final cells = {for (final p in layout.belt) layout.positions[p]};

      expect(layout.id, 'belt-block');
      expect(layout.belt, hasLength(7 + 7 + 2 * 3));
      expect(cells.map((p) => p.z), everyElement(0));
      expect(cells.map((p) => p.y).toSet(), {2, 4, 6, 8, 10});
      expect(cells.map((p) => p.x).toSet(), hasLength(7));
      expect(
        cells.where((p) => p.y == 6).map((p) => p.x),
        unorderedEquals([0, 12]),
      );
      for (final p in layout.belt) {
        expect(layout.above[p], isEmpty, reason: 'nothing lies on the belt');
      }
      expect(layout.positions, contains(const TilePosition(6, 6, 1)));
      expect(layout.positions.where((p) => p.x == 0 && p.y == 4), [
        const TilePosition(0, 4, 0),
      ], reason: 'the stack on the belt went');
      expect(layout.length, 52);
    });

    test('turns clockwise on screen, or the other way', () {
      final clockwise = withBelt(block, clockwise: true);
      final other = withBelt(block, clockwise: false);
      expect(clockwise.beltClockwise, isTrue);
      expect(other.beltClockwise, isFalse);
      // Along the top row, from left to right.
      final [first, second, ...] = clockwise.belt;
      expect(clockwise.positions[first], const TilePosition(0, 2, 0));
      expect(clockwise.positions[second], const TilePosition(2, 2, 0));
      expect([
        for (final p in other.belt) other.positions[p],
      ], [for (final p in clockwise.belt) clockwise.positions[p]].reversed);
    });

    test('keeps no stack more than three layers above a tile beside it', () {
      for (var seed = 1; seed <= 20; seed++) {
        for (final layout in beltLayouts(seed)) {
          int height(int x, int y) => layout.positions.fold(
            0,
            (h, q) => q.x == x && q.y == y && q.z >= h ? q.z + 1 : h,
          );
          for (final p in layout.positions) {
            for (final (dx, dy) in [(-2, 0), (2, 0), (0, -2), (0, 2)]) {
              final beside = height(p.x + dx, p.y + dy);
              if (beside == 0) continue;
              expect(p.z + 1 - beside, lessThanOrEqualTo(3), reason: '$p');
            }
          }
          expect(layout.length % 4, 0);
          expect(layout.length, lessThanOrEqualTo(144));
        }
      }
    });
  });

  group('a move turns the belt', () {
    test('a match moves every tile of the belt one place along it', () {
      final state = MahjongState(
        layout: loop,
        faces: [dots1, dots2, dots3, dots3, dots2, dots1],
        slots: [0, 1, 2, 3, 4, 5],
      );
      // 0 and 5 sit on the left end: free.
      final next = state.match(0, 5)!;
      expect(next.slots, [MahjongState.empty, MahjongState.empty, 1, 2, 3, 4]);
      // 4 lay between 3 and 5; it came to the left end.
      expect(state.isFree(4), isFalse);
      expect(next.isFree(4), isTrue);
    });

    test('a pick moves them too, a tile into the tray or not', () {
      final tray = TrayState(
        MahjongState(
          layout: loop,
          faces: [dots1, dots2, dots3, dots3, dots2, dots1],
          slots: [0, 1, 2, 3, 4, 5],
        ),
        const [],
      );
      final next = tray.pick(0)!;
      expect(next.tray, [0]);
      expect(next.board.slots, [5, MahjongState.empty, 1, 2, 3, 4]);
      expect(next.pick(5)!.board.slots, [
        4,
        MahjongState.empty,
        MahjongState.empty,
        1,
        2,
        3,
      ]);
    });
  });

  group('deals with a belt', () {
    test('are won by their order, which follows the turns of the belt', () {
      var differs = 0;
      for (var seed = 1; seed <= 6; seed++) {
        for (final layout in beltLayouts(seed)) {
          final deal = generateDeal(layout, seed, trapPercent: 50);
          expect(deal.state.isSolvedBy(deal.solution), isTrue);
          final tray = generateTrayDeal(
            layout,
            seed,
            MahjongDifficulty.hard.tray,
          );
          expect(
            TrayState(tray.state, const []).isSolvedBy(tray.solution),
            isTrue,
          );
          // The same tiles on a belt that stands still.
          final still = MahjongState(
            layout: MahjongLayout(layout.id, layout.positions),
            faces: deal.state.faces,
            slots: deal.state.slots,
          );
          if (!still.isSolvedBy(deal.solution)) differs++;
        }
      }
      expect(differs, greaterThan(0), reason: 'the belt matters');
    });

    test('the solvers find wins that replay', () {
      var found = 0;
      for (var seed = 1; seed <= 10; seed++) {
        final layout = withBelt(
          MahjongDifficulty.medium.layoutFor(MahjongShape.generated, seed),
          clockwise: seed.isOdd,
        );
        final deal = generateDeal(layout, seed, trapPercent: 15);
        if (solveBelt(deal.state) case final order?) {
          found++;
          expect(deal.state.isSolvedBy(order), isTrue);
        }
        final tray = TrayState(
          generateTrayDeal(layout, seed, MahjongDifficulty.medium.tray).state,
          const [],
        );
        final picks = solveBeltTray(tray)!;
        expect(tray.isSolvedBy(picks), isTrue);
      }
      expect(found, greaterThanOrEqualTo(8));
    });

    test('the order of the deal stays when the player follows it, and is '
        'checked again when not', () {
      final layout = withBelt(
        MahjongDifficulty.medium.layoutFor(MahjongShape.generated, 3),
        clockwise: true,
      );
      final deal = generateDeal(layout, 3, trapPercent: 15);
      final [(a, b), ...rest] = deal.solution;
      expect(mendSolution(deal.state.match(a, b)!, deal.solution, a, b), rest);

      for (final (c, d) in deal.state.freePairs) {
        final after = deal.state.match(c, d)!;
        final mended = mendSolution(after, deal.solution, c, d);
        if (mended != null) expect(after.isSolvedBy(mended), isTrue);
      }
    });
  });

  test('without a belt, a deal is the same as before', () {
    final layout = MahjongDifficulty.hard.layout();
    expect(layout.turned(<int>[1, 2, 3]), [1, 2, 3]);
    final deal = generateDeal(layout, 1);
    final occupied = [for (final _ in layout.positions) true];
    for (final (a, b) in deal.solution) {
      expect(layout.isFree(a, occupied) && layout.isFree(b, occupied), isTrue);
      occupied[a] = false;
      occupied[b] = false;
    }
  });
}
