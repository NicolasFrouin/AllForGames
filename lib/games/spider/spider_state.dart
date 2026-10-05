import '../../cards/deal_random.dart';
import '../../cards/playing_card.dart';
import 'spider_difficulty.dart';

/// Classic Spider scoring (as in Windows Spider): the score starts at
/// [start], each move, stock deal or undo costs a point, and each completed
/// run on the foundations is worth [run] points. Undoing a completed run takes
/// its points back. Never below zero.
abstract final class SpiderScoring {
  static const start = 500;
  static const run = 100;

  static int score({
    required int moves,
    required int undos,
    required int runs,
  }) {
    final score = start - moves - undos + run * runs;
    return score < 0 ? 0 : score;
  }
}

/// Immutable Spider board: 104 cards (two decks), ten columns, a stock dealt
/// ten cards at a time and the completed runs. The last card of each list is
/// the top card.
class SpiderState {
  SpiderState({
    required List<List<PlayingCard>> columns,
    required List<PlayingCard> stock,
    List<List<PlayingCard>> runs = const [],
    this.difficulty = SpiderDifficulty.medium,
  }) : assert(columns.length == columnCount),
       columns = List.unmodifiable(columns.map(List<PlayingCard>.unmodifiable)),
       stock = List.unmodifiable(stock),
       runs = List.unmodifiable(runs.map(List<PlayingCard>.unmodifiable));

  /// The deal of [seed] for [difficulty], the same on every platform: the
  /// 104 cards ([cardsOf]) shuffled by [shuffledCards]; the first 54 go to
  /// the columns row by row from the left (columns 1 to 4 get six cards, the
  /// others five; only the top card face up), the last 50 form the stock in
  /// that order (its last card is the top of the stock).
  ///
  /// The shuffle seed also holds the suit count: with the same shuffle, the
  /// levels would deal the same ranks in the same places.
  ///
  /// **Never change this algorithm** (nor [cardsOf], [shuffledCards] and
  /// `DealRandom`): the seeds of `spiderDeals` were proven winnable for the
  /// exact deals it gives today.
  factory SpiderState.deal(int seed, SpiderDifficulty difficulty) {
    final cards = shuffledCards(
      seed ^ (difficulty.suitCount << 28),
      cardsOf(difficulty),
    );
    final columns = List.generate(columnCount, (_) => <PlayingCard>[]);
    for (var i = 0; i < dealtCount; i++) {
      columns[i % columnCount].add(cards[i]);
    }
    return SpiderState(
      columns: [
        for (final column in columns)
          [...column.take(column.length - 1), column.last.turned(faceUp: true)],
      ],
      stock: cards.sublist(dealtCount),
      difficulty: difficulty,
    );
  }

  /// Reads a board written by [encode]. Throws a [FormatException] unless
  /// [text] holds the 104 cards of [difficulty] once each: a face-down stock
  /// of whole deals, columns with their face-down cards at the bottom, and
  /// completed runs.
  factory SpiderState.decode(String text, SpiderDifficulty difficulty) {
    final piles = text.split(',').map(_decodePile).toList();
    if (piles.length < 1 + columnCount ||
        piles.length > 1 + columnCount + runCount) {
      throw FormatException('Not a Spider board', text);
    }
    final ids = {
      for (final pile in piles)
        for (final card in pile) card.id,
    };
    final copies = runCount ~/ difficulty.suitCount;
    final suits = suitsOf(difficulty);
    final cards = [for (final pile in piles) ...pile];
    if (cards.length != cardCount ||
        ids.length != cardCount ||
        cards.any(
          (card) => !suits.contains(card.suit) || card.deck >= copies,
        )) {
      throw FormatException('A board needs the 104 cards once each', text);
    }
    final stock = piles[0];
    if (stock.length % columnCount != 0 || stock.any((card) => card.faceUp)) {
      throw FormatException('Not a stock', text);
    }
    final columns = piles.sublist(1, 1 + columnCount);
    for (final column in columns) {
      final firstUp = column.indexWhere((card) => card.faceUp);
      if (firstUp >= 0 && column.skip(firstUp).any((card) => !card.faceUp)) {
        throw FormatException('A face-down card above a face-up one', text);
      }
    }
    final runs = piles.sublist(1 + columnCount);
    for (final run in runs) {
      if (run.length != 13 ||
          !_isRun(run.reversed.toList(), 0) ||
          run.first.rank != 1) {
        throw FormatException('Not a completed run', text);
      }
    }
    return SpiderState(
      columns: columns,
      stock: stock,
      runs: runs,
      difficulty: difficulty,
    );
  }

