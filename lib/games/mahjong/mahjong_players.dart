import 'dart:math';

import 'mahjong_state.dart';

/// Simulated players that grade the difficulty levels, offline only (the
/// difficulty tool and the tests).
enum SimulatedPlayer {
  /// Any match, at random.
  random,

  /// The match that frees the most tiles, at random among the best.
  greedy,
}

/// Plays [state] to the end with [player]; true when it clears the board.
bool playMahjong(MahjongState state, SimulatedPlayer player, Random random) {
  while (!state.isWon) {
    final pairs = state.freePairs;
    if (pairs.isEmpty) return false;
    final candidates = switch (player) {
      SimulatedPlayer.random => pairs,
      SimulatedPlayer.greedy => _mostFreeing(state, pairs),
    };
    final (a, b) = candidates[random.nextInt(candidates.length)];
    state = state.match(a, b)!;
  }
  return true;
}

List<TilePair> _mostFreeing(MahjongState state, List<TilePair> pairs) {
  var best = -1;
  final bests = <TilePair>[];
  for (final (a, b) in pairs) {
    final next = state.match(a, b)!;
    var freed = 0;
    for (final id in next.tileIds) {
      if (next.isFree(id) && !state.isFree(id)) freed++;
    }
    if (freed > best) {
      best = freed;
      bests.clear();
    }
    if (freed == best) bests.add((a, b));
  }
  return bests;
}
