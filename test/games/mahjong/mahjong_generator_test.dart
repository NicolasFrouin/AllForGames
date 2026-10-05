import 'dart:math';

import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mahjong_test_helpers.dart';

/// The first faces of the Medium deal of seed 1, as the Dart VM deals it.
/// The e2e tests check that the web deals the same.
const seed1MediumFaces = [
  4, 33, 27, 1, 32, 36, 18, 15, 0, 25, 6, 12, //
  11, 18, 29, 20, 10, 19, 9, 4, 25, 30, 5, 37,
];

MahjongDeal deal(MahjongDifficulty difficulty, int seed, {bool t = false}) =>
    generateDeal(
      difficulty.layout(transposed: t),
      seed,
      trapPercent: difficulty.trapPercent,
    );

/// Plays [state] at random until it is stuck (or won).
MahjongState playUntilStuck(MahjongState state, Random random) {
  while (state.freePairs.isNotEmpty) {
    final (a, b) = state.freePairs[random.nextInt(state.freePairs.length)];
    state = state.match(a, b)!;
  }
  return state;
}

void main() {
  test('every deal of every level, both ways, can be cleared', () {
    for (final difficulty in MahjongDifficulty.values) {
      for (final transposed in [false, true]) {
        for (var seed = 1; seed <= 60; seed++) {
          final (:state, :solution) = deal(difficulty, seed, t: transposed);
          expect(
            state.isSolvedBy(solution),
            isTrue,
            reason: '${difficulty.name} $seed $transposed',
          );
        }
      }
    }
  });

  test('a seed always gives the same deal, another seed another one', () {
    final first = deal(MahjongDifficulty.medium, 1).state;

    expect(first.faces.take(seed1MediumFaces.length), seed1MediumFaces);
    expect(deal(MahjongDifficulty.medium, 1).state.faces, first.faces);
    expect(deal(MahjongDifficulty.medium, 2).state.faces, isNot(first.faces));
  });

  test('a Turtle deal uses a full set, a pyramid deal half of one', () {
    List<int> sorted(List<int> faces) => [...faces]..sort();
    final fullSet = sorted([
      for (final (a, b) in TileFace.setPairs()) ...[a, b],
    ]);

    expect(sorted(deal(MahjongDifficulty.hard, 7).state.faces), fullSet);

    final pyramid = deal(MahjongDifficulty.easy, 7).state.faces;
    expect(pyramid, hasLength(72));
    for (final face in pyramid.toSet()) {
      final count = pyramid.where((f) => f == face).length;
      final suit = TileFace(face).suit;
      final single = suit == TileSuit.flowers || suit == TileSuit.seasons;
      expect(count, single ? 1 : 4, reason: '$face');
    }
  });

  test('positions that cannot be cleared have no removal order', () {
    // A tile on its only partner.
    final layout = layoutOf([(0, 0, 0), (0, 0, 1)]);

    expect(
      removalOrder(layout, [true, true], DealRandom(1), attempts: 20),
      isNull,
    );
  });

  group('shuffle', () {
    test('keeps the tiles and the shape of the board, and can be cleared', () {
      var sameShape = 0;
      for (var seed = 1; seed <= 40; seed++) {
        final stuck = playUntilStuck(
          deal(MahjongDifficulty.hard, seed).state,
          Random(seed),
        );
        if (stuck.isWon) continue;

        final (:state, :solution) = shuffleTiles(stuck, DealRandom(seed));

        expect(state.isSolvedBy(solution), isTrue, reason: '$seed');
        expect(state.tileIds.toSet(), stuck.tileIds.toSet());
        bool shape(MahjongState s) => listEquals(
          [for (final id in s.slots) id != MahjongState.empty],
          [for (final id in stuck.slots) id != MahjongState.empty],
        );
        if (shape(state)) sameShape++;
      }
      // Other shapes only when the tiles lie on each other.
      expect(sameShape, greaterThan(30));
    });

    test('moves tiles that would stay stuck down to the table', () {
      // The last two tiles lie on each other: no shuffle on these places
      // can be cleared.
      final full = deal(MahjongDifficulty.easy, 3).state;
      final layout = full.layout;
      final top = layout.positions.indexWhere((p) => p.z == 3);
      final under = layout.positions.indexWhere(
        (p) => p.z == 0 && p.overlaps(layout.positions[top]),
      );
      final stuck = full.withSlots([
        for (var p = 0; p < layout.length; p++)
          p == top
              ? 0
              : p == under
              ? 1
              : MahjongState.empty,
      ]);

      final (:state, :solution) = shuffleTiles(
        MahjongState(
          layout: layout,
          faces: [dots1, dots1, ...full.faces.skip(2)],
          slots: stuck.slots,
        ),
        DealRandom(1),
      );

      expect(state.isSolvedBy(solution), isTrue);
      expect(
        [
          for (final id in state.tileIds)
            layout.positions[state.positionOf(id)!].z,
        ],
        [0, 0],
      );
    });
  });

  test('every layout can be dealt', () {
    for (final layout in mahjongLayouts) {
      expect(generateDeal(layout, 1).state.tileCount, layout.length);
    }
  });
}
