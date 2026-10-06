import 'dart:math';

import 'package:all_for_games/games/tripeaks/tripeaks_deal_picker.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deals.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

Set<int> seedsOf(TriPeaksDifficulty difficulty) =>
    triPeaksDeals[difficulty.name]!.toSet();

int pick(TriPeaksDifficulty difficulty, Set<int> played, [int random = 0]) =>
    pickTriPeaksSeed(
      difficulty: difficulty,
      played: played,
      random: Random(random),
    );

void main() {
  test('picks only seeds of the list of the difficulty', () {
    for (final difficulty in TriPeaksDifficulty.values) {
      final picked = {for (var i = 0; i < 100; i++) pick(difficulty, {}, i)};
      expect(seedsOf(difficulty), containsAll(picked));
      expect(picked.length, greaterThan(50), reason: 'random seeds');
    }
  });

  test('skips played seeds, of any list', () {
    const hard = TriPeaksDifficulty.hard;
    final left = seedsOf(hard).elementAt(100);
    final played = {
      for (final difficulty in TriPeaksDifficulty.values)
        ...seedsOf(difficulty),
    }..remove(left);
    for (var i = 0; i < 20; i++) {
      expect(pick(hard, played, i), left);
    }
  });

  test('picks any seed of the list again once all were played', () {
    const easy = TriPeaksDifficulty.easy;
    final played = seedsOf(easy);
    final picked = {for (var i = 0; i < 20; i++) pick(easy, played, i)};
    expect(played, containsAll(picked));
    expect(picked.length, greaterThan(1));
  });

  test('finds the list of a seed, null for a seed in none', () {
    for (final difficulty in TriPeaksDifficulty.values) {
      final seeds = triPeaksDeals[difficulty.name]!;
      for (final seed in [seeds.first, seeds.last]) {
        expect(triPeaksDifficultyOfSeed(seed), difficulty);
      }
    }
    final listed = triPeaksDeals.values.expand((seeds) => seeds).toSet();
    final unlisted = [
      for (var seed = 1; seed < 1000; seed++)
        if (!listed.contains(seed)) seed,
    ].first;
    expect(triPeaksDifficultyOfSeed(unlisted), isNull);
    expect(triPeaksDifficultyOfSeed(1 << 31), isNull);
  });
}
