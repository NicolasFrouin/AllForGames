/// A "thoughtful" Klondike solver (it sees the face-down cards), used offline
/// to prove deals winnable and to grade them. Pure Dart: it runs in the
/// generator tool and in tests, never in the app.
///
/// Technique, after Blake & Gent, "The Winnability of Klondike Solitaire and
/// Many Other Patience Games" (arXiv:1906.12314, JAIR):
/// - depth-first search with a transposition table on canonical states
///   (fully face-up columns are interchangeable, so they are sorted);
/// - the stock and waste form one "talon": a move may take any card that
///   draws alone can bring to the top of the waste (K+ representation); it
///   expands to that many `draw` actions plus one move;
/// - safe foundation moves are played automatically (dominances);
/// - pointless moves are pruned (see [_Board._moves]).
///
/// The search is sound but not complete: a [SolveStatus.solved] result always
/// replays to a win, while [SolveStatus.unsolvable] only means that this
/// pruned search space is exhausted.
library;

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import '../../cards/playing_card.dart';
import 'klondike_difficulty.dart';
import 'klondike_state.dart';

/// One step of a solution, to replay with [KlondikeState.draw] and
/// [KlondikeState.move].
sealed class KlondikeAction {
  const KlondikeAction();

  /// The state after this action, or null when it is not legal in [state].
  KlondikeState? applyTo(KlondikeState state);
}

final class DrawAction extends KlondikeAction {
  const DrawAction();

  @override
  KlondikeState? applyTo(KlondikeState state) => state.draw()?.state;

  @override
  bool operator ==(Object other) => other is DrawAction;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'draw';
}

final class MoveAction extends KlondikeAction {
  const MoveAction(this.from, this.count, this.to);

  final PileRef from;
  final int count;
  final PileRef to;

  @override
  KlondikeState? applyTo(KlondikeState state) =>
      state.move(from, count, to)?.state;

  @override
  bool operator ==(Object other) =>
      other is MoveAction &&
      other.from == from &&
      other.count == count &&
      other.to == to;

  @override
  int get hashCode => Object.hash(from, count, to);

  @override
  String toString() => 'move($from, $count, $to)';
}

