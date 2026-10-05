/// A "thoughtful" Spider solver (it sees the face-down cards), used offline
/// to prove deals winnable. Pure Dart: it runs in the generator tool and in
/// tests, never in the app.
///
/// Technique:
/// - best-first search on an evaluation of the board (face-down cards, cards
///   not on a card of the same suit one rank higher, cards still in the
///   stock, empty columns, completed runs), with a little weight on the
///   number of moves so that it does not wander;
/// - a transposition table of 64-bit hashes of canonical boards: the
///   face-down cards of a column never move, so a column is its index, its
///   face-down count and its face-up cards, and the columns without face-down
///   cards are interchangeable (their hashes are summed);
/// - moves that cannot help are never tried: the cards that move are always
///   the whole run of one suit on top of a column (splitting a run of one
///   suit gains nothing), a column never moves whole to an empty column, and
///   only the first empty column is tried;
/// - the open list is capped: past [SpiderSolver.maxOpen] boards, the worse
///   half is dropped;
/// - small changes of the weights solve different deals, so the solver tries
///   a few weight sets in turn ([SpiderSolver.defaultAttempts]).
///
/// The search is sound but not complete: a [SolveStatus.solved] result always
/// replays to a win, while [SolveStatus.unsolvable] only means that this
/// pruned search space is exhausted (or that boards were dropped).
library;

import 'dart:collection';
import 'dart:typed_data';

import '../../cards/playing_card.dart';
import 'spider_difficulty.dart';
import 'spider_state.dart';

/// One step of a solution, to replay with [SpiderState.move] and
/// [SpiderState.deal].
sealed class SpiderMove {
  const SpiderMove();

  /// The state after this move, or null when it is not legal in [state].
  SpiderState? applyTo(SpiderState state);
}

final class ColumnMove extends SpiderMove {
  const ColumnMove(this.from, this.count, this.to);

  final int from;
  final int count;
  final int to;

  @override
  SpiderState? applyTo(SpiderState state) => state.move(from, count, to);

  @override
  bool operator ==(Object other) =>
      other is ColumnMove &&
      other.from == from &&
      other.count == count &&
      other.to == to;

  @override
  int get hashCode => Object.hash(from, count, to);

  @override
  String toString() => 'move($from, $count, $to)';
}

final class StockDeal extends SpiderMove {
  const StockDeal();

  @override
  SpiderState? applyTo(SpiderState state) => state.deal();

  @override
  bool operator ==(Object other) => other is StockDeal;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'deal';
}

/// Plays [moves] from [state]. Returns null as soon as one is illegal.
SpiderState? replayMoves(SpiderState state, Iterable<SpiderMove> moves) {
  var current = state;
  for (final move in moves) {
    final next = move.applyTo(current);
    if (next == null) return null;
    current = next;
  }
  return current;
}

enum SolveStatus {
  solved,

  /// The (pruned) search space was exhausted without a win.
  unsolvable,

  /// The node budget ran out first.
  unknown,
}

class SolveResult {
  const SolveResult(this.status, this.nodes, [this.solution = const []]);

  final SolveStatus status;

  /// Boards expanded by the search.
  final int nodes;

  /// Winning moves when [status] is [SolveStatus.solved], else empty.
  final List<SpiderMove> solution;

  bool get isSolved => status == SolveStatus.solved;

  @override
  String toString() =>
      'SolveResult(${status.name}, $nodes nodes, ${solution.length} moves)';
}

/// Weights of the evaluation: a board with a lower value is expanded first.
class SpiderWeights {
  const SpiderWeights({
    this.faceDown = 6,
    this.offSuit = 2,
    this.broken = 4,
    this.stockCard = 2,
    this.emptyColumn = 8,
    this.run = 30,
    this.cover = 0,
    this.move = 0.5,
  });

  /// Per face-down card.
  final double faceDown;

  /// Per card on a card one rank higher of another suit.
  final double offSuit;

  /// Per face-up card on a card that it does not fit.
  final double broken;

  /// Per card in the stock (each will land on some column).
  final double stockCard;

  /// Per empty column (a bonus).
  final double emptyColumn;

  /// Per completed run (a bonus).
  final double run;

  /// Per face-up card above face-down cards.
  final double cover;

  /// Per move from the start.
  final double move;
}

/// Proves Spider deals winnable (see the library comment).
///
/// Small changes of the weights solve different deals: the solver tries each
/// of [attempts] in turn, each with the node budget, until one wins.
class SpiderSolver {
  const SpiderSolver({this.attempts = defaultAttempts});

