import 'dart:math';

import 'package:all_for_games/games/klondike/deal_picker.dart';
import 'package:all_for_games/games/klondike/klondike_deals.dart';
import 'package:flutter_test/flutter_test.dart';

Set<int> winnable(int drawCount) => {
  ...klondikeDeals[drawCount]!.values.expand((seeds) => seeds),
};

int pick(int drawCount, Set<int> played, [int randomSeed = 0]) => pickDealSeed(
  drawCount: drawCount,
  played: played,
  random: Random(randomSeed),
);

void main() {
  test('picks only listed seeds, of every difficulty', () {
    for (final drawCount in [1, 3]) {
      final picked = {for (var i = 0; i < 300; i++) pick(drawCount, {}, i)};
      expect(winnable(drawCount), containsAll(picked));
      for (final seeds in klondikeDeals[drawCount]!.values) {
        expect(picked.intersection(seeds.toSet()), isNotEmpty);
      }
    }
  });

  test('skips played seeds', () {
    final left = winnable(1).elementAt(500);
    final played = winnable(1)..remove(left);
    for (var i = 0; i < 20; i++) {
      expect(pick(1, played, i), left);
    }
  });

  test('picks any listed seed again once all were played', () {
    final played = winnable(1);
    final picked = {for (var i = 0; i < 20; i++) pick(1, played, i)};
    expect(played, containsAll(picked));
    expect(picked.length, greaterThan(1));
  });

  test('uses the list of the draw count', () {
    final left = winnable(3).difference(winnable(1)).first;
    final played = {...winnable(1), ...winnable(3)}..remove(left);
    expect(pick(3, played), left);
    // Every draw 1 seed was played, and the draw 3 one is not for draw 1.
    expect(winnable(1), contains(pick(1, played)));
  });
}
