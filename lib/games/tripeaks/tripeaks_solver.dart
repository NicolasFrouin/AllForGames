/// A TriPeaks solver, used offline to prove deals winnable and to grade
/// them. Pure Dart: it runs in the generator tool and in tests, never in the
/// app.
///
/// Technique: depth-first search over every move (each playable tableau
/// card, then a draw), with a memo of the positions already searched. Only
/// the rank of the waste card matters for what follows, so a position is the
/// set of cleared tableau places, the number of cards drawn and the waste
/// rank. The search is complete: within its node budget, a deal it cannot win
/// is unwinnable.
library;

import 'dart:collection';

import '../../cards/deal_random.dart';
import 'tripeaks_difficulty.dart';
import 'tripeaks_state.dart';

/// One move of a solution, to replay on a [TriPeaksState].
class TriPeaksMove {
  const TriPeaksMove.play(int this.position);
  const TriPeaksMove.draw() : position = null;

  /// The tableau place of the card played; null for a draw.
  final int? position;

  bool get isDraw => position == null;

  @override
  bool operator ==(Object other) =>
      other is TriPeaksMove && other.position == position;

  @override
  int get hashCode => position.hashCode;

  @override
  String toString() => isDraw ? 'draw' : 'play($position)';
}

/// Plays [moves] from [state]. Returns null as soon as one is illegal.
TriPeaksState? replayMoves(TriPeaksState state, Iterable<TriPeaksMove> moves) {
  TriPeaksState? current = state;
  for (final move in moves) {
    current = switch (move.position) {
      null => current!.draw(),
      final position => current!.play(position),
    };
    if (current == null) return null;
  }
  return current;
}

enum SolveStatus {
  solved,

  /// Every position was searched without a win: the deal cannot be won.
  unsolvable,

  /// The node budget ran out first.
  unknown,
}

class SolveResult {
  const SolveResult(this.status, this.nodes, [this.solution = const []]);

  final SolveStatus status;

  /// Positions searched.
  final int nodes;

  /// Winning moves when [status] is [SolveStatus.solved], else empty.
  final List<TriPeaksMove> solution;

  bool get isSolved => status == SolveStatus.solved;

  @override
  String toString() =>
      'SolveResult(${status.name}, $nodes nodes, ${solution.length} moves)';
}

/// The rules that grade a deal into a [TriPeaksDifficulty].
///
/// Changing them (or the players) changes the grades: rerun
/// `dart run tool/generate_tripeaks_deals.dart` afterwards.
abstract final class TriPeaksGrading {
  /// Node budget of the solver for a deal; beyond it the deal is unknown and
  /// never offered.
  static const maxNodes = 2000000;

  /// Games of the casual player per deal.
  static const casualGames = 200;

  /// Easy: the greedy player wins, and the casual player wins at least this
  /// share of its games (almost any play wins).
  static const easyMinWinRate = 0.5;

  /// Medium: the greedy player loses, and the casual player wins this share
  /// of its games (the choices matter).
  static const mediumMinWinRate = 0.1;
  static const mediumMaxWinRate = 0.4;

  /// Hard: the greedy player loses, and the casual player wins this share
  /// of its games: few winning lines, so it needs planning, but at least one
  /// natural line (the player cannot see the stock).
  static const hardMinWinRate = 0.005;
  static const hardMaxWinRate = 0.03;
}

/// Grading metrics of one deal.
class TriPeaksDealGrade {
  const TriPeaksDealGrade({
    required this.seed,
    required this.greedyWins,
    required this.casualWins,
    required this.result,
  });

  final int seed;

  /// Whether [TriPeaksSolver.playGreedy] wins the deal.
  final bool greedyWins;

  /// Games won by [TriPeaksSolver.playCasual], out of
  /// [TriPeaksGrading.casualGames].
  final int casualWins;

  final SolveResult result;

  double get casualWinRate => casualWins / TriPeaksGrading.casualGames;

  /// Null when the solver could not prove the deal winnable, or when the
  /// deal falls between two levels: the gaps keep the levels apart.
  TriPeaksDifficulty? get difficulty {
    if (!result.isSolved) return null;
    final rate = casualWinRate;
    if (greedyWins) {
      return rate >= TriPeaksGrading.easyMinWinRate
          ? TriPeaksDifficulty.easy
          : null;
    }
    if (rate >= TriPeaksGrading.hardMinWinRate &&
        rate <= TriPeaksGrading.hardMaxWinRate) {
      return TriPeaksDifficulty.hard;
    }
    if (rate >= TriPeaksGrading.mediumMinWinRate &&
        rate <= TriPeaksGrading.mediumMaxWinRate) {
      return TriPeaksDifficulty.medium;
    }
    return null;
  }
}

/// Proves TriPeaks states winnable (see the library comment), plays them
/// like simple players, and grades deals.
class TriPeaksSolver {
  const TriPeaksSolver();

  static const defaultMaxNodes = TriPeaksGrading.maxNodes;

  SolveResult solve(TriPeaksState state, {int maxNodes = defaultMaxNodes}) =>
      _Search(_Board(state), maxNodes).run();

