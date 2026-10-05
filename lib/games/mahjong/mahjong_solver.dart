import 'dart:math';

import 'mahjong_layout.dart';
import 'mahjong_state.dart';
import 'mahjong_tiles.dart';

/// An order of pairs that clears [state], or null when there is none, or
/// when the search gives up after [budget] boards (it runs on the UI thread:
/// 20000 boards take about 50 ms on a laptop).
///
/// A depth-first search: the last tiles of a face, when all free, go at
/// once (nothing better can come from waiting); otherwise it tries the
/// pairs that uncover the most tiles first, skips boards where tiles wait on
/// each other forever, and never visits a board twice. Its first choices
/// matter most, so it starts over with shuffled ties every [_restartBoards]
/// boards.
List<TilePair>? solveMahjong(MahjongState state, {int budget = 20000}) {
  final solver = _Solver(state);
  if (solver.groupPositions.keys.any(solver.deadEnd)) return null;
  for (var run = 0; run * _restartBoards < budget; run++) {
    final solution = solver.run(
      min(_restartBoards, budget - run * _restartBoards),
      run == 0 ? null : Random(run),
    );
    if (solution != null) return solution;
    if (!solver.gaveUp) return null;
  }
  return null;
}

const _restartBoards = 1000;

class _Solver {
  _Solver(MahjongState state)
    : layout = state.layout,
      slots = state.slots,
      groupOf = [for (final face in state.faces) TileFace(face).group],
      tileCount = state.tileCount {
    for (var p = 0; p < layout.length; p++) {
      for (final q in [
        ...layout.above[p],
        ...layout.left[p],
        ...layout.right[p],
      ]) {
        blocks[q].add(p);
      }
    }
    for (final (p, id) in slots.indexed) {
      if (id != MahjongState.empty) {
        (groupPositions[groupOf[id]] ??= []).add(p);
      }
    }
    _reset();
  }

  final MahjongLayout layout;
  final List<int> slots;
  final List<int> groupOf;
  final int tileCount;

  /// The positions that each position blocks: those it lies on or beside.
  late final blocks = List.generate(layout.length, (_) => <int>[]);

  /// The positions of the tiles of each group.
  final groupPositions = <int, List<int>>{};

  late List<bool> occupied;
  late Map<int, int> left;
  final path = <TilePair>[];
  int remaining = 0;
  int boards = 0;
  int budget = 0;
  bool gaveUp = false;
  Random? random;

  void _reset() {
    occupied = [for (final id in slots) id != MahjongState.empty];
    left = {
      for (final MapEntry(:key, :value) in groupPositions.entries)
        key: value.length,
    };
    path.clear();
    remaining = tileCount;
  }

  List<TilePair>? run(int budget, Random? random) {
    _reset();
    this.budget = budget;
    this.random = random;
    boards = 0;
    gaveUp = false;
    return _search(<String>{}) == true ? [...path] : null;
  }

  bool over(int p, int q) => layout.above[q].contains(p);

  /// Whether the tiles left of [group] can never all go: the last two lie
  /// one on the other, or three lie on each other (the top one must go with
  /// the fourth, and the other two are then stuck).
  bool deadEnd(int group) {
    final ps = [
      for (final p in groupPositions[group]!)
        if (occupied[p]) p,
    ];
    for (final p in ps) {
      for (final q in ps) {
        if (!over(p, q)) continue;
        if (ps.length == 2) return true;
        for (final r in ps) {
          if (over(q, r)) return true;
        }
      }
    }
    return false;
  }

  /// Whether the last two tiles of some groups wait on each other: a tile
  /// of one lies on a tile of the next, around a loop. Each of them can only
  /// go after the one on it, so none ever goes.
  bool deadlocked() {
    final waits = <int, Set<int>>{};
    for (final MapEntry(key: group, value: count) in left.entries) {
      if (count != 2) continue;
      for (final p in groupPositions[group]!) {
        if (!occupied[p]) continue;
        for (final q in layout.above[p]) {
          if (!occupied[q]) continue;
          final other = groupOf[slots[q]];
          if (left[other] == 2) (waits[other] ??= {}).add(group);
        }
      }
    }
    // 1: on the current path, 2: done.
    final marks = <int, int>{};
    bool loops(int group) {
      marks[group] = 1;
      for (final next in waits[group] ?? const <int>{}) {
        final mark = marks[next];
        if (mark == 1 || (mark == null && loops(next))) return true;
      }
      marks[group] = 2;
      return false;
    }

    return waits.keys.any((group) => marks[group] == null && loops(group));
  }