  /// With 300000 nodes each, the first proves about 55% of the 4-suit
  /// deals, the four together about 82% (2-suit deals: 99%).
  static const defaultAttempts = [
    SpiderWeights(cover: 1),
    SpiderWeights(offSuit: 2.5),
    SpiderWeights(move: 0.3),
    SpiderWeights(offSuit: 3, broken: 5, cover: 1),
  ];

  static const defaultMaxNodes = 100000;

  /// Node budget of each attempt by level, for the generator: beyond it, a
  /// deal is unknown and never offered.
  static const maxNodesFor = {
    SpiderDifficulty.easy: 20000,
    SpiderDifficulty.medium: 100000,
    SpiderDifficulty.hard: 300000,
  };

  /// Boards kept in the open list.
  static const maxOpen = 400000;

  final List<SpiderWeights> attempts;

  /// Searches with each weight set of [attempts], with [maxNodes] expanded
  /// boards each. The result counts the nodes of every attempt.
  SolveResult solve(SpiderState state, {int maxNodes = defaultMaxNodes}) {
    var nodes = 0;
    var status = SolveStatus.unsolvable;
    for (final weights in attempts) {
      final result = _Search(_Board.from(state), weights, maxNodes).run();
      nodes += result.nodes;
      if (result.isSolved) {
        return SolveResult(SolveStatus.solved, nodes, result.solution);
      }
      if (result.status == SolveStatus.unknown) status = SolveStatus.unknown;
    }
    return SolveResult(status, nodes);
  }
}

// Cards are ints: suit index * 13 + rank - 1.

int _rankOf(int card) => card % 13 + 1;
int _suitOf(int card) => card ~/ 13;

const _columns = SpiderState.columnCount;

/// Room per column in the board arrays: 104 cards at most.
const _stride = 112;

/// A move of the search: `from << 12 | count << 4 | to` for a column move
/// (runs have 13 cards at most, columns are below 16), [_dealMove] for a
/// stock deal.
const _dealMove = -1;

int _columnMove(int from, int count, int to) => from << 12 | count << 4 | to;

/// Mutable board for the search.
class _Board {
  _Board.from(SpiderState state)
    : stockDeals = [
        for (var deal = 0; deal * _columns < state.stock.length; deal++)
          [
            for (var i = 0; i < _columns; i++)
              if (state.stock.length - 1 - deal * _columns - i >= 0)
                _cardOf(
                  state.stock[state.stock.length - 1 - deal * _columns - i],
                ),
          ],
      ] {
    for (var c = 0; c < _columns; c++) {
      final column = state.columns[c];
      var faceDown = 0;
      while (faceDown < column.length && !column[faceDown].faceUp) {
        faceDown++;
      }
      if (column.skip(faceDown).any((card) => !card.faceUp)) {
        throw ArgumentError('Face-down card above a face-up card in column $c');
      }
      for (var i = 0; i < column.length; i++) {
        cards[c * _stride + i] = _cardOf(column[i]);
      }
      length[c] = column.length;
      down[c] = faceDown;
    }
    dealsLeft = stockDeals.length;
    runs = state.runs.length;
  }

  _Board._copy(_Board other) : stockDeals = other.stockDeals {
    load(other.save());
  }

  static int _cardOf(PlayingCard card) => card.suit.index * 13 + card.rank - 1;

  /// The deals of the stock, from the first one: card `i` goes to column `i`.
  final List<List<int>> stockDeals;

  final cards = Uint8List(_columns * _stride);
  final length = Uint8List(_columns);
  final down = Uint8List(_columns);
  int dealsLeft = 0;
  int runs = 0;

  bool get isWon {
    if (dealsLeft > 0) return false;
    for (var c = 0; c < _columns; c++) {
      if (length[c] > 0) return false;
    }
    return true;
  }

  int card(int c, int i) => cards[c * _stride + i];
  int top(int c) => cards[c * _stride + length[c] - 1];

  /// Start of the run of one suit on top of column [c] (its length when
  /// empty).
  int runStart(int c) {
    final n = length[c];
    if (n == 0) return 0;
    final base = c * _stride;
    var s = n - 1;
    while (s > down[c] &&
        cards[base + s - 1] == cards[base + s] + 1 &&
        _rankOf(cards[base + s]) < 13) {
      s--;
    }
    return s;
  }

  /// Moves the top [count] cards of [from] onto [to], turns the uncovered
  /// card and removes a completed run.
  void move(int from, int count, int to) {
    final source = from * _stride;
    final target = to * _stride;
    final start = length[from] - count;
    for (var i = 0; i < count; i++) {
      cards[target + length[to] + i] = cards[source + start + i];
    }
    length[from] = start;
    length[to] += count;
    if (down[from] > 0 && down[from] == start) down[from]--;
    _collect(to);
  }

