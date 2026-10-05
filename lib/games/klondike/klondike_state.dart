import 'dart:math';

import 'playing_card.dart';

enum PileType { stock, waste, foundation, tableau }

class PileRef {
  const PileRef._(this.type, this.index);

  const PileRef.foundation(int index) : this._(PileType.foundation, index);
  const PileRef.tableau(int index) : this._(PileType.tableau, index);

  static const stock = PileRef._(PileType.stock, 0);
  static const waste = PileRef._(PileType.waste, 0);

  final PileType type;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is PileRef && other.type == type && other.index == index;

  @override
  int get hashCode => Object.hash(type, index);

  @override
  String toString() => '${type.name}[$index]';
}

/// Standard Windows Solitaire scoring.
abstract final class KlondikeScoring {
  static const wasteToTableau = 5;
  static const toFoundation = 10;
  static const revealCard = 5;
  static const foundationToTableau = -15;

  static int recycle(int drawCount) => drawCount == 1 ? -100 : -20;
}

typedef MoveResult = ({KlondikeState state, int scoreDelta, bool revealed});
typedef DrawResult = ({KlondikeState state, int scoreDelta, bool recycled});

/// Immutable Klondike board. The last card of each list is the top card.
///
/// Foundation `i` only holds cards of `Suit.values[i]`.
class KlondikeState {
  KlondikeState({
    required List<PlayingCard> stock,
    required List<PlayingCard> waste,
    required List<List<PlayingCard>> foundations,
    required List<List<PlayingCard>> tableau,
    this.drawCount = 1,
  }) : assert(foundations.length == 4 && tableau.length == 7),
       assert(drawCount == 1 || drawCount == 3),
       stock = List.unmodifiable(stock),
       waste = List.unmodifiable(waste),
       foundations = List.unmodifiable(
         foundations.map(List<PlayingCard>.unmodifiable),
       ),
       tableau = List.unmodifiable(tableau.map(List<PlayingCard>.unmodifiable));

