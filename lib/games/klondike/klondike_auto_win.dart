import 'klondike_solver.dart';
import 'klondike_state.dart';

/// How a game in progress wins by itself: take back [undos] moves, then play
/// [actions].
typedef AutoWinPlan = ({int undos, List<KlondikeAction> actions});

/// The plan from the latest of [states] (the positions of the game, from its
/// deal to the one on screen) that [solver] wins from, or null when it wins
/// from none of them.
///
/// A lost position only leads to lost ones, so a binary search finds the
/// move that lost the game in a few searches. (A search that runs out of
/// nodes can make it stop earlier: any position it wins from does.)
Future<AutoWinPlan?> planAutoWin(
  List<KlondikeState> states, {
  KlondikeSolver solver = const KlondikeSolver(),
  int maxNodes = KlondikeSolver.defaultMaxNodes,
}) async {
  final last = states.length - 1;
  Future<AutoWinPlan?> from(int index) async {
    final result = await solver.solveInSlices(
      states[index],
      maxNodes: maxNodes,
    );
    return result.isSolved
        ? (undos: last - index, actions: result.solution)
        : null;
  }

  if (await from(last) case final plan?) return plan;
  AutoWinPlan? best;
  var low = 0;
  var high = last - 1;
  while (low <= high) {
    final middle = (low + high) ~/ 2;
    if (await from(middle) case final plan?) {
      best = plan;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  return best;
}
