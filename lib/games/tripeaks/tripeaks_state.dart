import '../../cards/deal_random.dart';
import '../../cards/playing_card.dart';

/// The score of a game. An undo takes back the points of the action it
/// undoes.
abstract final class TriPeaksScoring {
  /// A tableau card scores 10 points per card of the run it extends, itself
  /// included: 10, 20, 30... A draw from the stock starts a new run.
  static int card(int run) => 10 * run;

  /// Clearing the top card of a peak.
  static const peak = 500;

  /// On a win, per card still in the stock.
  static const stockCardLeft = 100;
}

/// Immutable TriPeaks board: 28 tableau cards in three overlapping peaks,
/// the stock and the waste.
///
/// Tableau positions go row by row from the top, left to right: the 3 peak
/// tops (0-2), 6 cards (3-8), 9 cards (9-17), then the 10 cards of the
/// bottom row (18-27). Each card above the bottom row is covered by the two
/// cards below it ([coveredBy]); a card is face up once both are gone.
class TriPeaksState {
  TriPeaksState({
    required List<PlayingCard?> tableau,
    required List<PlayingCard> stock,
    required List<PlayingCard> waste,
  }) : assert(tableau.length == positions && waste.isNotEmpty),
       tableau = List.unmodifiable(tableau),
       stock = List.unmodifiable(stock),
       waste = List.unmodifiable(waste);

  /// The deal of [seed], the same on every platform: the first 28 cards of
  /// [shuffledDeck] go to the tableau positions in order (the bottom row face
  /// up), the next one face up to the waste, and the last 23 face down to the
  /// stock, the last card of the deck on top.
  ///
  /// **Never change this algorithm** (nor [shuffledDeck] and `DealRandom`):
  /// the seeds of `triPeaksDeals` were proven winnable for the exact deals it
  /// gives today.
  factory TriPeaksState.deal(int seed) {
    final deck = shuffledDeck(seed);
    return TriPeaksState(
      tableau: [
        for (var i = 0; i < positions; i++)
          deck[i].turned(faceUp: coveredBy[i].isEmpty),
      ],
      waste: [deck[positions].turned(faceUp: true)],
      stock: deck.sublist(positions + 1),
    );
  }

  /// Reads a board written by [encode]. Throws a [FormatException] unless
  /// [text] holds the 52 cards once each, the tableau cards face up exactly
  /// when uncovered, the stock face down and a face-up waste of one card or
  /// more.
  factory TriPeaksState.decode(String text) {
    final parts = text.split(',');
    if (parts.length != 3 || parts[0].length != positions * 2) {
      throw FormatException('Not a TriPeaks board', text);
    }
    final tableau = [
      for (var i = 0; i < positions; i++)
        switch (parts[0].substring(2 * i, 2 * i + 2)) {
          '--' => null,
          final code => PlayingCard.fromCode(code),
        },
    ];
    final stock = _decodeCards(parts[1]);
    final waste = _decodeCards(parts[2]);
    final cards = [...tableau.nonNulls, ...stock, ...waste];
    if (cards.length != 52 ||
        cards.map((card) => card.id).toSet().length != 52) {
      throw FormatException('A board needs the 52 cards once each', text);
    }
    if (waste.isEmpty ||
        waste.any((card) => !card.faceUp) ||
        stock.any((card) => card.faceUp)) {
      throw FormatException('Face-up waste and face-down stock', text);
    }
    for (var i = 0; i < positions; i++) {
      final card = tableau[i];
      if (card != null && card.faceUp != _uncovered(tableau, i)) {
        throw FormatException('Tableau card $i is turned wrong', text);
      }
    }
    return TriPeaksState(tableau: tableau, stock: stock, waste: waste);
  }

  static const positions = 28;
  static const peakCount = 3;

