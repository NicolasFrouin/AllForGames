import 'dart:math';

import 'mahjong_state.dart';
import 'mahjong_tray.dart';

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

/// Simulated players of tray mode.
enum TrayPlayer {
  /// Clears a tile of the tray when it can, else picks a tile of a free
  /// pair while the tray has room for it, else any free tile.
  casual,

  /// Like [casual], but before any free tile, picks one after which a tile
  /// can clear the tray (it lay under or beside the picked one).
  greedy,

  /// Like [greedy], but before any free tile, picks one after which one
  /// more such tile, and the tiles that clear the tray, bring the tray back
  /// to what it holds now.
  careful,
}

/// Plays [state] to the end with [player]; true when it wins.
bool playTray(TrayState state, TrayPlayer player, Random random) {
  while (!state.isWon) {
    if (state.isLost) return false;
    final pick = _trayPick(state, player, random);
    if (pick == null) return false;
    state = state.pick(pick)!;
  }
  return true;
}

int? _trayPick(TrayState state, TrayPlayer player, Random random) {
  T any<T>(List<T> items) => items[random.nextInt(items.length)];
  final matches = state.freeMatches;
  if (matches.isNotEmpty) return any(matches);
  // Any other pick goes into the tray: the last place loses.
  if (state.tray.length >= TrayState.capacity - 1) return null;
  final pairs = state.board.freePairs;
  if (pairs.isNotEmpty) {
    final (a, b) = any(pairs);
    return random.nextBool() ? a : b;
  }
  final free = [
    for (final id in state.board.tileIds)
      if (state.board.isFree(id)) id,
  ];
  if (player == TrayPlayer.casual) return any(free);
  final blindPicks = player == TrayPlayer.greedy ? 0 : 1;
  final safe = [
    for (final id in free)
      if (_recovers(state.pick(id)!, state.tray.length, blindPicks)) id,
  ];
  return any(safe.isEmpty ? free : safe);
}

/// Whether the tiles that clear the tray, and at most [blindPicks] tiles
/// that wait in it, bring the tray of [state] down to [target] tiles (or
/// win), without filling it.
bool _recovers(TrayState state, int target, int blindPicks) {
  if (state.isLost) return false;
  if (state.isWon || state.tray.length <= target) return true;
  final matches = state.freeMatches;
  if (matches.isNotEmpty) {
    return _recovers(state.pick(matches.first)!, target, blindPicks);
  }
  if (blindPicks == 0 || state.tray.length >= TrayState.capacity - 1) {
    return false;
  }
  for (final id in state.board.tileIds) {
    if (state.board.isFree(id) &&
        _recovers(state.pick(id)!, target, blindPicks - 1)) {
      return true;
    }
  }
  return false;
}
