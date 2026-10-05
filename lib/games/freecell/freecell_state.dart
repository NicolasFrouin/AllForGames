import 'dart:math';

import '../../cards/deal_random.dart';
import '../../cards/playing_card.dart';

enum FreeCellPileType { cell, foundation, cascade }

/// A place for cards on the FreeCell table.
class FreeCellPile {
  const FreeCellPile._(this.type, this.index);

  const FreeCellPile.cell(int index) : this._(FreeCellPileType.cell, index);
  const FreeCellPile.foundation(int index)
    : this._(FreeCellPileType.foundation, index);
  const FreeCellPile.cascade(int index)
    : this._(FreeCellPileType.cascade, index);

  /// Every pile: the free cells, the foundations, then the cascades.
  static const all = [
    FreeCellPile.cell(0),
    FreeCellPile.cell(1),
    FreeCellPile.cell(2),
    FreeCellPile.cell(3),
    FreeCellPile.foundation(0),
    FreeCellPile.foundation(1),
    FreeCellPile.foundation(2),
    FreeCellPile.foundation(3),
    FreeCellPile.cascade(0),
    FreeCellPile.cascade(1),
    FreeCellPile.cascade(2),
    FreeCellPile.cascade(3),
    FreeCellPile.cascade(4),
    FreeCellPile.cascade(5),
    FreeCellPile.cascade(6),
    FreeCellPile.cascade(7),
  ];

  final FreeCellPileType type;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is FreeCellPile && other.type == type && other.index == index;

  @override
  int get hashCode => Object.hash(type, index);

  @override
  String toString() => '${type.name}[$index]';
}

/// The score of a game: [toFoundation] points per card that reaches a
/// foundation (the automatic moves too), and on a win a bonus for few moves.
/// An undo takes back the points of the action it undoes.
abstract final class FreeCellScoring {
  static const toFoundation = 10;

  /// 1000 points, minus 5 per move made (undone ones too), at least 0.
  static int winBonus(int moves) => max(0, 1000 - 5 * moves);
}

/// Immutable FreeCell board. The last card of each list is the top card.
///
/// Foundation `i` only holds cards of `Suit.values[i]`. Every card is face up.
class FreeCellState {
  FreeCellState({
    required List<PlayingCard?> cells,
    required List<List<PlayingCard>> foundations,
    required List<List<PlayingCard>> cascades,
  }) : assert(
         cells.length == 4 && foundations.length == 4 && cascades.length == 8,
       ),
       cells = List.unmodifiable(cells),
       foundations = List.unmodifiable(
         foundations.map(List<PlayingCard>.unmodifiable),
       ),
       cascades = List.unmodifiable(
         cascades.map(List<PlayingCard>.unmodifiable),
       );

  /// The deal of [seed], the same on every platform: the cards of
  /// [shuffledDeck], face up, row by row over the 8 cascades (card `i` goes
  /// to cascade `i % 8`), so the first four cascades get 7 cards and the
  /// others 6.
  ///
  /// **Never change this algorithm** (nor [shuffledDeck] and `DealRandom`):
  /// the seeds of `freecellDeals` were proven winnable for the exact deals it
  /// gives today.
  factory FreeCellState.deal(int seed) {
    final deck = shuffledDeck(seed);
    return FreeCellState(
      cells: const [null, null, null, null],
      foundations: const [[], [], [], []],
      cascades: [
        for (var c = 0; c < 8; c++)
          [
            for (var i = c; i < deck.length; i += 8)
              deck[i].turned(faceUp: true),
          ],
      ],
    );
  }

  /// Reads a board written by [encode]. Throws a [FormatException] unless
  /// [text] holds the 52 face-up cards once each, in 16 piles, with at most
  /// one card per cell and each foundation in order.
  factory FreeCellState.decode(String text) {
    final piles = text.split(',').map(_decodePile).toList();
    if (piles.length != 16) {
      throw FormatException('Not a FreeCell board', text);
    }
    final cards = piles.expand((pile) => pile).toList();
    if (cards.length != 52 ||
        cards.map((card) => card.id).toSet().length != 52) {
      throw FormatException('A board needs the 52 cards once each', text);
    }
    if (cards.any((card) => !card.faceUp)) {
      throw FormatException('FreeCell cards are face up', text);
    }
    if (piles.take(4).any((cell) => cell.length > 1)) {
      throw FormatException('A free cell holds one card', text);
    }
    for (var i = 0; i < 4; i++) {
      final foundation = piles[4 + i];
      for (var j = 0; j < foundation.length; j++) {
        if (foundation[j].suit.index != i || foundation[j].rank != j + 1) {
          throw FormatException('Foundation $i is not in order', text);
        }
      }
    }
    return FreeCellState(
      cells: [for (final cell in piles.take(4)) cell.firstOrNull],
      foundations: piles.sublist(4, 8),
      cascades: piles.sublist(8),
    );
  }