  /// The tableau positions that cover each position: two below it, none for
  /// the bottom row.
  static final coveredBy = List<List<int>>.unmodifiable([
    for (var p = 0; p < 3; p++) [3 + 2 * p, 4 + 2 * p],
    for (var j = 0; j < 6; j++)
      [9 + 3 * (j ~/ 2) + j % 2, 10 + 3 * (j ~/ 2) + j % 2],
    for (var j = 0; j < 9; j++) [18 + j, 19 + j],
    for (var j = 0; j < 10; j++) const <int>[],
  ]);

  /// The tableau positions that each position covers (the inverse of
  /// [coveredBy]).
  static final covers = List<List<int>>.unmodifiable([
    for (var i = 0; i < positions; i++)
      [
        for (var j = 0; j < positions; j++)
          if (coveredBy[j].contains(i)) j,
      ],
  ]);

  /// Null where the card was cleared.
  final List<PlayingCard?> tableau;

  /// Face down; the last card is the top one.
  final List<PlayingCard> stock;

  /// Face up; the last card is the one to play on.
  final List<PlayingCard> waste;

  /// Whether a card of [rank] can go on a card of [onto]: one rank above or
  /// below, the King and the Ace next to each other.
  static bool fits(int rank, int onto) {
    final gap = (rank - onto).abs();
    return gap == 1 || gap == 12;
  }

  /// Compact text of the board for saves: the 28 tableau places (`--` for a
  /// cleared one), the stock and the waste, bottom card first, joined by
  /// commas; each card as its [PlayingCard.code].
  String encode() => [
    tableau.map((card) => card?.code ?? '--').join(),
    stock.map((card) => card.code).join(),
    waste.map((card) => card.code).join(),
  ].join(',');

  PlayingCard get wasteTop => waste.last;

  int get cardsLeft => tableau.nonNulls.length;

  /// Peaks whose top card was cleared.
  int get peaksCleared =>
      tableau.take(peakCount).where((card) => card == null).length;

  bool get isWon => cardsLeft == 0;

  /// No card to play and no card to draw.
  bool get isStuck => !isWon && stock.isEmpty && playable.isEmpty;

  bool isUncovered(int position) => _uncovered(tableau, position);

  bool canPlay(int position) {
    final card = tableau[position];
    return card != null &&
        isUncovered(position) &&
        fits(card.rank, wasteTop.rank);
  }

  /// The positions of the cards that can go on the waste now.
  List<int> get playable => [
    for (var i = 0; i < positions; i++)
      if (canPlay(i)) i,
  ];

  /// Moves the card at [position] onto the waste and turns over the cards
  /// it uncovers. Returns null when the move is not legal.
  TriPeaksState? play(int position) {
    if (!canPlay(position)) return null;
    final next = [...tableau];
    final card = next[position]!;
    next[position] = null;
    for (final below in covers[position]) {
      if (next[below] case final hidden? when _uncovered(next, below)) {
        next[below] = hidden.turned(faceUp: true);
      }
    }
    return TriPeaksState(tableau: next, stock: stock, waste: [...waste, card]);
  }

  /// Turns the top stock card onto the waste. Null when the stock is empty.
  TriPeaksState? draw() {
    if (stock.isEmpty) return null;
    return TriPeaksState(
      tableau: tableau,
      stock: stock.sublist(0, stock.length - 1),
      waste: [...waste, stock.last.turned(faceUp: true)],
    );
  }

  /// The stock turned onto the waste, its top card first: the bonus cards
  /// of a won game.
  TriPeaksState collectStock() => TriPeaksState(
    tableau: tableau,
    stock: const [],
    waste: [
      ...waste,
      for (final card in stock.reversed) card.turned(faceUp: true),
    ],
  );

  static bool _uncovered(List<PlayingCard?> tableau, int position) =>
      coveredBy[position].every((i) => tableau[i] == null);

  static List<PlayingCard> _decodeCards(String text) {
    if (text.length.isOdd) throw FormatException('Not a card pile', text);
    return [
      for (var i = 0; i < text.length; i += 2)
        PlayingCard.fromCode(text.substring(i, i + 2)),
    ];
  }
}