/// Plays [actions] from [state]. Returns null as soon as one is illegal.
KlondikeState? replayActions(
  KlondikeState state,
  Iterable<KlondikeAction> actions,
) {
  var current = state;
  for (final action in actions) {
    final next = action.applyTo(current);
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

  /// Distinct states expanded by the search.
  final int nodes;

  /// Winning actions when [status] is [SolveStatus.solved], else empty.
  final List<KlondikeAction> solution;

  bool get isSolved => status == SolveStatus.solved;

  @override
  String toString() =>
      'SolveResult(${status.name}, $nodes nodes, ${solution.length} actions)';
}

/// The rules that grade a deal into a [KlondikeDifficulty].
///
/// Changing them (or the solver's move ordering) changes the grades: rerun
/// `dart run tool/generate_klondike_deals.dart` afterwards.
abstract final class KlondikeGrading {
  /// Node budget of the solver for a deal; beyond it the deal is unknown and
  /// never offered.
  static const maxNodes = 100000;

  /// Above this many solver nodes, a deal the greedy player loses is hard.
  static const mediumMaxNodes = 1000;
}

/// Grading metrics of one deal.
class DealGrade {
  const DealGrade({
    required this.seed,
    required this.drawCount,
    required this.greedyWins,
    required this.result,
  });

  final int seed;
  final int drawCount;

  /// Whether [KlondikeSolver.playGreedy] wins the deal.
  final bool greedyWins;
  final SolveResult result;

  /// Null when the solver could not prove the deal winnable.
  KlondikeDifficulty? get difficulty {
    if (!result.isSolved) return null;
    if (greedyWins) return KlondikeDifficulty.easy;
    return result.nodes <= KlondikeGrading.mediumMaxNodes
        ? KlondikeDifficulty.medium
        : KlondikeDifficulty.hard;
  }
}

/// Proves Klondike states winnable (see the library comment) and grades
/// deals.
class KlondikeSolver {
  const KlondikeSolver();

  static const defaultMaxNodes = KlondikeGrading.maxNodes;

  SolveResult solve(KlondikeState state, {int maxNodes = defaultMaxNodes}) =>
      _Search(_Board.from(state), maxNodes).run();

  /// Plays [state] like a casual player: no lookahead, no undo, only the
  /// face-up cards are known. Each turn takes the first legal move of: any
  /// card to a foundation; a whole face-up run onto another column to turn
  /// a card (the column with most face-down cards first); the waste card
  /// onto the tableau; else draw. It gives up after a full pass through the
  /// stock without any other move.
  ///
  /// Returns the winning actions, or null when this player loses.
  List<KlondikeAction>? playGreedy(KlondikeState state) =>
      _Board.from(state).playGreedy();

  /// Grades the deal of [seed] (see [KlondikeGrading]).
  DealGrade grade(int seed, int drawCount) {
    final state = KlondikeState.deal(seed, drawCount: drawCount);
    return DealGrade(
      seed: seed,
      drawCount: drawCount,
      greedyWins: playGreedy(state) != null,
      result: solve(state, maxNodes: KlondikeGrading.maxNodes),
    );
  }
}

// Cards are ints: suit index * 13 + rank - 1.

final List<bool> _redSuit = [for (final suit in Suit.values) suit.isRed];

int _suitOf(int card) => card ~/ 13;
int _rankOf(int card) => card % 13 + 1;
bool _isKing(int card) => card % 13 == 12;

/// Whether [card] may be put on [onto] in the tableau.
bool _canStack(int card, int onto) =>
    _redSuit[card ~/ 13] != _redSuit[onto ~/ 13] && onto % 13 == card % 13 + 1;

PlayingCard _playingCard(int card) =>
    PlayingCard(Suit.values[_suitOf(card)], _rankOf(card));

const _tableauToFoundation = 0;
const _tableauToTableau = 1;
const _talonToFoundation = 2;
const _talonToTableau = 3;
const _foundationToTableau = 4;

/// A solver move. Talon moves take the card at waste pointer [from] (the
/// card `talon[from - 1]`) after [draws] draws.
final class _Move {
  _Move(
    this.kind,
    this.from,
    this.to,
    this.card, {
    this.count = 1,
    this.draws = 0,
  });

  final int kind;

  /// Column, talon pointer, or suit (foundation to tableau).
  final int from;

  /// Destination column (unused for foundation moves).
  final int to;
  final int card;
  final int count;
  final int draws;

  // Undo information, set by [_Board.apply].
  bool flipped = false;
  int oldPointer = 0;

  void addActionsTo(List<KlondikeAction> actions) {
    switch (kind) {
      case _tableauToFoundation:
        actions.add(
          MoveAction(
            PileRef.tableau(from),
            1,
            PileRef.foundation(_suitOf(card)),
          ),
        );
      case _tableauToTableau:
        actions.add(
          MoveAction(PileRef.tableau(from), count, PileRef.tableau(to)),
        );
      case _talonToFoundation || _talonToTableau:
        for (var i = 0; i < draws; i++) {
          actions.add(const DrawAction());
        }
        actions.add(
          MoveAction(
            PileRef.waste,
            1,
            kind == _talonToTableau
                ? PileRef.tableau(to)
                : PileRef.foundation(_suitOf(card)),
          ),
        );
      case _foundationToTableau:
        actions.add(
          MoveAction(PileRef.foundation(from), 1, PileRef.tableau(to)),
        );
    }
  }
}

/// Mutable board for the search, changed in place by [apply] and [undo].
class _Board {
  _Board.from(KlondikeState state) : drawCount = state.drawCount {
    for (var c = 0; c < 7; c++) {
      final pile = state.tableau[c];
      var faceDown = 0;
      while (faceDown < pile.length && !pile[faceDown].faceUp) {
        faceDown++;
      }
      if (pile.skip(faceDown).any((card) => !card.faceUp)) {
        throw ArgumentError('Face-down card above a face-up card in column $c');
      }
      columns[c].addAll(pile.map(_cardOf));
      down[c] = faceDown;
    }
    for (var s = 0; s < 4; s++) {
      foundations[s] = state.foundations[s].length;
    }
    foundationCount = state.foundationCardCount;
    talon
      ..addAll(state.waste.map(_cardOf))
      ..addAll(state.stock.reversed.map(_cardOf));
    pointer = state.waste.length;
  }

  static int _cardOf(PlayingCard card) => card.suit.index * 13 + card.rank - 1;

  final int drawCount;
  final List<List<int>> columns = List.generate(7, (_) => <int>[]);

  /// Face-down cards at the bottom of each column.
  final List<int> down = List.filled(7, 0);

  /// Cards on each foundation, by suit index.
  final List<int> foundations = List.filled(4, 0);
  int foundationCount = 0;

  /// The waste (bottom to top) followed by the stock (top to bottom), so that
  /// drawing only moves [pointer] forward and recycling resets it to 0. Cards
  /// never come back to the talon, so its order is fixed.
  final List<int> talon = [];

  /// Number of waste cards: `talon[pointer - 1]` is the top of the waste.
  int pointer = 0;

  bool get isWon => foundationCount == 52;

  bool _canFound(int card) => foundations[_suitOf(card)] == _rankOf(card) - 1;

  /// A foundation move that can never hurt (Blake & Gent's dominance): the
  /// card is at most 2 above both opposite-colour foundations and at most 3
  /// above the other foundation of its colour, so no card still needs it.
  bool _isSafe(int card) {
    final suit = _suitOf(card);
    final rank = _rankOf(card);
    if (foundations[suit] != rank - 1) return false;
    return rank <= 2 || _belowSafeLimit(suit, rank);
  }

  bool _belowSafeLimit(int suit, int rank) {
    final red = _redSuit[suit];
    for (var s = 0; s < 4; s++) {
      if (s == suit) continue;
      final limit = _redSuit[s] == red ? 3 : 2;
      if (rank > foundations[s] + limit) return false;
    }
    return true;
  }

  void apply(_Move m) {
    switch (m.kind) {
      case _tableauToFoundation:
        columns[m.from].removeLast();
        foundations[_suitOf(m.card)]++;
        foundationCount++;
        m.flipped = _flip(m.from);
      case _tableauToTableau:
        final source = columns[m.from];
        final start = source.length - m.count;
        columns[m.to].addAll(source.getRange(start, source.length));
        source.length = start;
        m.flipped = _flip(m.from);
      case _talonToFoundation:
        m.oldPointer = pointer;
        talon.removeAt(m.from - 1);
        pointer = m.from - 1;
        foundations[_suitOf(m.card)]++;
        foundationCount++;
      case _talonToTableau:
        m.oldPointer = pointer;
        talon.removeAt(m.from - 1);
        pointer = m.from - 1;
        columns[m.to].add(m.card);
      case _foundationToTableau:
        foundations[m.from]--;
        foundationCount--;
        columns[m.to].add(m.card);
    }
  }

  void undo(_Move m) {
    switch (m.kind) {
      case _tableauToFoundation:
        if (m.flipped) down[m.from]++;
        columns[m.from].add(m.card);
        foundations[_suitOf(m.card)]--;
        foundationCount--;
      case _tableauToTableau:
        if (m.flipped) down[m.from]++;
        final target = columns[m.to];
        final start = target.length - m.count;
        columns[m.from].addAll(target.getRange(start, target.length));
        target.length = start;
      case _talonToFoundation:
        foundations[_suitOf(m.card)]--;
        foundationCount--;
        talon.insert(m.from - 1, m.card);
        pointer = m.oldPointer;
      case _talonToTableau:
        columns[m.to].removeLast();
        talon.insert(m.from - 1, m.card);
        pointer = m.oldPointer;
      case _foundationToTableau:
        columns[m.to].removeLast();
        foundations[m.from]++;
        foundationCount++;
    }
  }

  /// Turns the top card of column [c] face up if it is face down.
  bool _flip(int c) {
    if (down[c] > 0 && columns[c].length == down[c]) {
      down[c]--;
      return true;
    }
    return false;
  }

  int? _faceUpTop(int c) {
    final column = columns[c];
    return column.length > down[c] ? column.last : null;
  }

  int _firstEmptyColumn() {
    for (var c = 0; c < 7; c++) {
      if (columns[c].isEmpty) return c;
    }
    return -1;
  }

  // Talon reachability, reused between calls.
  final Int32List _reachPointers = Int32List(64);
  final Int32List _reachDraws = Int32List(64);
  final Int32List _visited = Int32List(64);
  int _visitStamp = 0;

  /// Fills [_reachPointers] and [_reachDraws] with every waste pointer that
  /// draws alone can reach (each card that can become the top of the waste)
  /// and the fewest draws to get there. Returns how many there are.
  int _reachTalon() {
    final n = talon.length;
    if (n == 0) return 0;
    final stamp = ++_visitStamp;
    var count = 0;
    var current = pointer;
    for (var draws = 0; _visited[current] != stamp; draws++) {
      _visited[current] = stamp;
      if (current > 0) {
        _reachPointers[count] = current;
        _reachDraws[count] = draws;
        count++;
      }
      // A draw on an empty stock turns the waste over.
      current = current == n ? 0 : min(current + drawCount, n);
    }
    return count;
  }

  /// Plays safe foundation moves until none is left, appending them to
  /// [path]. Returns how many were played.
  int autoplay(List<_Move> path) {
    var played = 0;
    var changed = true;
    while (changed) {
      changed = false;
      for (var c = 0; c < 7; c++) {
        final top = _faceUpTop(c);
        if (top != null && _isSafe(top)) {
          final m = _Move(_tableauToFoundation, c, 0, top);
          apply(m);
          path.add(m);
          played++;
          changed = true;
        }
      }
      // In draw 1 every talon card stays reachable whatever is removed, so a
      // safe talon card can go too. In draw 3, removing a card changes which
      // cards later draws reveal, which is not always harmless.
      if (drawCount == 1) {
        final reachable = _reachTalon();
        for (var i = 0; i < reachable; i++) {
          final q = _reachPointers[i];
          final card = talon[q - 1];
          if (_isSafe(card)) {
            final m = _Move(
              _talonToFoundation,
              q,
              0,
              card,
              draws: _reachDraws[i],
            );
            apply(m);
            path.add(m);
            played++;
            changed = true;
            break; // The talon changed: compute the reachable cards again.
          }
        }
      }
    }
    return played;
  }

  /// When the talon is empty and every card is face up, each column is a
  /// run and the lowest card left is always on top of one: plays them all to
  /// the foundations. Returns false (and plays nothing) otherwise.
  bool finish(List<_Move> path) {
    if (talon.isNotEmpty || down.any((d) => d > 0)) return false;
    final start = path.length;
    while (!isWon) {
      var best = -1;
      for (var c = 0; c < 7; c++) {
        final top = _faceUpTop(c);
        if (top != null &&
            _canFound(top) &&
            (best < 0 || _rankOf(top) < _rankOf(columns[best].last))) {
          best = c;
        }
      }
      if (best < 0) {
        // Only possible in hand-made states whose columns are not runs.
        while (path.length > start) {
          undo(path.removeLast());
        }
        return false;
      }
      final m = _Move(_tableauToFoundation, best, 0, columns[best].last);
      apply(m);
      path.add(m);
    }
    return true;
  }

  /// Candidate moves, most promising first. Pruned:
  /// - a king at the bottom of a column never moves to an empty column, and
  ///   only the first empty column is tried (they are all alike);
  /// - a column with no face-down card is emptied only if a king could use
  ///   the space;
  /// - part of a face-up run moves only if the card it uncovers can go to a
  ///   foundation (then it does, as the next move);
  /// - a card leaves a foundation only if no dominance applies to it and a
  ///   card could then go on it.
  List<_Move> _moves() {
    final moves = <_Move>[];
    final reachable = _reachTalon();
    final empty = _firstEmptyColumn();

    // 1. Whole face-up runs that turn a card, most face-down cards first
    // (a total order, so that node counts never depend on the sort).
    final order = [for (var c = 0; c < 7; c++) c]
      ..sort((a, b) => down[a] != down[b] ? down[b] - down[a] : a - b);
    for (final c in order) {
      if (down[c] == 0 || columns[c].length == down[c]) continue;
      _addRunMoves(moves, c, down[c], empty);
    }

    // 2. To the foundations (the safe ones were played already).
    for (var c = 0; c < 7; c++) {
      final top = _faceUpTop(c);
      if (top != null && _canFound(top)) {
        moves.add(_Move(_tableauToFoundation, c, 0, top));
      }
    }
    for (var i = 0; i < reachable; i++) {
      final q = _reachPointers[i];
      final card = talon[q - 1];
      if (_canFound(card)) {
        moves.add(_Move(_talonToFoundation, q, 0, card, draws: _reachDraws[i]));
      }
    }

    // 3. Talon cards onto the tableau.
    for (var i = 0; i < reachable; i++) {
      final q = _reachPointers[i];
      final card = talon[q - 1];
      for (var t = 0; t < 7; t++) {
        if (_accepts(t, card, empty)) {
          moves.add(_Move(_talonToTableau, q, t, card, draws: _reachDraws[i]));
        }
      }
    }

    // 4. Whole columns without face-down cards, to make an empty column.
    if (_kingNeedsSpace()) {
      for (var c = 0; c < 7; c++) {
        final column = columns[c];
        if (down[c] > 0 || column.isEmpty || _isKing(column.first)) continue;
        _addRunMoves(moves, c, 0, -1);
      }
    }

    // 5. Part of a run, when it uncovers a card for the foundations.
    for (var c = 0; c < 7; c++) {
      final column = columns[c];
      for (var i = down[c] + 1; i < column.length; i++) {
        if (_canFound(column[i - 1])) _addRunMoves(moves, c, i, empty);
      }
    }

    // 6. Back from a foundation.
    for (var s = 0; s < 4; s++) {
      final rank = foundations[s];
      if (rank <= 2 || _belowSafeLimit(s, rank)) continue;
      final card = s * 13 + rank - 1;
      if (!_canFollow(card, reachable)) continue;
      for (var t = 0; t < 7; t++) {
        if (_accepts(t, card, empty)) {
          moves.add(_Move(_foundationToTableau, s, t, card));
        }
      }
    }
    return moves;
  }

  /// Whether [card] can go on column [t], [empty] being the only empty
  /// column worth trying (-1 for none).
  bool _accepts(int t, int card, int empty) {
    final column = columns[t];
    if (column.isEmpty) return t == empty && _isKing(card);
    return column.length > down[t] && _canStack(card, column.last);
  }

  void _addRunMoves(List<_Move> moves, int c, int start, int empty) {
    final column = columns[c];
    final base = column[start];
    for (var t = 0; t < 7; t++) {
      if (t != c && _accepts(t, base, empty)) {
        moves.add(
          _Move(_tableauToTableau, c, t, base, count: column.length - start),
        );
      }
    }
  }

  /// Whether a king that is not at the bottom of a column (or not yet
  /// visible) could use an empty column.
  bool _kingNeedsSpace() {
    for (final card in talon) {
      if (_isKing(card)) return true;
    }
    for (final column in columns) {
      for (var i = 1; i < column.length; i++) {
        if (_isKing(column[i])) return true;
      }
    }
    return false;
  }

  /// Whether a card that could go on [card] is face up or in the talon.
  bool _canFollow(int card, int reachable) {
    bool fits(int other) => _canStack(other, card);
    for (var i = 0; i < reachable; i++) {
      if (fits(talon[_reachPointers[i] - 1])) return true;
    }
    for (var c = 0; c < 7; c++) {
      final column = columns[c];
      for (var i = down[c]; i < column.length; i++) {
        if (fits(column[i])) return true;
      }
    }
    return false;
  }

  final Uint8List _keyBuffer = Uint8List(160);
  final List<int> _faceUpColumns = List.filled(7, 0);

  /// Canonical transposition key. The talon is not part of it: it holds the
  /// cards that are elsewhere in neither the tableau nor the foundations, in
  /// a fixed order. The face-down cards of a column are fixed too, so a
  /// column with face-down cards is its index and count. Columns without
  /// face-down cards are interchangeable, so they are sorted.
  String key() {
    final buffer = _keyBuffer;
    var n = 0;
    for (var s = 0; s < 4; s++) {
      buffer[n++] = foundations[s];
    }
    buffer[n++] = _canonicalPointer();
    var faceUpCount = 0;
    for (var c = 0; c < 7; c++) {
      final column = columns[c];
      if (down[c] == 0) {
        if (column.isNotEmpty) _faceUpColumns[faceUpCount++] = c;
        continue;
      }
      buffer[n++] = 100 + c;
      buffer[n++] = down[c];
      for (var i = down[c]; i < column.length; i++) {
        buffer[n++] = column[i];
      }
    }
    // Insertion sort by bottom card (all cards are distinct).
    for (var i = 1; i < faceUpCount; i++) {
      final c = _faceUpColumns[i];
      var j = i - 1;
      while (j >= 0 && columns[_faceUpColumns[j]].first > columns[c].first) {
        _faceUpColumns[j + 1] = _faceUpColumns[j];
        j--;
      }
      _faceUpColumns[j + 1] = c;
    }
    for (var i = 0; i < faceUpCount; i++) {
      buffer[n++] = 120;
      for (final card in columns[_faceUpColumns[i]]) {
        buffer[n++] = card;
      }
    }
    return String.fromCharCodes(buffer, 0, n);
  }

  /// Pointers with the same reachable cards have the same future: in draw 1
  /// every card is always reachable; in draw 3, a pointer on a multiple of 3
  /// or at the end reaches the same cards as an empty waste.
  int _canonicalPointer() {
    if (drawCount == 1) return 0;
    final p = pointer;
    return p % drawCount == 0 || p == talon.length ? 0 : p;
  }

  List<KlondikeAction>? playGreedy() {
    final actions = <KlondikeAction>[];
    // A move since the start or since the waste was last turned over.
    var progress = false;
    for (var turn = 0; turn < 10000; turn++) {
      if (isWon) return actions;
      final m = _greedyMove();
      if (m != null) {
        apply(m);
        m.addActionsTo(actions);
        progress = true;
        continue;
      }
      if (talon.isEmpty) return null;
      if (pointer == talon.length) {
        if (!progress) return null;
        progress = false;
        pointer = 0;
      } else {
        pointer = min(pointer + drawCount, talon.length);
      }
      actions.add(const DrawAction());
    }
    return null;
  }

  _Move? _greedyMove() {
    for (var c = 0; c < 7; c++) {
      final top = _faceUpTop(c);
      if (top != null && _canFound(top)) {
        return _Move(_tableauToFoundation, c, 0, top);
      }
    }
    final waste = pointer > 0 ? talon[pointer - 1] : null;
    if (waste != null && _canFound(waste)) {
      return _Move(_talonToFoundation, pointer, 0, waste);
    }
    final empty = _firstEmptyColumn();
    var bestSource = -1;
    var bestTarget = -1;
    for (var c = 0; c < 7; c++) {
      if (down[c] == 0 || columns[c].length == down[c]) continue;
      if (bestSource >= 0 && down[c] <= down[bestSource]) continue;
      final base = columns[c][down[c]];
      for (var t = 0; t < 7; t++) {
        if (t != c && _accepts(t, base, empty)) {
          bestSource = c;
          bestTarget = t;
          break;
        }
      }
    }
    if (bestSource >= 0) {
      final column = columns[bestSource];
      return _Move(
        _tableauToTableau,
        bestSource,
        bestTarget,
        column[down[bestSource]],
        count: column.length - down[bestSource],
      );
    }
    if (waste != null) {
      for (var t = 0; t < 7; t++) {
        if (_accepts(t, waste, empty)) {
          return _Move(_talonToTableau, pointer, t, waste);
        }
      }
    }
    return null;
  }

  @override
  String toString() {
    final piles = [
      for (var c = 0; c < 7; c++) '${down[c]}:${columns[c].map(_playingCard)}',
    ];
    return 'found $foundations, talon ${talon.map(_playingCard)} @$pointer, '
        'columns $piles';
  }
}

/// Iterative depth-first search (no recursion limit to worry about).
class _Search {
  _Search(this.board, this.maxNodes);

  final _Board board;
  final int maxNodes;
  final _seen = HashSet<String>();
  final _path = <_Move>[];
  final _frames = <_Frame>[];
  int _nodes = 0;

  SolveResult run() {
    var outcome = _enter();
    while (outcome == _Outcome.open && _frames.isNotEmpty) {
      final frame = _frames.last;
      if (frame.next < frame.moves.length) {
        final m = frame.moves[frame.next++];
        board.apply(m);
        _path.add(m);
        outcome = _enter();
        if (outcome == _Outcome.skipped) {
          board.undo(_path.removeLast());
          outcome = _Outcome.open;
        }
      } else {
        _frames.removeLast();
        for (var i = 0; i < frame.autoplayed; i++) {
          board.undo(_path.removeLast());
        }
        // Undo the move that led to this state (none for the root).
        if (_frames.isNotEmpty) board.undo(_path.removeLast());
      }
    }
    return switch (outcome) {
      _Outcome.solved => SolveResult(SolveStatus.solved, _nodes, _actions()),
      _Outcome.budget => SolveResult(SolveStatus.unknown, _nodes),
      _ => SolveResult(SolveStatus.unsolvable, _nodes),
    };
  }

  /// Enters the current state: autoplay, then either a result, a skip (seen
  /// before, the autoplay is undone) or a new frame to expand.
  _Outcome _enter() {
    final autoplayed = board.autoplay(_path);
    if (board.isWon || board.finish(_path)) return _Outcome.solved;
    if (!_seen.add(board.key())) {
      for (var i = 0; i < autoplayed; i++) {
        board.undo(_path.removeLast());
      }
      return _Outcome.skipped;
    }
    if (_nodes >= maxNodes) return _Outcome.budget;
    _nodes++;
    _frames.add(_Frame(board._moves(), autoplayed));
    return _Outcome.open;
  }

  List<KlondikeAction> _actions() {
    final actions = <KlondikeAction>[];
    for (final m in _path) {
      m.addActionsTo(actions);
    }
    return actions;
  }
}

enum _Outcome { open, skipped, solved, budget }

class _Frame {
  _Frame(this.moves, this.autoplayed);

  final List<_Move> moves;
  final int autoplayed;
  int next = 0;
}
