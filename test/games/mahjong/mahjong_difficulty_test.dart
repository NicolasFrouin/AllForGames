import 'dart:math';

import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_players.dart';
import 'package:flutter_test/flutter_test.dart';

/// Share of the deals of seeds 1 to [deals] that the greedy player wins.
double greedyWinRate(MahjongDifficulty difficulty, int deals) {
  var wins = 0;
  for (var seed = 1; seed <= deals; seed++) {
    final deal = generateDeal(
      difficulty.layout(),
      seed,
      trapPercent: difficulty.trapPercent,
    );
    if (playMahjong(deal.state, SimulatedPlayer.greedy, Random(seed))) wins++;
  }
  return wins / deals;
}

void main() {
  test('harder levels are won less often by a simulated player', () {
    // About 91%, 58% and 23% over 1000 deals (tool/mahjong_difficulty.dart).
    final easy = greedyWinRate(MahjongDifficulty.easy, 80);
    final medium = greedyWinRate(MahjongDifficulty.medium, 80);
    final hard = greedyWinRate(MahjongDifficulty.hard, 80);

    expect(easy, greaterThan(0.8));
    expect(medium, inInclusiveRange(0.4, 0.75));
    expect(hard, lessThan(0.35));
  });
}