  factory KlondikeState.deal(Random random, {int drawCount = 1}) {
    final deck = [
      for (final suit in Suit.values)
        for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank),
    ]..shuffle(random);
    var next = 0;
    final tableau = [
      for (var column = 0; column < 7; column++)
        [
          for (var row = 0; row <= column; row++)
            deck[next++].turned(faceUp: row == column),
        ],
    ];
    return KlondikeState(
      stock: deck.sublist(next),
      waste: const [],
      foundations: List.generate(4, (_) => const []),
      tableau: tableau,
      drawCount: drawCount,
    );
  }

  /// Reads a board written by [encode]. Throws a [FormatException] unless
  /// [text] holds the 52 cards once each, in 13 piles, with each foundation
  /// in order.
  factory KlondikeState.decode(String text, {required int drawCount}) {
    final piles = text.split(',').map(_decodePile).toList();
    if (piles.length != 13 || (drawCount != 1 && drawCount != 3)) {
      throw FormatException('Not a Klondike board', text);
    }
    final count = piles.fold(0, (sum, pile) => sum + pile.length);
    final ids = {
      for (final pile in piles)
        for (final card in pile) card.id,
    };
    if (count != 52 || ids.length != 52) {
      throw FormatException('A board needs the 52 cards once each', text);
    }
    for (var i = 0; i < 4; i++) {
      final foundation = piles[2 + i];
      for (var j = 0; j < foundation.length; j++) {
        final card = foundation[j];
        if (card.suit.index != i || card.rank != j + 1 || !card.faceUp) {
          throw FormatException('Foundation $i is not in order', text);
        }
      }
    }
    return KlondikeState(
      stock: piles[0],
      waste: piles[1],
      foundations: piles.sublist(2, 6),
      tableau: piles.sublist(6),
      drawCount: drawCount,
    );
  }

  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;
  final int drawCount;

  /// Compact text of the board for saves: the 13 piles (stock, waste,
  /// foundations, tableau) joined by commas, each pile as the
  /// [PlayingCard.code]s of its cards from bottom to top. [drawCount] is not
  /// in it.
  String encode() => [
    stock,
    waste,
    ...foundations,
    ...tableau,
  ].map((pile) => pile.map((card) => card.code).join()).join(',');

  List<PlayingCard> pile(PileRef ref) => switch (ref.type) {
    PileType.stock => stock,
    PileType.waste => waste,
    PileType.foundation => foundations[ref.index],
    PileType.tableau => tableau[ref.index],
  };

  int get foundationCardCount =>
      foundations.fold(0, (sum, pile) => sum + pile.length);

  int get faceDownCount => tableau.fold(
    0,
    (sum, pile) => sum + pile.where((card) => !card.faceUp).length,
  );

  bool get isWon => foundationCardCount == 52;

  /// True when only foundation moves are left, so the game can finish itself.
  bool get canAutoComplete =>
      !isWon &&
      stock.isEmpty &&
      waste.isEmpty &&
      tableau.every((pile) => pile.every((card) => card.faceUp));

  /// Whether the top [count] cards of [from] can be put on [to].
  bool canMove(PileRef from, int count, PileRef to) {
    if (from == to || count < 1) return false;
    final source = pile(from);
    if (count > source.length) return false;
    switch (from.type) {
      case PileType.stock:
        return false;
      case PileType.waste || PileType.foundation:
        if (count != 1) return false;
      case PileType.tableau:
        // Face-up cards are always on top of a tableau pile, so checking the
        // lowest moved card is enough.
        if (!source[source.length - count].faceUp) return false;
    }

    final moving = source[source.length - count];
    final target = pile(to);
    switch (to.type) {
      case PileType.stock || PileType.waste:
        return false;
      case PileType.foundation:
        return count == 1 &&
            moving.suit.index == to.index &&
            moving.rank == target.length + 1;
      case PileType.tableau:
        if (target.isEmpty) return moving.rank == 13;
        final top = target.last;
        return top.faceUp &&
            top.suit.isRed != moving.suit.isRed &&
            top.rank == moving.rank + 1;
    }
  }

  /// Returns null when the move is not legal.
  MoveResult? move(PileRef from, int count, PileRef to) {
    if (!canMove(from, count, to)) return null;
    final source = pile(from);
    final moving = source.sublist(source.length - count);
    var remaining = source.sublist(0, source.length - count);
    final revealed =
        from.type == PileType.tableau &&
        remaining.isNotEmpty &&
        !remaining.last.faceUp;
    if (revealed) {
      remaining = [
        ...remaining.sublist(0, remaining.length - 1),
        remaining.last.turned(faceUp: true),
      ];
    }
    final next = _withPile(
      from,
      remaining,
    )._withPile(to, [...pile(to), ...moving]);
    return (
      state: next,
      scoreDelta:
          _moveScore(from.type, to.type) +
          (revealed ? KlondikeScoring.revealCard : 0),
      revealed: revealed,
    );
  }

  /// Draws from the stock, or turns the waste back into the stock when the
  /// stock is empty. Returns null when both are empty.
  DrawResult? draw() {
    if (stock.isEmpty) {
      if (waste.isEmpty) return null;
      return (
        state: _copyWith(
          stock: [
            for (final card in waste.reversed) card.turned(faceUp: false),
          ],
          waste: const [],
        ),
        scoreDelta: KlondikeScoring.recycle(drawCount),
        recycled: true,
      );
    }
    final count = min(drawCount, stock.length);
    return (
      state: _copyWith(
        stock: stock.sublist(0, stock.length - count),
        waste: [
          ...waste,
          for (final card in stock.reversed.take(count))
            card.turned(faceUp: true),
        ],
      ),
      scoreDelta: 0,
      recycled: false,
    );
  }

  /// Best destination when the player taps the top [count] cards of [from]:
  /// a foundation first, then the first tableau pile that accepts them.
  PileRef? autoTarget(PileRef from, int count) {
    final source = pile(from);
    if (source.isEmpty) return null;
    if (count == 1) {
      final foundation = PileRef.foundation(source.last.suit.index);
      if (canMove(from, 1, foundation)) return foundation;
    }
    // A king that already starts a tableau pile gains nothing on another empty pile.
    final wholePile = from.type == PileType.tableau && count == source.length;
    for (var i = 0; i < tableau.length; i++) {
      final to = PileRef.tableau(i);
      if (canMove(from, count, to) && !(wholePile && tableau[i].isEmpty)) {
        return to;
      }
    }
    return null;
  }

  /// Next foundation move for auto-complete: the lowest top card first.
  ({PileRef from, PileRef to})? nextFoundationMove() {
    ({PileRef from, PileRef to})? best;
    var bestRank = 14;
    for (final from in [
      PileRef.waste,
      for (var i = 0; i < tableau.length; i++) PileRef.tableau(i),
    ]) {
      final card = pile(from).lastOrNull;
      if (card == null || card.rank >= bestRank) continue;
      final to = PileRef.foundation(card.suit.index);
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

  static int _moveScore(PileType from, PileType to) => switch ((from, to)) {
    (PileType.waste, PileType.tableau) => KlondikeScoring.wasteToTableau,
    (_, PileType.foundation) => KlondikeScoring.toFoundation,
    (PileType.foundation, PileType.tableau) =>
      KlondikeScoring.foundationToTableau,
    _ => 0,
  };

  KlondikeState _withPile(PileRef ref, List<PlayingCard> cards) =>
      switch (ref.type) {
        PileType.stock => _copyWith(stock: cards),
        PileType.waste => _copyWith(waste: cards),
        PileType.foundation => _copyWith(
          foundations: [...foundations]..[ref.index] = cards,
        ),
        PileType.tableau => _copyWith(
          tableau: [...tableau]..[ref.index] = cards,
        ),
      };

  KlondikeState _copyWith({
    List<PlayingCard>? stock,
    List<PlayingCard>? waste,
    List<List<PlayingCard>>? foundations,
    List<List<PlayingCard>>? tableau,
  }) => KlondikeState(
    stock: stock ?? this.stock,
    waste: waste ?? this.waste,
    foundations: foundations ?? this.foundations,
    tableau: tableau ?? this.tableau,
    drawCount: drawCount,
  );
}