  /// Plays [state] like a player who always plays a tableau card when one
  /// fits, the one that leaves the most cards to play next (then the one
  /// that turns over the most cards, then the leftmost), and draws only
  /// when no card fits. Returns the winning moves, or null when this player
  /// loses.
  List<TriPeaksMove>? playGreedy(TriPeaksState state) {
    final board = _Board(state);
    final moves = <TriPeaksMove>[];
    var cleared = board.initialCleared;
    var drawn = 0;
    var waste = board.wasteRank;
    while (cleared != board.full) {
      int? best;
      var bestScore = -1;
      for (final i in board.playable(cleared, waste)) {
        final after = cleared | 1 << i;
        final score =
            board.playable(after, board.ranks[i]).length * 16 +
            board.turnedOver(cleared, i);
        if (score > bestScore) {
          best = i;
          bestScore = score;
        }
      }
      if (best != null) {
        moves.add(TriPeaksMove.play(best));
        cleared |= 1 << best;
        waste = board.ranks[best];
      } else if (drawn < board.stockRanks.length) {
        moves.add(const TriPeaksMove.draw());
        waste = board.stockRanks[drawn++];
      } else {
        return null;
      }
    }
    return moves;
  }

  /// Plays [state] like a casual player: a random card among those that fit
  /// (random by [seed]), a draw only when none fits. Returns whether this
  /// player wins.
  bool playCasual(TriPeaksState state, int seed) {
    final board = _Board(state);
    final random = DealRandom(seed);
    var cleared = board.initialCleared;
    var drawn = 0;
    var waste = board.wasteRank;
    while (cleared != board.full) {
      final playable = board.playable(cleared, waste);
      if (playable.isNotEmpty) {
        final i = playable[random.nextInt(playable.length)];
        cleared |= 1 << i;
        waste = board.ranks[i];
      } else if (drawn < board.stockRanks.length) {
        waste = board.stockRanks[drawn++];
      } else {
        return false;
      }
    }
    return true;
  }

  /// Grades the deal of [seed] (see [TriPeaksGrading]).
  TriPeaksDealGrade grade(int seed) {
    final state = TriPeaksState.deal(seed);
    var casualWins = 0;
    for (var game = 0; game < TriPeaksGrading.casualGames; game++) {
      if (playCasual(state, seed * TriPeaksGrading.casualGames + game)) {
        casualWins++;
      }
    }
    return TriPeaksDealGrade(
      seed: seed,
      greedyWins: playGreedy(state) != null,
      casualWins: casualWins,
      result: solve(state),
    );
  }
}

/// The deal as numbers: a rank per tableau place, the stock ranks in draw
/// order, and a bit per tableau place for the cleared ones.
class _Board {
  _Board(TriPeaksState state)
    : ranks = [for (final card in state.tableau) card?.rank ?? 0],
      stockRanks = [for (final card in state.stock.reversed) card.rank],
      wasteRank = state.wasteTop.rank,
      initialCleared = _clearedOf(state);

  static final _coverMasks = [
    for (final below in TriPeaksState.coveredBy)
      below.fold(0, (mask, i) => mask | 1 << i),
  ];

  final int full = (1 << TriPeaksState.positions) - 1;
  final List<int> ranks;
  final List<int> stockRanks;
  final int wasteRank;
  final int initialCleared;

  static int _clearedOf(TriPeaksState state) {
    var cleared = 0;
    for (var i = 0; i < TriPeaksState.positions; i++) {
      if (state.tableau[i] == null) cleared |= 1 << i;
    }
    return cleared;
  }

  /// The places whose card can go on a waste of rank [waste].
  List<int> playable(int cleared, int waste) => [
    for (var i = 0; i < TriPeaksState.positions; i++)
      if (cleared & 1 << i == 0 &&
          cleared & _coverMasks[i] == _coverMasks[i] &&
          TriPeaksState.fits(ranks[i], waste))
        i,
  ];

  /// How many cards clearing place [i] turns over.
  int turnedOver(int cleared, int i) {
    final after = cleared | 1 << i;
    return TriPeaksState.covers[i]
        .where(
          (j) =>
              cleared & 1 << j == 0 && after & _coverMasks[j] == _coverMasks[j],
        )
        .length;
  }
}

class _Search {
  _Search(this.board, this.maxNodes);

  final _Board board;
  final int maxNodes;
  final _seen = HashSet<int>();
  final _path = <TriPeaksMove>[];
  int _nodes = 0;
  bool _outOfBudget = false;

  SolveResult run() {
    if (_win(board.initialCleared, 0, board.wasteRank)) {
      return SolveResult(SolveStatus.solved, _nodes, List.of(_path));
    }
    return SolveResult(
      _outOfBudget ? SolveStatus.unknown : SolveStatus.unsolvable,
      _nodes,
    );
  }

  bool _win(int cleared, int drawn, int waste) {
    if (cleared == board.full) return true;
    if (_nodes >= maxNodes) {
      _outOfBudget = true;
      return false;
    }
    // 28 bits of cleared places, 5 of cards drawn, 4 of waste rank.
    if (!_seen.add(cleared | drawn << 28 | waste << 33)) return false;
    _nodes++;
    for (final i in board.playable(cleared, waste)) {
      _path.add(TriPeaksMove.play(i));
      if (_win(cleared | 1 << i, drawn, board.ranks[i])) return true;
      _path.removeLast();
      if (_outOfBudget) return false;
    }
    if (drawn < board.stockRanks.length) {
      _path.add(const TriPeaksMove.draw());
      if (_win(cleared, drawn + 1, board.stockRanks[drawn])) return true;
      _path.removeLast();
    }
    return false;
  }
}
