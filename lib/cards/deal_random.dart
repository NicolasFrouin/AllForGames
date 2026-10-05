import 'playing_card.dart';

const _mask32 = 0xFFFFFFFF;

/// Deterministic random numbers for deals.
///
/// Gives the same sequence on the Dart VM, dart2js and dart2wasm. On the web
/// (dart2js) an `int` is a double: bitwise operators truncate their operands
/// to 32 bits and products above 2^53 lose precision, while the VM and Wasm
/// use 64-bit ints. So every value here stays an unsigned 32-bit int, masked
/// with `& 0xFFFFFFFF` after each left shift, and no product exceeds 2^49.
///
/// The algorithm is xorshift32 (Marsaglia, 2003), with the seed mixed by the
/// murmur3 finalizer so that consecutive seeds give unrelated deals.
///
/// **Never change this algorithm or [shuffledDeck]**: they make the deals of
/// `KlondikeState.deal`, and the generated seed lists (`klondike_deals.dart`)
/// were proven winnable for the exact deals they produce today.
class DealRandom {
  /// Only the low 32 bits of [seed] are used.
  DealRandom(int seed) : _state = _initialState(seed);

  int _state;

  static int _initialState(int seed) {
    final state = _mix32(seed & _mask32);
    // Zero is the only state xorshift never leaves.
    return state == 0 ? 0x6D2B79F5 : state;
  }

  /// Next value in `[0, 2^32)`.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask32;
    x ^= x >> 17;
    x ^= (x << 5) & _mask32;
    return _state = x;
  }

  /// Next value in `[0, max)`. The modulo bias is below 2^-25 for a deck.
  int nextInt(int max) {
    assert(max > 0 && max <= 0x10000);
    return nextUint32() % max;
  }

  /// murmur3 `fmix32`.
  static int _mix32(int h) {
    h ^= h >> 16;
    h = _mul32(h, 0x85EBCA6B);
    h ^= h >> 13;
    h = _mul32(h, 0xC2B2AE35);
    h ^= h >> 16;
    return h;
  }

  /// `a * b mod 2^32` for unsigned 32-bit [a] and [b], split in 16-bit halves
  /// so that every intermediate product is exact on the web (below 2^49).
  static int _mul32(int a, int b) {
    final low = a * (b & 0xFFFF);
    final high = (a * (b >> 16)) & 0xFFFF;
    return (low + high * 0x10000) & _mask32;
  }
}

/// The 52 cards, face down, shuffled by [seed].
///
/// Fisher-Yates over the deck built suit by suit (in `Suit.values` order),
/// ace to king. Must never change: see [DealRandom].
List<PlayingCard> shuffledDeck(int seed) {
  final deck = [
    for (final suit in Suit.values)
      for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank),
  ];
  final random = DealRandom(seed);
  for (var i = deck.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final card = deck[i];
    deck[i] = deck[j];
    deck[j] = card;
  }
  return deck;
}

/// A copy of [cards] shuffled by [seed], for games that deal something else
/// than one 52-card deck (Spider deals two decks). It shuffles a list of any
/// type, at most 65536 items.
///
/// Fisher-Yates from the last item, like [shuffledDeck], with a new
/// [DealRandom] of [seed]. Must never change: the seed lists of the games that
/// use it were proven winnable for the exact deals it gives today.
List<T> shuffledCards<T>(int seed, List<T> cards) {
  final shuffled = [...cards];
  final random = DealRandom(seed);
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final card = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = card;
  }
  return shuffled;
}