  /// Null for an empty cell.
  final List<PlayingCard?> cells;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> cascades;

  /// Compact text of the board for saves: the 16 piles (cells, foundations,
  /// cascades) joined by commas, each pile as the [PlayingCard.code]s of its
  /// cards from bottom to top.
  String encode() => FreeCellPile.all
      .map((ref) => pile(ref).map((card) => card.code).join())
      .join(',');

  /// The cards of [ref], bottom first: a cell has none or one.
  List<PlayingCard> pile(FreeCellPile ref) => switch (ref.type) {
    FreeCellPileType.cell => [?cells[ref.index]],
    FreeCellPileType.foundation => foundations[ref.index],
    FreeCellPileType.cascade => cascades[ref.index],
  };

  int get foundationCardCount =>
      foundations.fold(0, (sum, pile) => sum + pile.length);

  int get freeCellCount => cells.where((card) => card == null).length;

  int get usedCellCount => 4 - freeCellCount;

  int get emptyCascadeCount => cascades.where((pile) => pile.isEmpty).length;

  bool get isWon => foundationCardCount == 52;

  /// How many cards can move at once, one by one through the free cells and
  /// empty cascades: (free cells + 1) × 2^(empty cascades). The empty cascade
  /// that receives the cards does not count.
  int maxRunLength({required bool toEmptyCascade}) {
    final empty = emptyCascadeCount - (toEmptyCascade ? 1 : 0);
    return (freeCellCount + 1) << max(0, empty);
  }

  /// Whether [card] can go on [onto] in a cascade: one rank lower, the other
  /// colour.
  static bool canStack(PlayingCard card, PlayingCard onto) =>
      card.suit.isRed != onto.suit.isRed && onto.rank == card.rank + 1;

  /// Index of the lowest card of the run at the top of [cascade]: the cards
  /// from there up go down by one in alternating colours. The length for an
  /// empty cascade.
  static int runStart(List<PlayingCard> cascade) {
    if (cascade.isEmpty) return 0;
    var start = cascade.length - 1;
    while (start > 0 && canStack(cascade[start], cascade[start - 1])) {
      start--;
    }
    return start;
  }

  /// Whether the top [count] cards of [from] can be put on [to].
  bool canMove(FreeCellPile from, int count, FreeCellPile to) {
    if (from == to || count < 1) return false;
    final source = pile(from);
    if (count > source.length) return false;
    switch (from.type) {
      case FreeCellPileType.foundation:
        return false;
      case FreeCellPileType.cell:
        if (count != 1) return false;
      case FreeCellPileType.cascade:
        if (source.length - count < runStart(source)) return false;
    }
    final moving = source[source.length - count];
    switch (to.type) {
      case FreeCellPileType.cell:
        return count == 1 && cells[to.index] == null;
      case FreeCellPileType.foundation:
        return count == 1 &&
            moving.suit.index == to.index &&
            moving.rank == foundations[to.index].length + 1;
      case FreeCellPileType.cascade:
        final target = cascades[to.index];
        if (target.isEmpty) {
          return count <= maxRunLength(toEmptyCascade: true);
        }
        return canStack(moving, target.last) &&
            count <= maxRunLength(toEmptyCascade: false);
    }
  }

  /// Returns null when the move is not legal.
  FreeCellState? move(FreeCellPile from, int count, FreeCellPile to) {
    if (!canMove(from, count, to)) return null;
    final source = pile(from);
    final moving = source.sublist(source.length - count);
    return _withPile(
      from,
      source.sublist(0, source.length - count),
    )._withPile(to, [...pile(to), ...moving]);
  }

