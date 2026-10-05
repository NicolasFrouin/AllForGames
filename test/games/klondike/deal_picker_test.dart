import 'dart:math';

import 'package:all_for_games/games/klondike/deal_picker.dart';
import 'package:all_for_games/games/klondike/klondike_deals.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

const easy = KlondikeDifficulty.easy;
const medium = KlondikeDifficulty.medium;
const hard = KlondikeDifficulty.hard;

Set<int> seedsOf(int drawCount, KlondikeDifficulty difficulty) =>
    klondikeDeals[drawCount]![difficulty.name]!.toSet();

int pick(
  int drawCount,
  KlondikeDifficulty difficulty,
  Set<int> played, [
  int randomSeed = 0,
]) => pickDealSeed(
  drawCount: drawCount,
  difficulty: difficulty,
  played: played,
  random: Random(randomSeed),
);

void main() {
  test('picks only seeds of the list of the draw count and difficulty', () {
    for (final drawCount in [1, 3]) {
      for (final difficulty in KlondikeDifficulty.values) {
        final picked = {
          for (var i = 0; i < 100; i++) pick(drawCount, difficulty, {}, i),
        };
        expect(seedsOf(drawCount, difficulty), containsAll(picked));
        expect(picked.length, greaterThan(50), reason: 'random seeds');
      }
    }
  });

  test('skips played seeds', () {
    final left = seedsOf(1, hard).elementAt(200);
    final played = seedsOf(1, hard)..remove(left);
    for (var i = 0; i < 20; i++) {
      expect(pick(1, hard, played, i), left);
    }
  });

  test('picks any seed of the list again once all were played', () {
    final played = seedsOf(1, easy);
    final picked = {for (var i = 0; i < 20; i++) pick(1, easy, played, i)};
    expect(played, containsAll(picked));
    expect(picked.length, greaterThan(1));
  });

  test('played seeds of other lists do not count', () {
    // Every seed but one of the draw 3 medium list, and all the others.
    final left = seedsOf(3, medium).first;
    final played = {
      for (final drawCount in [1, 3])
        for (final difficulty in KlondikeDifficulty.values)
          ...seedsOf(drawCount, difficulty),
    }..remove(left);
    expect(pick(3, medium, played), left);
    // Every draw 3 hard seed was played: any of them again.
    expect(seedsOf(3, hard), contains(pick(3, hard, played)));
  });

  group('difficultyOfSeed', () {
    test('finds the list of a seed, by draw count', () {
      for (final drawCount in [1, 3]) {
        for (final difficulty in KlondikeDifficulty.values) {
          final seeds = klondikeDeals[drawCount]![difficulty.name]!;
          for (final seed in [seeds.first, seeds.last]) {
            expect(difficultyOfSeed(drawCount, seed), difficulty);
          }
        }
      }
    });

    test('is null for a seed in no list', () {
      final listed = {
        for (final lists in klondikeDeals.values)
          for (final seeds in lists.values) ...seeds,
      };
      final unlisted = [
        for (var seed = 1; seed < 100; seed++)
          if (!listed.contains(seed)) seed,
      ].first;
      expect(difficultyOfSeed(1, unlisted), isNull);
      expect(difficultyOfSeed(3, unlisted), isNull);
      expect(difficultyOfSeed(1, 1 << 31), isNull);
      expect(difficultyOfSeed(2, seedsOf(1, easy).first), isNull);
    });

    test('depends on the draw count', () {
      // A seed only listed for draw 3.
      final draw1 = {for (final seeds in klondikeDeals[1]!.values) ...seeds};
      final seed = seedsOf(3, hard).firstWhere((s) => !draw1.contains(s));
      expect(difficultyOfSeed(3, seed), hard);
      expect(difficultyOfSeed(1, seed), isNull);
    });
  });
}
