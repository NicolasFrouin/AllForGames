/// A FreeCell solver, used offline to prove deals winnable and to grade
/// them. Pure Dart: it runs in the generator tool and in tests, never in the
/// app.
///
/// Technique: best-first search on a heuristic (cards left, cards above the
/// next card of each foundation, broken sequences, busy cells), with a
/// transposition table on canonical states (cells and cascades are
/// interchangeable, so they are sorted). A move of several cards (a
/// "supermove") is one move, within the limit of the rules. Safe moves to
/// the foundations ([FreeCellState.isSafeToFoundation]) are played
/// automatically after each move, as the game does.
///
/// The search is sound but not complete: a [SolveStatus.solved] result always
/// replays to a win, while [SolveStatus.unsolvable] only means that the
/// search space (with the moves it tries) is exhausted.
library;

import 'dart:collection';
import 'dart:typed_data';

import '../../cards/playing_card.dart';
import 'freecell_difficulty.dart';
import 'freecell_state.dart';

/// One move of a solution, to replay with [FreeCellState.move].
class FreeCellMove {
  const FreeCellMove(this.from, this.count, this.to);

  final FreeCellPile from;
  final int count;
  final FreeCellPile to;

  @override
  bool operator ==(Object other) =>
      other is FreeCellMove &&
      other.from == from &&
      other.count == count &&
      other.to == to;

  @override
  int get hashCode => Object.hash(from, count, to);

  @override
  String toString() => 'move($from, $count, $to)';
}

/// Plays [moves] from [state]. Returns null as soon as one is illegal.
FreeCellState? replayMoves(FreeCellState state, Iterable<FreeCellMove> moves) {
  var current = state;
  for (final move in moves) {
    final next = current.move(move.from, move.count, move.to);
    if (next == null) return null;
    current = next;
  }
  return current;
}

enum SolveStatus {
  solved,

  /// The search space was exhausted without a win.
  unsolvable,

  /// The node budget ran out first.
  unknown,
}

class SolveResult {
  const SolveResult(this.status, this.nodes, [this.solution = const []]);

  final SolveStatus status;

  /// States expanded by the search.
  final int nodes;

  /// Winning moves when [status] is [SolveStatus.solved], else empty. The
  /// automatic moves to the foundations are in it too.
  final List<FreeCellMove> solution;

  bool get isSolved => status == SolveStatus.solved;

  @override
  String toString() =>
      'SolveResult(${status.name}, $nodes nodes, ${solution.length} moves)';
}

/// The rules that grade a deal into a [FreeCellDifficulty].
///
/// Changing them (or the solver's moves or heuristic) changes the grades:
/// rerun `dart run tool/generate_freecell_deals.dart` afterwards.
abstract final class FreeCellGrading {
  /// Node budget of the solver for a deal; beyond it the deal is unknown and
  /// never offered.
  static const maxNodes = 200000;

  /// Node budget of the search with [mediumCells] free cells.
  static const fewCellsMaxNodes = 100000;

  /// A deal the greedy player loses is medium when the solver wins it with
  /// this many free cells only (within [fewCellsMaxNodes]), else hard.
  static const mediumCells = 2;
}

/// Grading metrics of one deal.
class FreeCellDealGrade {
  const FreeCellDealGrade({
    required this.seed,
    required this.greedyWins,
    required this.result,
    required this.fewCells,
  });

  final int seed;

  /// Whether [FreeCellSolver.playGreedy] wins the deal.
  final bool greedyWins;

  /// The search with the 4 free cells.
  final SolveResult result;

  /// The search with [FreeCellGrading.mediumCells] free cells; null when it
  /// did not run (the greedy player won).
  final SolveResult? fewCells;

  /// Null when the solver could not prove the deal winnable.
  FreeCellDifficulty? get difficulty {
    if (!result.isSolved) return null;
    if (greedyWins) return FreeCellDifficulty.easy;
    return (fewCells?.isSolved ?? false)
        ? FreeCellDifficulty.medium
        : FreeCellDifficulty.hard;
  }
}

/// Proves FreeCell states winnable (see the library comment) and grades
/// deals.
class FreeCellSolver {
  const FreeCellSolver();

  static const defaultMaxNodes = FreeCellGrading.maxNodes;

