// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

// Plays many deals of each Mahjong difficulty with simulated players and
// prints their win rates, in both orientations of the layouts, for the
// classic mode and the tray mode:
//   dart run tool/mahjong_difficulty.dart [deals per level, default 500]
import 'dart:math';

import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_players.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';

void main(List<String> args) {
  final deals = args.isEmpty ? 500 : int.parse(args.first);
  print('Win rates over $deals deals (seeds 1 to $deals)');
  for (final mode in MahjongMode.values) {
    print('${mode.name}:');
    for (final difficulty in MahjongDifficulty.values) {
      for (final transposed in [false, true]) {
        final layout = difficulty.layout(transposed: transposed);
        final wins = <String, int>{};
        void play(String player, bool won) =>
            wins[player] = (wins[player] ?? 0) + (won ? 1 : 0);
        for (var seed = 1; seed <= deals; seed++) {
          switch (mode) {
            case MahjongMode.classic:
              final deal = generateDeal(
                layout,
                seed,
                trapPercent: difficulty.trapPercent,
              );
              for (final player in SimulatedPlayer.values) {
                play(
                  player.name,
                  playMahjong(deal.state, player, Random(seed)),
                );
              }
            case MahjongMode.tray:
              final deal = generateTrayDeal(layout, seed, difficulty.tray);
              final state = TrayState(deal.state, const []);
              for (final player in TrayPlayer.values) {
                play(player.name, playTray(state, player, Random(seed)));
              }
          }
        }
        final rates = [
          for (final MapEntry(key: player, value: won) in wins.entries)
            '$player ${(100 * won / deals).toStringAsFixed(1)}%',
        ];
        print(
          '  ${difficulty.name.padRight(6)} ${layout.id}'
          '${transposed ? ' (transposed)' : ''}: ${rates.join(', ')}',
        );
      }
    }
  }
}
