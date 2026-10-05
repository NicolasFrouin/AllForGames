/// Where a tile lies: [x] and [y] in half tile widths and heights (a tile
/// covers two by two units), [z] the layer from 0.
class TilePosition {
  const TilePosition(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;

  /// Whether the tiles at this and [other] cover some of the same ground.
  bool overlaps(TilePosition other) =>
      (x - other.x).abs() < 2 && (y - other.y).abs() < 2;

  @override
  bool operator ==(Object other) =>
      other is TilePosition && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// The shape of a board: the positions of its tiles, and which positions
/// block which.
///
/// A tile is free when no tile lies on it, and the tiles on its left or the
/// tiles on its right are all gone.
class MahjongLayout {
  MahjongLayout(this.id, this.positions, {this.transposed = false})
    : above = _neighbors(positions, (p, q) => q.z > p.z && p.overlaps(q)),
      left = _neighbors(positions, (p, q) => _beside(p, q, -2)),
      right = _neighbors(positions, (p, q) => _beside(p, q, 2));

  /// Stays the same when [transposed]: records name the layout by it.
  final String id;

  /// Rows and columns swapped, to fit tall screens. The rules then apply to
  /// the new rows: this is another board, with its own deals.
  final bool transposed;
  final List<TilePosition> positions;

  /// For each position, the positions of the tiles that lie on it, beside it
  /// on the left, and beside it on the right.
  final List<List<int>> above;
  final List<List<int>> left;
  final List<List<int>> right;

  int get length => positions.length;

  /// Size in half tile units, and number of layers.
  late final int width = positions.fold(0, (w, p) => p.x + 2 > w ? p.x + 2 : w);
  late final int height = positions.fold(
    0,
    (h, p) => p.y + 2 > h ? p.y + 2 : h,
  );
  late final int layers = positions.fold(
    0,
    (l, p) => p.z + 1 > l ? p.z + 1 : l,
  );

  /// Whether the tile at [position] is free, where `occupied[i]` tells if a
  /// tile is at position `i`.
  bool isFree(int position, List<bool> occupied) {
    bool anyOccupied(List<int> positions) {
      for (final p in positions) {
        if (occupied[p]) return true;
      }
      return false;
    }

    return !anyOccupied(above[position]) &&
        (!anyOccupied(left[position]) || !anyOccupied(right[position]));
  }

  /// The same board with rows and columns swapped.
  MahjongLayout toTransposed() => MahjongLayout(id, [
    for (final p in positions) TilePosition(p.y, p.x, p.z),
  ], transposed: !transposed);

  static bool _beside(TilePosition p, TilePosition q, int dx) =>
      q.z == p.z && q.x == p.x + dx && (q.y - p.y).abs() < 2;

  static List<List<int>> _neighbors(
    List<TilePosition> positions,
    bool Function(TilePosition p, TilePosition q) test,
  ) => [
    for (final p in positions)
      [
        for (final (j, q) in positions.indexed)
          if (!identical(p, q) && test(p, q)) j,
      ],
  ];
}

/// Positions of a block of [columns] by [rows] tiles, from ([x], [y]).
Iterable<TilePosition> _block(
  int x,
  int y,
  int z,
  int columns, [
  int rows = 1,
]) => [
  for (var row = 0; row < rows; row++)
    for (var column = 0; column < columns; column++)
      TilePosition(x + column * 2, y + row * 2, z),
];

/// A small four-step pyramid of 72 tiles on a hexagon.
final pyramidLayout = MahjongLayout('pyramid', [
  ..._block(4, 0, 0, 4),
  ..._block(2, 2, 0, 6),
  ..._block(0, 4, 0, 8, 2),
  ..._block(2, 8, 0, 6),
  ..._block(4, 10, 0, 4),
  ..._block(2, 2, 1, 6, 4),
  ..._block(4, 4, 2, 4, 2),
  ..._block(6, 4, 3, 2, 2),
]);

/// The classic Turtle (also known as Dragon) of 144 tiles on five layers.
final turtleLayout = MahjongLayout('turtle', [
  ..._block(2, 0, 0, 12),
  ..._block(6, 2, 0, 8),
  ..._block(4, 4, 0, 10),
  ..._block(2, 6, 0, 12, 2),
  ..._block(4, 10, 0, 10),
  ..._block(6, 12, 0, 8),
  ..._block(2, 14, 0, 12),
  // The head and the tail, between two rows.
  const TilePosition(0, 7, 0),
  const TilePosition(26, 7, 0),
  const TilePosition(28, 7, 0),
  ..._block(8, 2, 1, 6, 6),
  ..._block(10, 4, 2, 4, 4),
  ..._block(12, 6, 3, 2, 2),
  const TilePosition(13, 7, 4),
]);

final mahjongLayouts = [pyramidLayout, turtleLayout];

/// The layout [id] (null for an unknown one), transposed when asked.
MahjongLayout? layoutById(String id, {bool transposed = false}) {
  for (final layout in mahjongLayouts) {
    if (layout.id == id) return transposed ? layout.toTransposed() : layout;
  }
  return null;
}
