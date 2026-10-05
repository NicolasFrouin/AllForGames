enum Suit {
  clubs('♣', isRed: false),
  diamonds('♦', isRed: true),
  hearts('♥', isRed: true),
  spades('♠', isRed: false);

  const Suit(this.symbol, {required this.isRed});

  final String symbol;
  final bool isRed;
}

class PlayingCard {
  const PlayingCard(this.suit, this.rank, {this.faceUp = false, this.deck = 0})
    : assert(rank >= 1 && rank <= 13),
      assert(deck >= 0);

  /// Reads a [code]. Throws a [FormatException] for anything else.
  factory PlayingCard.fromCode(String code) {
    if (code.length == 2) {
      final rank = _rankCodes.indexOf(code[0]) + 1;
      final suit = _suitCodes.indexOf(code[1].toLowerCase());
      if (rank > 0 && suit >= 0) {
        return PlayingCard(
          Suit.values[suit],
          rank,
          faceUp: code[1] != _suitCodes[suit],
        );
      }
    }
    throw FormatException('Not a card code', code);
  }

  static const _rankCodes = 'A23456789TJQK';

  /// In the order of [Suit.values].
  static const _suitCodes = 'cdhs';

  final Suit suit;

  /// 1 (ace) to 13 (king).
  final int rank;
  final bool faceUp;

  /// Which copy of the card, in games with several decks (Spider): the
  /// cards of deck 0 are the cards of a single-deck game.
  final int deck;

  /// Stable across face changes, so widgets keep their identity when a card
  /// flips. Unique among several decks: `hearts-12` (deck 0), `hearts-12-3`.
  String get id =>
      deck == 0 ? '${suit.name}-$rank' : '${suit.name}-$rank-$deck';

  /// Two letters for saves: rank then suit, with an uppercase suit letter for
  /// a face-up card. `TH` is the face-up 10 of hearts, `Kc` the face-down
  /// king of clubs.
  String get code {
    final suitCode = _suitCodes[suit.index];
    return _rankCodes[rank - 1] + (faceUp ? suitCode.toUpperCase() : suitCode);
  }

  String get rankLabel => switch (rank) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$rank',
  };

  PlayingCard turned({required bool faceUp}) =>
      PlayingCard(suit, rank, faceUp: faceUp, deck: deck);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.suit == suit &&
      other.rank == rank &&
      other.faceUp == faceUp &&
      other.deck == deck;

  @override
  int get hashCode => Object.hash(suit, rank, faceUp, deck);

  @override
  String toString() => '$rankLabel${suit.symbol}${faceUp ? '' : '?'}';
}