  static const columnCount = 10;
  static const cardCount = 104;

  /// Cards dealt to the columns at the start.
  static const dealtCount = 54;

  /// Runs to complete: one per 13 cards.
  static const runCount = 8;

  /// The suits of [difficulty]: spades; spades and hearts; all four.
  static List<Suit> suitsOf(SpiderDifficulty difficulty) =>
      switch (difficulty.suitCount) {
        1 => const [Suit.spades],
        2 => const [Suit.spades, Suit.hearts],
        _ => Suit.values,
      };

  /// The 104 cards of [difficulty], face down, before the shuffle: deck by
  /// deck, each deck suit by suit ([suitsOf] order), ace to king. Must never
  /// change: see [SpiderState.deal].
  static List<PlayingCard> cardsOf(SpiderDifficulty difficulty) {
    final suits = suitsOf(difficulty);
    return [
      for (var deck = 0; deck < runCount ~/ suits.length; deck++)
        for (final suit in suits)
          for (var rank = 1; rank <= 13; rank++)
            PlayingCard(suit, rank, deck: deck),
    ];
  }

  final List<List<PlayingCard>> columns;

  /// Face down; a deal gives its top (last) card to the first column.
  final List<PlayingCard> stock;

  /// The completed runs, in the order they were completed, each as its
  /// foundation pile: the ace first, the king on top.
  final List<List<PlayingCard>> runs;
  final SpiderDifficulty difficulty;

  /// Stock deals left.
  int get dealsLeft => (stock.length + columnCount - 1) ~/ columnCount;

  int get faceDownCount => columns.fold(
    0,
    (sum, column) => sum + column.where((card) => !card.faceUp).length,
  );

  bool get isWon => stock.isEmpty && columns.every((column) => column.isEmpty);

  /// Compact text of the board for saves: the stock, the ten columns, then
  /// the runs, joined by commas. Each card is its [PlayingCard.code] and its
  /// deck (`TH1` is the face-up 10 of hearts of deck 1).
  String encode() => [stock, ...columns, ...runs]
      .map((pile) => pile.map((card) => '${card.code}${card.deck}').join())
      .join(',');

  /// Whether the top [count] cards of [column] can move together: a run of
  /// one suit in descending order, face up.
  bool canPick(int column, int count) {
    if (column < 0 || column >= columnCount || count < 1) return false;
    final cards = columns[column];
    return count <= cards.length && _isRun(cards, cards.length - count);
  }

  /// Whether the top [count] cards of [from] can go on [to]: a run on a card
  /// one rank higher (any suit), or anything on an empty column.
  bool canMove(int from, int count, int to) {
    if (from == to || to < 0 || to >= columnCount) return false;
    if (!canPick(from, count)) return false;
    final source = columns[from];
    final target = columns[to];
    if (target.isEmpty) return true;
    final top = target.last;
    return top.faceUp && top.rank == source[source.length - count].rank + 1;
  }

  /// Returns null when the move is not legal. A run completed by the move
  /// leaves the column at once, and the uncovered cards turn face up.
  SpiderState? move(int from, int count, int to) {
    if (!canMove(from, count, to)) return null;
    final next = [...columns];
    final source = columns[from];
    next[from] = _revealTop(source.sublist(0, source.length - count));
    next[to] = [...columns[to], ...source.sublist(source.length - count)];
    final runs = [...this.runs];
    next[to] = _collectRun(next[to], runs);
    return _copyWith(columns: next, runs: runs);
  }

  /// A deal needs a card in every column.
  bool get canDeal =>
      stock.isNotEmpty && columns.every((column) => column.isNotEmpty);