  String _key() {
    final codes = <int>[];
    for (var p = 0; p < occupied.length; p += 16) {
      var code = 0;
      for (var q = p; q < p + 16 && q < occupied.length; q++) {
        if (occupied[q]) code |= 1 << (q - p);
      }
      codes.add(code);
    }
    return String.fromCharCodes(codes);
  }

  int _uncovered(int p) {
    var count = 0;
    for (final q in blocks[p]) {
      if (occupied[q]) count++;
    }
    return count;
  }

  void _remove(int a, int b) {
    occupied[a] = false;
    occupied[b] = false;
    left[groupOf[slots[a]]] = left[groupOf[slots[a]]]! - 2;
    remaining -= 2;
    path.add((slots[a], slots[b]));
  }

  void _restore(int a, int b) {
    occupied[a] = true;
    occupied[b] = true;
    left[groupOf[slots[a]]] = left[groupOf[slots[a]]]! + 2;
    remaining += 2;
    path.removeLast();
  }

  /// True when solved, false when there is no way on, null when the budget
  /// is out.
  bool? _search(Set<String> visited) {
    if (remaining == 0) return true;
    if (++boards > budget) {
      gaveUp = true;
      return null;
    }
    if (!visited.add(_key()) || deadlocked()) return false;
    final free = <int, List<int>>{};
    for (var p = 0; p < occupied.length; p++) {
      if (occupied[p] && layout.isFree(p, occupied)) {
        (free[groupOf[slots[p]]] ??= []).add(p);
      }
    }
    for (final MapEntry(key: group, value: ps) in free.entries) {
      if (ps.length >= 2 && ps.length == left[group]) {
        final pairs = [(ps[0], ps[1]), if (ps.length == 4) (ps[2], ps[3])];
        for (final (a, b) in pairs) {
          _remove(a, b);
        }
        final result = _search(visited);
        if (result != false) return result;
        for (final (a, b) in pairs.reversed) {
          _restore(a, b);
        }
        return false;
      }
    }
    final moves = [
      for (final ps in free.values)
        for (var i = 0; i < ps.length; i++)
          for (var j = i + 1; j < ps.length; j++)
            (
              ps[i],
              ps[j],
              _uncovered(ps[i]) +
                  _uncovered(ps[j]) +
                  (random?.nextDouble() ?? 0),
            ),
    ]..sort((x, y) => y.$3.compareTo(x.$3));
    for (final (a, b, _) in moves) {
      _remove(a, b);
      if (!deadEnd(groupOf[slots[a]])) {
        final result = _search(visited);
        if (result != false) return result;
      }
      _restore(a, b);
    }
    return false;
  }
}

/// Mends [solution], an order that cleared the board before the player
/// matched [a] and [b], into an order that clears [after], the board now.
/// Null when it cannot.
///
/// A pair of the order can go earlier: removing tiles never blocks others.
/// Otherwise the partners of [a] and [b] in the order now go together, at
/// the first place where the order still works.
List<TilePair>? mendSolution(
  MahjongState after,
  List<TilePair> solution,
  int a,
  int b,
) {
  bool holds(TilePair pair, int id) => pair.$1 == id || pair.$2 == id;
  final i = solution.indexWhere((pair) => holds(pair, a));
  final j = solution.indexWhere((pair) => holds(pair, b));
  if (i < 0 || j < 0) return null;
  if (i == j) return [...solution]..removeAt(i);
  int partner(TilePair pair, int id) => pair.$1 == id ? pair.$2 : pair.$1;
  final mended = (partner(solution[i], a), partner(solution[j], b));
  final rest = [
    for (final (k, pair) in solution.indexed)
      if (k != i && k != j) pair,
  ];
  for (var k = i < j ? i : j; k <= rest.length; k++) {
    final order = [...rest]..insert(k, mended);
    if (after.isSolvedBy(order)) return order;
  }
  return null;
}