  void deal() {
    final deal = stockDeals[stockDeals.length - dealsLeft];
    dealsLeft--;
    for (var c = 0; c < deal.length; c++) {
      cards[c * _stride + length[c]] = deal[c];
      length[c]++;
    }
    for (var c = 0; c < deal.length; c++) {
      _collect(c);
    }
  }

  void _collect(int c) {
    final n = length[c];
    if (n < 13 || _rankOf(top(c)) != 1) return;
    final start = n - 13;
    if (start < down[c]) return;
    final base = c * _stride;
    for (var i = start + 1; i < n; i++) {
      if (cards[base + i] != cards[base + i - 1] - 1) return;
    }
    if (_rankOf(cards[base + start]) != 13) return;
    length[c] = start;
    runs++;
    if (down[c] > 0 && down[c] == start) down[c]--;
  }

  /// The board as bytes: deals left, runs, then each column as its length,
  /// face-down count and cards.
  Uint8List save() {
    var size = 2 + 2 * _columns;
    for (var c = 0; c < _columns; c++) {
      size += length[c];
    }
    final bytes = Uint8List(size);
    bytes[0] = dealsLeft;
    bytes[1] = runs;
    var n = 2;
    for (var c = 0; c < _columns; c++) {
      final len = length[c];
      bytes[n++] = len;
      bytes[n++] = down[c];
      bytes.setRange(n, n + len, cards, c * _stride);
      n += len;
    }
    return bytes;
  }

  void load(Uint8List bytes) {
    dealsLeft = bytes[0];
    runs = bytes[1];
    var n = 2;
    for (var c = 0; c < _columns; c++) {
      final len = bytes[n++];
      length[c] = len;
      down[c] = bytes[n++];
      cards.setRange(c * _stride, c * _stride + len, bytes, n);
      n += len;
    }
  }

  /// 64-bit hash of the canonical board (see the library comment).
  int hash() {
    var sum = dealsLeft * 0x9E3779B97F4A7C15;
    for (var c = 0; c < _columns; c++) {
      final base = c * _stride;
      var h = 0xCBF29CE484222325 ^ down[c];
      if (down[c] > 0) h ^= (c + 1) << 8;
      for (var i = down[c]; i < length[c]; i++) {
        h = (h ^ (cards[base + i] + 1)) * 0x100000001B3;
      }
      sum += _mix(h);
    }
    return sum;
  }

  /// splitmix64 finalizer.
  static int _mix(int z) {
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  double evaluate(SpiderWeights w) {
    var faceDown = 0;
    var offSuit = 0;
    var broken = 0;
    var empty = 0;
    var cover = 0;
    for (var c = 0; c < _columns; c++) {
      final n = length[c];
      if (n == 0) {
        empty++;
        continue;
      }
      faceDown += down[c];
      if (down[c] > 0) cover += n - down[c];
      final base = c * _stride;
      for (var i = down[c] + 1; i < n; i++) {
        final below = cards[base + i - 1];
        final card = cards[base + i];
        if (_rankOf(below) != _rankOf(card) + 1) {
          broken++;
        } else if (_suitOf(below) != _suitOf(card)) {
          offSuit++;
        }
      }
    }
    var stock = 0;
    for (var d = stockDeals.length - dealsLeft; d < stockDeals.length; d++) {
      stock += stockDeals[d].length;
    }
    return w.faceDown * faceDown +
        w.offSuit * offSuit +
        w.broken * broken +
        w.stockCard * stock -
        w.emptyColumn * empty -
        w.run * runs +
        w.cover * cover;
  }

  /// Candidate moves (see the library comment).
  void moves(List<int> out) {
    out.clear();
    var firstEmpty = -1;
    var allFilled = true;
    for (var c = 0; c < _columns; c++) {
      if (length[c] == 0) {
        allFilled = false;
        if (firstEmpty < 0) firstEmpty = c;
      }
    }
    for (var c = 0; c < _columns; c++) {
      final n = length[c];
      if (n == 0) continue;
      final s = runStart(c);
      final count = n - s;
      final bottom = card(c, s);
      final rank = _rankOf(bottom);
      for (var t = 0; t < _columns; t++) {
        if (t == c || length[t] == 0) continue;
        final onto = top(t);
        if (_rankOf(onto) == rank + 1) out.add(_columnMove(c, count, t));
      }
      if (firstEmpty >= 0 && s > 0) out.add(_columnMove(c, count, firstEmpty));
    }
    if (allFilled && dealsLeft > 0) out.add(_dealMove);
  }

  void apply(int m) {
    if (m == _dealMove) {
      deal();
    } else {
      move(m >> 12, (m >> 4) & 0xFF, m & 0xF);
    }
  }
}

SpiderMove _spiderMove(int m) => m == _dealMove
    ? const StockDeal()
    : ColumnMove(m >> 12, (m >> 4) & 0xFF, m & 0xF);

class _Search {
  _Search(this.board, this.weights, this.maxNodes);

