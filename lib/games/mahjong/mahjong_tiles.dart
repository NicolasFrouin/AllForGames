/// The suits of a Mahjong set, with the number of faces of each.
enum TileSuit {
  dots(9),
  bamboo(9),
  characters(9),

  /// East, south, west, north.
  winds(4),

  /// Red, green, white.
  dragons(3),

  /// One flower face.
  flowers(1),

  /// One season face.
  seasons(1);

  const TileSuit(this.size);

  /// Number of faces of the suit.
  final int size;
}

/// One of the 36 faces of a Mahjong set, by [code]: dots 1-9 are 0-8, then
/// bamboo, characters, winds, dragons, the flower and the season, in
/// [TileSuit] order. A set holds four tiles of each face, and only tiles of
/// the same face match: matching tiles always look the same.
///
/// Pure Dart without Flutter: the rules and the generator use it.
class TileFace {
  const TileFace(this.code) : assert(code >= 0 && code < count);

  factory TileFace.of(TileSuit suit, int rank) {
    assert(rank >= 1 && rank <= suit.size);
    var code = rank - 1;
    for (final before in TileSuit.values.take(suit.index)) {
      code += before.size;
    }
    return TileFace(code);
  }

  static const count = 36;

  final int code;

  TileSuit get suit => _suitAndRank.$1;

  /// From 1, in the order of the [TileSuit] comments.
  int get rank => _suitAndRank.$2;

  (TileSuit, int) get _suitAndRank {
    var rest = code;
    for (final suit in TileSuit.values) {
      if (rest < suit.size) return (suit, rest + 1);
      rest -= suit.size;
    }
    throw StateError('Unknown tile face $code');
  }

  @override
  bool operator ==(Object other) => other is TileFace && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '${suit.name}-$rank';
}
