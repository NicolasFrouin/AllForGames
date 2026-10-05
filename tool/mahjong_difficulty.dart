// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

// Plays many deals of each Mahjong difficulty with simulated players and
// prints their win rates, in both orientations of the layouts:
//   dart run tool/mahjong_difficulty.dart [deals per level, default 500]
import 'dart:math';

import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_players.dart';

void main(List<String> args) {
  final deals = args.isEmpty ? 500 : int.parse(args.first);
  print('Win rates over $deals deals (seeds 1 to $deals)');
  for (final difficulty in MahjongDifficulty.values) {
    for (final transposed in [false, true]) {
      final layout = difficulty.layout(transposed: transposed);
      final wins = {for (final player in SimulatedPlayer.values) player: 0};
      for (var seed = 1; seed <= deals; seed++) {
        final deal = generateDeal(
          layout,
          seed,
          trapPercent: difficulty.trapPercent,
        );
        for (final player in SimulatedPlayer.values) {
          if (playMahjong(deal.state, player, Random(seed))) {
            wins[player] = wins[player]! + 1;
          }
        }
      }
      final rates = [
        for (final MapEntry(key: player, value: won) in wins.entries)
          '${player.name} ${(100 * won / deals).toStringAsFixed(1)}%',
      ];
      print(
        '${difficulty.name.padRight(6)} ${layout.id}'
        '${transposed ? ' (transposed)' : ''}: ${rates.join(', ')}',
      );
    }
  }
}
