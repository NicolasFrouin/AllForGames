enum Suit {
  clubs('♣', 'clubs', isRed: false),
  diamonds('♦', 'diamonds', isRed: true),
  hearts('♥', 'hearts', isRed: true),
  spades('♠', 'spades', isRed: false);

  const Suit(this.symbol, this.label, {required this.isRed});

  final String symbol;
  final String label;
  final bool isRed;
}

class PlayingCard {
  const PlayingCard(this.suit, this.rank, {this.faceUp = false})
    : assert(rank >= 1 && rank <= 13);

  final Suit suit;

  /// 1 (ace) to 13 (king).
  final int rank;
  final bool faceUp;

  /// Stable across face changes, so widgets keep their identity when a card flips.
  String get id => '${suit.name}-$rank';

  String get rankLabel => switch (rank) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$rank',
  };

  String get name {
    final rankName = switch (rank) {
      1 => 'Ace',
      11 => 'Jack',
      12 => 'Queen',
      13 => 'King',
      _ => '$rank',
    };
    return '$rankName of ${suit.label}';
  }

  PlayingCard turned({required bool faceUp}) =>
      PlayingCard(suit, rank, faceUp: faceUp);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.suit == suit &&
      other.rank == rank &&
      other.faceUp == faceUp;

  @override
  int get hashCode => Object.hash(suit, rank, faceUp);

  @override
  String toString() => '$rankLabel${suit.symbol}${faceUp ? '' : '?'}';
}