  /// Where a tap on the top [count] cards of [from] sends them: their
  /// foundation; else the cascade that accepts them on the longest run (the
  /// leftmost of equals); else a free cell for a single card; else an empty
  /// cascade (never a whole cascade into another empty one). Null when they
  /// cannot move.
  FreeCellPile? tapTarget(FreeCellPile from, int count) {
    final source = pile(from);
    if (count < 1 || count > source.length) return null;
    if (count == 1) {
      final foundation = FreeCellPile.foundation(source.last.suit.index);
      if (canMove(from, 1, foundation)) return foundation;
    }
    FreeCellPile? best;
    var bestRun = 0;
    for (var i = 0; i < 8; i++) {
      final cascade = cascades[i];
      final to = FreeCellPile.cascade(i);
      if (cascade.isEmpty || !canMove(from, count, to)) continue;
      final run = cascade.length - runStart(cascade);
      if (run > bestRun) {
        best = to;
        bestRun = run;
      }
    }
    if (best != null) return best;
    if (count == 1 && from.type != FreeCellPileType.cell) {
      final cell = cells.indexOf(null);
      if (cell >= 0) return FreeCellPile.cell(cell);
    }
    final wholeCascade =
        from.type == FreeCellPileType.cascade && count == source.length;
    if (!wholeCascade) {
      for (var i = 0; i < 8; i++) {
        final to = FreeCellPile.cascade(i);
        if (cascades[i].isEmpty && canMove(from, count, to)) return to;
      }
    }
    return null;
  }

  /// Whether a card of [rank] and [suit] that fits its foundation can go
  /// there without ever hurting the game: no card still out could need it as
  /// a base. Aces and twos; a card whose opposite-colour cards one rank lower
  /// are all on the foundations; or one at most 2 above both opposite-colour
  /// foundations and at most 3 above the other one of its colour (the
  /// dominance of the Klondike solver).
  bool isSafeToFoundation(Suit suit, int rank) {
    if (rank <= 2) return true;
    var oppositeLow = 13;
    var sameColour = 13;
    for (final other in Suit.values) {
      if (other == suit) continue;
      final height = foundations[other.index].length;
      if (other.isRed == suit.isRed) {
        sameColour = height;
      } else {
        oppositeLow = min(oppositeLow, height);
      }
    }
    return oppositeLow >= rank - 1 ||
        (oppositeLow >= rank - 2 && sameColour >= rank - 3);
  }

  /// The next safe move to a foundation (see [isSafeToFoundation]), from the
  /// cells first, then the cascades from the left; null when there is none.
  ({FreeCellPile from, FreeCellPile to})? nextSafeMove() {
    for (final from in FreeCellPile.all) {
      if (from.type == FreeCellPileType.foundation) continue;
      final card = pile(from).lastOrNull;
      if (card == null) continue;
      final to = FreeCellPile.foundation(card.suit.index);
      if (canMove(from, 1, to) && isSafeToFoundation(card.suit, card.rank)) {
        return (from: from, to: to);
      }
    }
    return null;
  }

  /// True when the game can finish itself: in every cascade, each card is
  /// at most as high as the card below it, so the lowest card left is
  /// always free to go to its foundation.
  bool get canFinish =>
      !isWon &&
      cascades.every((cascade) {
        for (var i = 1; i < cascade.length; i++) {
          if (cascade[i].rank > cascade[i - 1].rank) return false;
        }
        return true;
      });

  /// Next foundation move to finish the game: the lowest free card first.
  ({FreeCellPile from, FreeCellPile to})? nextFinishMove() {
    ({FreeCellPile from, FreeCellPile to})? best;
    var bestRank = 14;
    for (final from in FreeCellPile.all) {
      if (from.type == FreeCellPileType.foundation) continue;
      final card = pile(from).lastOrNull;
      if (card == null || card.rank >= bestRank) continue;
      final to = FreeCellPile.foundation(card.suit.index);
      if (canMove(from, 1, to)) {
        best = (from: from, to: to);
        bestRank = card.rank;
      }
    }
    return best;
  }

  static List<PlayingCard> _decodePile(String text) {
    if (text.length.isOdd) throw FormatException('Not a card pile', text);
    return [
      for (var i = 0; i < text.length; i += 2)
        PlayingCard.fromCode(text.substring(i, i + 2)),
    ];
  }

  FreeCellState _withPile(FreeCellPile ref, List<PlayingCard> cards) =>
      switch (ref.type) {
        FreeCellPileType.cell => FreeCellState(
          cells: [...cells]..[ref.index] = cards.lastOrNull,
          foundations: foundations,
          cascades: cascades,
        ),
        FreeCellPileType.foundation => FreeCellState(
          cells: cells,
          foundations: [...foundations]..[ref.index] = cards,
          cascades: cascades,
        ),
        FreeCellPileType.cascade => FreeCellState(
          cells: cells,
          foundations: foundations,
          cascades: [...cascades]..[ref.index] = cards,
        ),
      };
}