  /// Searches a win from [state] with the first [cells] free cells only
  /// (the others must be empty).
  SolveResult solve(
    FreeCellState state, {
    int maxNodes = defaultMaxNodes,
    int cells = 4,
  }) => _Search(_Board.from(state, cells), maxNodes).run();

  /// Plays [state] like a player who looks one move ahead and never takes
  /// a move back: each turn, the move (and the safe moves to the
  /// foundations that follow it) that gives the best looking board (the
  /// heuristic of the search) and a board not seen before. It gives up after
  /// [maxMoves] moves or when every move leads to a board seen before.
  ///
  /// Returns the winning moves, or null when this player loses.
  List<FreeCellMove>? playGreedy(FreeCellState state, {int maxMoves = 400}) =>
      _Board.from(state, 4).playGreedy(maxMoves);

  /// Grades the deal of [seed] (see [FreeCellGrading]).
  FreeCellDealGrade grade(int seed) {
    final state = FreeCellState.deal(seed);
    final greedyWins = playGreedy(state) != null;
    return FreeCellDealGrade(
      seed: seed,
      greedyWins: greedyWins,
      result: solve(state, maxNodes: FreeCellGrading.maxNodes),
      fewCells: greedyWins
          ? null
          : solve(
              state,
              maxNodes: FreeCellGrading.fewCellsMaxNodes,
              cells: FreeCellGrading.mediumCells,
            ),
    );
  }
}

// Cards are ints: suit index * 13 + rank - 1. Piles are the indexes of
// FreeCellPile.all: cells 0-3, foundations 4-7, cascades 8-15. A move is
// `from | to << 4 | count << 8`.

const _empty = -1;
final List<bool> _redSuit = [for (final suit in Suit.values) suit.isRed];

int _suitOf(int card) => card ~/ 13;
int _rankOf(int card) => card % 13 + 1;

/// Whether [card] may be put on [onto] in a cascade.
bool _canStack(int card, int onto) =>
    _redSuit[card ~/ 13] != _redSuit[onto ~/ 13] && onto % 13 == card % 13 + 1;

int _move(int from, int to, int count) => from | to << 4 | count << 8;

FreeCellMove _toMove(int move) => FreeCellMove(
  FreeCellPile.all[move & 15],
  move >> 8,
  FreeCellPile.all[move >> 4 & 15],
);

/// Mutable board for the search.
class _Board {
  _Board(this.cellCount);

  factory _Board.from(FreeCellState state, int cellCount) {
    final board = _Board(cellCount);
    for (var i = 0; i < 4; i++) {
      final card = state.cells[i];
      if (card != null && i >= cellCount) {
        throw ArgumentError('Cell $i is not empty');
      }
      board.cells[i] = card == null ? _empty : _cardOf(card);
      board.foundations[i] = state.foundations[i].length;
    }
    for (var c = 0; c < 8; c++) {
      board.cascades[c].addAll(state.cascades[c].map(_cardOf));
    }
    board.foundationCount = state.foundationCardCount;
    return board;
  }

  static int _cardOf(PlayingCard card) => card.suit.index * 13 + card.rank - 1;

  /// Free cells the search may use: the first ones.
  final int cellCount;
  final List<int> cells = List.filled(4, _empty);

  /// Cards on each foundation, by suit index.
  final List<int> foundations = List.filled(4, 0);
  int foundationCount = 0;
  final List<List<int>> cascades = List.generate(8, (_) => <int>[]);

  bool get isWon => foundationCount == 52;

  /// The board in a few bytes: foundations, cells, then each cascade as its
  /// length and cards.
  Uint8List snapshot() {
    var length = 16;
    for (final cascade in cascades) {
      length += cascade.length;
    }
    final data = Uint8List(length);
    var n = 0;
    for (var i = 0; i < 4; i++) {
      data[n++] = foundations[i];
    }
    for (var i = 0; i < 4; i++) {
      data[n++] = cells[i] & 0xFF;
    }
    for (final cascade in cascades) {
      data[n++] = cascade.length;
      for (final card in cascade) {
        data[n++] = card;
      }
    }
    return data;
  }

