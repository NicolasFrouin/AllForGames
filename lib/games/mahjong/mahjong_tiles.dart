/// The suits of a Mahjong set, with the number of faces of each.
enum TileSuit {
  dots(9),
  bamboo(9),
  characters(9),

  /// East, south, west, north.
  winds(4),

  /// Red, green, white.
  dragons(3),

  /// Plum, orchid, chrysanthemum, bamboo: one tile each.
  flowers(4),

  /// Spring, summer, autumn, winter: one tile each.
  seasons(4);

  const TileSuit(this.size);

  /// Number of faces of the suit.
  final int size;
}

/// One of the 42 faces of a Mahjong set, by [code]: dots 1-9 are 0-8, then
/// bamboo, characters, winds, dragons, flowers and seasons, in [TileSuit]
/// order. A set holds four tiles of each face, but one of each flower and of
/// each season.
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

  static const count = 42;

  /// First code of the flowers, then of the seasons.
  static const _flowers = 34;
  static const _seasons = 38;

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

  /// Faces of the same group match: any flower matches any flower, any
  /// season any season, and other faces only themselves.
  int get group => groupOf(code);

  bool matches(TileFace other) => group == other.group;

  static int groupOf(int code) => code >= _seasons
      ? _seasons
      : code >= _flowers
      ? _flowers
      : code;

  /// The faces of a full set of 144 tiles, in 72 matching pairs: two pairs
  /// of each group (a group is a face, or the flowers, or the seasons).
  /// Pairs `2k` and `2k + 1` are of the same group.
  static List<(int, int)> setPairs() => [
    for (var face = 0; face < _flowers; face++) ...[(face, face), (face, face)],
    (_flowers, _flowers + 1),
    (_flowers + 2, _flowers + 3),
    (_seasons, _seasons + 1),
    (_seasons + 2, _seasons + 3),
  ];

  @override
  bool operator ==(Object other) => other is TileFace && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '${suit.name}-$rank';
}
