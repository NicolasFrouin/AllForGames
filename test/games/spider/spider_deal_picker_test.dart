import 'dart:math';

import 'package:all_for_games/games/spider/spider_deal_picker.dart';
import 'package:all_for_games/games/spider/spider_deals.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

Set<int> seedsOf(SpiderDifficulty difficulty) =>
    spiderDeals[difficulty.name]!.toSet();

int pick(SpiderDifficulty difficulty, Set<int> played, [int randomSeed = 0]) =>
    pickSpiderSeed(
      difficulty: difficulty,
      played: played,
      random: Random(randomSeed),
    );

void main() {
  test('picks only seeds of the list of the difficulty', () {
    for (final difficulty in SpiderDifficulty.values) {
      final picked = {for (var i = 0; i < 100; i++) pick(difficulty, {}, i)};
      expect(seedsOf(difficulty), containsAll(picked));
      expect(picked.length, greaterThan(50), reason: 'random seeds');
    }
  });

  test('skips played seeds', () {
    final left = seedsOf(SpiderDifficulty.hard).elementAt(100);
    final played = seedsOf(SpiderDifficulty.hard)..remove(left);
    for (var i = 0; i < 20; i++) {
      expect(pick(SpiderDifficulty.hard, played, i), left);
    }
  });

  test('picks any seed of the list again once all were played', () {
    final played = seedsOf(SpiderDifficulty.easy);
    final picked = {
      for (var i = 0; i < 20; i++) pick(SpiderDifficulty.easy, played, i),
    };
    expect(played, containsAll(picked));
    expect(picked.length, greaterThan(1));
  });
}