  void load(Uint8List data) {
    var n = 0;
    foundationCount = 0;
    for (var i = 0; i < 4; i++) {
      foundations[i] = data[n++];
      foundationCount += foundations[i];
    }
    for (var i = 0; i < 4; i++) {
      final cell = data[n++];
      cells[i] = cell == 0xFF ? _empty : cell;
    }
    for (final cascade in cascades) {
      final length = data[n++];
      cascade.clear();
      for (var i = 0; i < length; i++) {
        cascade.add(data[n++]);
      }
    }
  }

  int _freeCells() {
    var free = 0;
    for (var i = 0; i < cellCount; i++) {
      if (cells[i] == _empty) free++;
    }
    return free;
  }

  int _emptyCascades() {
    var empty = 0;
    for (final cascade in cascades) {
      if (cascade.isEmpty) empty++;
    }
    return empty;
  }

  int _maxRun(int freeCells, int emptyCascades, {required bool toEmpty}) =>
      (freeCells + 1) << (toEmpty ? emptyCascades - 1 : emptyCascades);

  static int _runStart(List<int> cascade) {
    var start = cascade.length - 1;
    while (start > 0 && _canStack(cascade[start], cascade[start - 1])) {
      start--;
    }
    return start;
  }

  /// Moves [count] cards from pile [from] to pile [to], without checks.
  void apply(int from, int to, int count) {
    if (from < 4) {
      final card = cells[from];
      cells[from] = _empty;
      _put(to, card);
    } else if (from < 8) {
      final suit = from - 4;
      foundations[suit]--;
      foundationCount--;
      _put(to, suit * 13 + foundations[suit]);
    } else {
      final source = cascades[from - 8];
      final start = source.length - count;
      if (to >= 8) {
        cascades[to - 8].addAll(source.getRange(start, source.length));
      } else {
        _put(to, source[start]);
      }
      source.length = start;
    }
  }

  void _put(int to, int card) {
    if (to < 4) {
      cells[to] = card;
    } else if (to < 8) {
      foundations[to - 4]++;
      foundationCount++;
    } else {
      cascades[to - 8].add(card);
    }
  }

  bool _canFound(int card) => foundations[_suitOf(card)] == _rankOf(card) - 1;

  /// [FreeCellState.isSafeToFoundation] for a card that fits its foundation.
  bool _isSafe(int card) {
    final rank = _rankOf(card);
    if (rank <= 2) return true;
    final suit = _suitOf(card);
    final red = _redSuit[suit];
    var oppositeLow = 13;
    var sameColour = 13;
    for (var s = 0; s < 4; s++) {
      if (s == suit) continue;
      if (_redSuit[s] == red) {
        sameColour = foundations[s];
      } else if (foundations[s] < oppositeLow) {
        oppositeLow = foundations[s];
      }
    }
    return oppositeLow >= rank - 1 ||
        (oppositeLow >= rank - 2 && sameColour >= rank - 3);
  }

