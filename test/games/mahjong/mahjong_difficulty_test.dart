import 'dart:math';

import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_players.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
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

/// Share of the tray deals of seeds 1 to [deals] that [player] wins.
double trayWinRate(
  MahjongDifficulty difficulty,
  int deals, {
  TrayPlayer player = TrayPlayer.casual,
  bool transposed = false,
}) {
  var wins = 0;
  for (var seed = 1; seed <= deals; seed++) {
    final deal = generateTrayDeal(
      difficulty.layout(transposed: transposed),
      seed,
      difficulty.tray,
    );
    final state = TrayState(deal.state, const []);
    if (playTray(state, player, Random(seed))) wins++;
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

  test('in tray mode, harder levels are won less often, both ways', () {
    // The casual player, over 200 deals: about 93%, 36% and 7%, and 98%,
    // 62% and 45% transposed (tool/mahjong_difficulty.dart).
    for (final transposed in [false, true]) {
      final rates = [
        for (final difficulty in MahjongDifficulty.values)
          trayWinRate(difficulty, 60, transposed: transposed),
      ];
      expect(rates[0], greaterThan(0.85), reason: '$transposed $rates');
      expect(rates[1], lessThan(rates[0] - 0.2), reason: '$transposed $rates');
      expect(rates[2], lessThan(rates[1]), reason: '$transposed $rates');
    }
    // Hard on a wide screen: harder than a classic Hard deal.
    expect(trayWinRate(MahjongDifficulty.hard, 60), lessThan(0.2));
  });

  test('in tray mode, a player who looks ahead wins more', () {
    final casual = trayWinRate(MahjongDifficulty.hard, 30);
    final careful = trayWinRate(
      MahjongDifficulty.hard,
      30,
      player: TrayPlayer.careful,
    );

    expect(careful, greaterThan(casual + 0.3));
  });
}