  final _Board board;
  final SpiderWeights weights;
  final int maxNodes;

  final _seen = HashSet<int>();
  final _parents = <int>[];
  final _moves = <int>[];
  final _depths = <int>[];

  /// Open boards: priority, insertion order, node.
  final _open = _Heap();
  final _states = <int, Uint8List>{};
  int _nodes = 0;

  SolveResult run() {
    if (board.isWon) return SolveResult(SolveStatus.solved, 0);
    _seen.add(board.hash());
    _add(-1, 0, 0, board.save(), 0);
    final moves = <int>[];
    final child = _Board._copy(board);
    while (_open.isNotEmpty) {
      if (_nodes >= maxNodes) return SolveResult(SolveStatus.unknown, _nodes);
      final node = _open.pop();
      final state = _states.remove(node)!;
      _nodes++;
      board.load(state);
      board.moves(moves);
      final depth = _depths[node] + 1;
      for (final m in moves) {
        child.load(state);
        child.apply(m);
        if (child.isWon) {
          return SolveResult(SolveStatus.solved, _nodes, _path(node, m));
        }
        if (!_seen.add(child.hash())) continue;
        _add(
          node,
          m,
          depth,
          child.save(),
          child.evaluate(weights) + weights.move * depth,
        );
      }
      if (_open.length > SpiderSolver.maxOpen) _prune();
    }
    return SolveResult(SolveStatus.unsolvable, _nodes);
  }

  void _add(int parent, int move, int depth, Uint8List state, double value) {
    final node = _parents.length;
    _parents.add(parent);
    _moves.add(move);
    _depths.add(depth);
    _states[node] = state;
    _open.push(value, node);
  }

  /// Keeps the better half of the open list.
  void _prune() {
    for (final node in _open.dropWorseHalf()) {
      _states.remove(node);
    }
  }

  List<SpiderMove> _path(int node, int last) {
    final moves = [last];
    for (var n = node; _parents[n] >= 0; n = _parents[n]) {
      moves.add(_moves[n]);
    }
    return [for (final m in moves.reversed) _spiderMove(m)];
  }
}

/// A binary min-heap of nodes by value, the latest first among equals.
class _Heap {
  final _values = <double>[];
  final _orders = <int>[];
  final _nodes = <int>[];
  int _serial = 0;

  int get length => _nodes.length;
  bool get isNotEmpty => _nodes.isNotEmpty;

  bool _less(int a, int b) =>
      _values[a] < _values[b] ||
      (_values[a] == _values[b] && _orders[a] > _orders[b]);

  void _swap(int a, int b) {
    final v = _values[a];
    _values[a] = _values[b];
    _values[b] = v;
    final o = _orders[a];
    _orders[a] = _orders[b];
    _orders[b] = o;
    final n = _nodes[a];
    _nodes[a] = _nodes[b];
    _nodes[b] = n;
  }

  void push(double value, int node) {
    _values.add(value);
    _orders.add(_serial++);
    _nodes.add(node);
    var i = _nodes.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_less(i, parent)) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _nodes[0];
    final last = _nodes.length - 1;
    _swap(0, last);
    _values.removeLast();
    _orders.removeLast();
    _nodes.removeLast();
    var i = 0;
    final n = _nodes.length;
    while (true) {
      final left = 2 * i + 1;
      if (left >= n) break;
      var best = left;
      if (left + 1 < n && _less(left + 1, left)) best = left + 1;
      if (!_less(best, i)) break;
      _swap(i, best);
      i = best;
    }
    return top;
  }

  /// Removes the worse half and returns its nodes.
  List<int> dropWorseHalf() {
    final order = List.generate(_nodes.length, (i) => i)
      ..sort((a, b) => _less(a, b) ? -1 : (_less(b, a) ? 1 : 0));
    final keep = order.sublist(0, order.length ~/ 2);
    final dropped = [for (final i in order.skip(keep.length)) _nodes[i]];
    final values = [for (final i in keep) _values[i]];
    final orders = [for (final i in keep) _orders[i]];
    final nodes = [for (final i in keep) _nodes[i]];
    // A sorted array is a heap.
    _values
      ..clear()
      ..addAll(values);
    _orders
      ..clear()
      ..addAll(orders);
    _nodes
      ..clear()
      ..addAll(nodes);
    return dropped;
  }
}