  /// Plays safe moves to the foundations until none is left, appending them
  /// to [moves].
  void autoplay(List<int> moves) {
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < 4; i++) {
        final card = cells[i];
        if (card != _empty && _canFound(card) && _isSafe(card)) {
          final to = 4 + _suitOf(card);
          apply(i, to, 1);
          moves.add(_move(i, to, 1));
          changed = true;
        }
      }
      for (var c = 0; c < 8; c++) {
        final cascade = cascades[c];
        if (cascade.isEmpty) continue;
        final card = cascade.last;
        if (_canFound(card) && _isSafe(card)) {
          final to = 4 + _suitOf(card);
          apply(8 + c, to, 1);
          moves.add(_move(8 + c, to, 1));
          changed = true;
        }
      }
    }
  }

  /// Candidate moves (see [FreeCellSolver]). Only the first free cell and
  /// the first empty cascade are tried: the others are alike.
  List<int> moves() {
    final moves = <int>[];
    final freeCells = _freeCells();
    final emptyCascades = _emptyCascades();
    var firstCell = -1;
    for (var i = 0; i < cellCount; i++) {
      if (cells[i] == _empty) {
        firstCell = i;
        break;
      }
    }
    var firstEmpty = -1;
    for (var c = 0; c < 8; c++) {
      if (cascades[c].isEmpty) {
        firstEmpty = c;
        break;
      }
    }
    final maxRun = _maxRun(freeCells, emptyCascades, toEmpty: false);
    final maxRunToEmpty = emptyCascades == 0
        ? 0
        : _maxRun(freeCells, emptyCascades, toEmpty: true);

    // To the foundations (the safe moves were played already).
    for (var i = 0; i < 4; i++) {
      final card = cells[i];
      if (card != _empty && _canFound(card)) {
        moves.add(_move(i, 4 + _suitOf(card), 1));
      }
    }
    for (var c = 0; c < 8; c++) {
      final cascade = cascades[c];
      if (cascade.isNotEmpty && _canFound(cascade.last)) {
        moves.add(_move(8 + c, 4 + _suitOf(cascade.last), 1));
      }
    }

    // Runs onto other cascades: the part of the run that fits the target.
    for (var c = 0; c < 8; c++) {
      final source = cascades[c];
      if (source.isEmpty) continue;
      final start = _runStart(source);
      final topRank = _rankOf(source.last);
      for (var t = 0; t < 8; t++) {
        final target = cascades[t];
        if (t == c || target.isEmpty) continue;
        final onto = target.last;
        // The card of the run one rank below the target card.
        final count = _rankOf(onto) - topRank;
        if (count < 1 || count > source.length - start || count > maxRun) {
          continue;
        }
        if (_canStack(source[source.length - count], onto)) {
          moves.add(_move(8 + c, 8 + t, count));
        }
      }
    }

    // Cells onto the cascades.
    for (var i = 0; i < 4; i++) {
      final card = cells[i];
      if (card == _empty) continue;
      for (var t = 0; t < 8; t++) {
        final target = cascades[t];
        if (target.isEmpty ? t == firstEmpty : _canStack(card, target.last)) {
          moves.add(_move(i, 8 + t, 1));
        }
      }
    }

    // Runs into an empty cascade, every length but a whole cascade.
    if (firstEmpty >= 0) {
      for (var c = 0; c < 8; c++) {
        final source = cascades[c];
        if (source.isEmpty) continue;
        final run = source.length - _runStart(source);
        final longest = run < maxRunToEmpty ? run : maxRunToEmpty;
        for (var count = longest; count >= 1; count--) {
          if (count == source.length) continue;
          moves.add(_move(8 + c, 8 + firstEmpty, count));
        }
      }
    }

    // Top cards into a free cell.
    if (firstCell >= 0) {
      for (var c = 0; c < 8; c++) {
        if (cascades[c].isNotEmpty) moves.add(_move(8 + c, firstCell, 1));
      }
    }
    return moves;
  }

  /// Lower is better: cards still out, cards above the next card of each
  /// foundation, cards that break a sequence, busy cells and few empty
  /// cascades.
  int heuristic() {
    var blocked = 0;
    for (var s = 0; s < 4; s++) {
      if (foundations[s] == 13) continue;
      final next = s * 13 + foundations[s];
      for (final cascade in cascades) {
        final at = cascade.indexOf(next);
        if (at >= 0) {
          blocked += cascade.length - 1 - at;
          break;
        }
      }
    }
    var breaks = 0;
    for (final cascade in cascades) {
      for (var i = 1; i < cascade.length; i++) {
        if (!_canStack(cascade[i], cascade[i - 1])) breaks++;
      }
    }
    final busyCells = cellCount - _freeCells();
    final empty = _emptyCascades();
    // Weights tuned on deals 1 to 800; on deals 1 to 1500 the search wins
    // 99.7% within the budget, half of them within 100 nodes.
    return 3 * (52 - foundationCount) +
        2 * blocked +
        4 * breaks +
        3 * busyCells -
        4 * empty;
  }

  final Uint8List _keyBuffer = Uint8List(80);
  final List<int> _order = List.filled(8, 0);

  /// Canonical transposition key: the foundations, the cells sorted and the
  /// cascades sorted by their bottom card (empty ones left out).
  String key() {
    final buffer = _keyBuffer;
    var n = 0;
    for (var s = 0; s < 4; s++) {
      buffer[n++] = foundations[s];
    }
    // Insertion sort of the 4 cells (empty is 255, last).
    final first = n;
    for (var i = 0; i < 4; i++) {
      final cell = cells[i] & 0xFF;
      var j = n;
      while (j > first && buffer[j - 1] > cell) {
        buffer[j] = buffer[j - 1];
        j--;
      }
      buffer[j] = cell;
      n++;
    }
    var count = 0;
    for (var c = 0; c < 8; c++) {
      if (cascades[c].isEmpty) continue;
      final bottom = cascades[c].first;
      var j = count;
      while (j > 0 && cascades[_order[j - 1]].first > bottom) {
        _order[j] = _order[j - 1];
        j--;
      }
      _order[j] = c;
      count++;
    }
    for (var i = 0; i < count; i++) {
      buffer[n++] = 100;
      for (final card in cascades[_order[i]]) {
        buffer[n++] = card;
      }
    }
    return String.fromCharCodes(buffer, 0, n);
  }

  List<FreeCellMove>? playGreedy(int maxMoves) {
    final seen = HashSet<String>()..add(key());
    final path = <int>[];
    for (var turn = 0; turn < maxMoves && !isWon; turn++) {
      final start = snapshot();
      Uint8List? best;
      String? bestKey;
      List<int>? bestMoves;
      var bestScore = 0;
      for (final move in moves()) {
        load(start);
        final played = [move];
        apply(move & 15, move >> 4 & 15, move >> 8);
        autoplay(played);
        final boardKey = key();
        if (seen.contains(boardKey)) continue;
        final score = heuristic();
        if (best == null || score < bestScore) {
          best = snapshot();
          bestKey = boardKey;
          bestMoves = played;
          bestScore = score;
        }
      }
      if (best == null) return null;
      load(best);
      seen.add(bestKey!);
      path.addAll(bestMoves!);
    }
    return isWon ? [for (final move in path) _toMove(move)] : null;
  }
}