  /// Deals one card face up on each column, from the top of the stock.
  /// Returns null when [canDeal] is false.
  SpiderState? deal() {
    if (!canDeal) return null;
    final count = stock.length < columnCount ? stock.length : columnCount;
    final runs = [...this.runs];
    final next = [
      for (var i = 0; i < columnCount; i++)
        i < count
            ? _collectRun([
                ...columns[i],
                stock[stock.length - 1 - i].turned(faceUp: true),
              ], runs)
            : columns[i],
    ];
    return _copyWith(
      columns: next,
      stock: stock.sublist(0, stock.length - count),
      runs: runs,
    );
  }

  /// Best column for the top [count] cards of [from] when the player taps
  /// them: on a card of the same suit (the one with the longest run of that
  /// suit), else on any card one rank higher, else on an empty column unless
  /// the cards already fill their column. Null when none can take them.
  int? autoTarget(int from, int count) {
    if (!canPick(from, count)) return null;
    final source = columns[from];
    final moving = source[source.length - count];
    int? best;
    var bestScore = -1;
    for (var to = 0; to < columnCount; to++) {
      if (!canMove(from, count, to)) continue;
      final target = columns[to];
      final int score;
      if (target.isEmpty) {
        if (count == source.length) continue;
        score = 0;
      } else if (target.last.suit == moving.suit) {
        score = 100 + topRunLength(to);
      } else {
        score = 1;
      }
      if (score > bestScore) {
        best = to;
        bestScore = score;
      }
    }
    return best;
  }

  /// Cards in the run of one suit on top of [column] (0 when empty).
  int topRunLength(int column) {
    final cards = columns[column];
    var start = cards.length;
    while (start > 0 && _isRun(cards, start - 1)) {
      start--;
    }
    return cards.length - start;
  }

  /// Whether the cards of [cards] from [start] up form a run of one suit,
  /// descending, face up.
  static bool _isRun(List<PlayingCard> cards, int start) {
    if (start < 0 || start >= cards.length || !cards[start].faceUp) {
      return false;
    }
    for (var i = start + 1; i < cards.length; i++) {
      final below = cards[i - 1];
      final card = cards[i];
      if (!card.faceUp ||
          card.suit != below.suit ||
          card.rank != below.rank - 1) {
        return false;
      }
    }
    return true;
  }

  /// Removes a king-to-ace run of one suit from the top of [column] into
  /// [runs] (ace first), and turns the new top card face up.
  static List<PlayingCard> _collectRun(
    List<PlayingCard> column,
    List<List<PlayingCard>> runs,
  ) {
    final start = column.length - 13;
    if (start < 0 || column.last.rank != 1 || !_isRun(column, start)) {
      return column;
    }
    runs.add(column.sublist(start).reversed.toList());
    return _revealTop(column.sublist(0, start));
  }

  static List<PlayingCard> _revealTop(List<PlayingCard> column) {
    if (column.isEmpty || column.last.faceUp) return column;
    return [
      ...column.sublist(0, column.length - 1),
      column.last.turned(faceUp: true),
    ];
  }

  static List<PlayingCard> _decodePile(String text) {
    if (text.length % 3 != 0) throw FormatException('Not a card pile', text);
    return [
      for (var i = 0; i < text.length; i += 3)
        _decodeCard(text.substring(i, i + 3)),
    ];
  }

  static PlayingCard _decodeCard(String text) {
    final card = PlayingCard.fromCode(text.substring(0, 2));
    final deck = int.tryParse(text[2]);
    if (deck == null) throw FormatException('Not a deck', text);
    return PlayingCard(card.suit, card.rank, faceUp: card.faceUp, deck: deck);
  }

  SpiderState _copyWith({
    List<List<PlayingCard>>? columns,
    List<PlayingCard>? stock,
    List<List<PlayingCard>>? runs,
  }) => SpiderState(
    columns: columns ?? this.columns,
    stock: stock ?? this.stock,
    runs: runs ?? this.runs,
    difficulty: difficulty,
  );
}