/// Best-first search with a binary heap of node indexes.
class _Search {
  _Search(this.board, this.maxNodes);

  final _Board board;
  final int maxNodes;
  final _seen = HashSet<String>();

  // Nodes: the board, the node it came from, and the moves from there.
  final _boards = <Uint8List>[];
  final _parents = <int>[];
  final _moves = <List<int>>[];

  // The heap holds `priority * 2^24 + 2^24 - 1 - node`: the lowest
  // heuristic first, then the newest node.
  static const _nodeRange = 1 << 24;
  final _heap = <int>[];

  SolveResult run() {
    final rootMoves = <int>[];
    board.autoplay(rootMoves);
    _seen.add(board.key());
    _add(-1, rootMoves);
    var nodes = 0;
    while (_heap.isNotEmpty) {
      final node = _nodeRange - 1 - _pop() % _nodeRange;
      board.load(_boards[node]);
      if (board.isWon) {
        return SolveResult(SolveStatus.solved, nodes, _solution(node));
      }
      if (nodes >= maxNodes) return SolveResult(SolveStatus.unknown, nodes);
      nodes++;
      final start = _boards[node];
      for (final move in board.moves()) {
        board.load(start);
        final played = [move];
        board.apply(move & 15, move >> 4 & 15, move >> 8);
        board.autoplay(played);
        if (_seen.add(board.key())) _add(node, played);
      }
    }
    return SolveResult(SolveStatus.unsolvable, nodes);
  }

  void _add(int parent, List<int> moves) {
    final node = _boards.length;
    _boards.add(board.snapshot());
    _parents.add(parent);
    _moves.add(moves);
    final priority = board.isWon ? 0 : board.heuristic() + 1000;
    _push(priority * _nodeRange + _nodeRange - 1 - node);
  }

  List<FreeCellMove> _solution(int node) {
    final chain = <List<int>>[];
    for (var at = node; at >= 0; at = _parents[at]) {
      chain.add(_moves[at]);
    }
    return [
      for (final moves in chain.reversed)
        for (final move in moves) _toMove(move),
    ];
  }

  void _push(int value) {
    final heap = _heap..add(value);
    var i = heap.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (heap[parent] <= value) break;
      heap[i] = heap[parent];
      i = parent;
    }
    heap[i] = value;
  }

  int _pop() {
    final heap = _heap;
    final top = heap.first;
    final last = heap.removeLast();
    if (heap.isEmpty) return top;
    var i = 0;
    final n = heap.length;
    while (true) {
      var child = 2 * i + 1;
      if (child >= n) break;
      if (child + 1 < n && heap[child + 1] < heap[child]) child++;
      if (heap[child] >= last) break;
      heap[i] = heap[child];
      i = child;
    }
    heap[i] = last;
    return top;
  }
}
