import 'dart:math';

import '../../cards/deal_random.dart';
import 'mahjong_layout.dart';

/// The places of [count] discs on [layout] for the deal of [seed]. A disc
/// lies on a tile of layer `z - 1`, under the tile place it is given (layer
/// `z`), and is wider than a tile: it peeks out where no tile of its layer
/// lies beside it. Discs lie apart from each other.
///
/// Pure Dart: the discs mode is built at runtime from the seed, like the
/// deals.
List<TilePosition> placeDiscs(MahjongLayout layout, int seed, int count) {
  final random = DealRandom(seed ^ 0x6469736B);
  final places = layout.positions.toSet();
  bool covered(int x, int y, int z) {
    for (var layer = z; layer < layout.layers; layer++) {
      if (places.contains(TilePosition(x, y, layer))) return true;
    }
    return false;
  }

  bool shows(TilePosition p) => [
    (p.x - 2, p.y),
    (p.x + 2, p.y),
    (p.x, p.y - 2),
    (p.x, p.y + 2),
  ].any((side) => !covered(side.$1, side.$2, p.z));

  // On a tile; the places with a side where the disc shows first.
  final onTiles = _shuffled([
    for (final p in layout.positions)
      if (p.z > 0 && places.contains(TilePosition(p.x, p.y, p.z - 1))) p,
  ], random);
  final candidates = [
    ...onTiles.where(shows),
    ...onTiles.where((p) => !shows(p)),
  ];
  // Apart from each other when the shape has room, closer when not.
  final discs = <TilePosition>[];
  for (final apart in [2 * discRadius, discRadius, 0.0]) {
    for (final candidate in candidates) {
      if (discs.length == count) return discs;
      if (discs.contains(candidate)) continue;
      final far = discs.every(
        (disc) =>
            sqrt(pow(disc.x - candidate.x, 2) + pow(disc.y - candidate.y, 2)) >=
            apart,
      );
      if (far) discs.add(candidate);
    }
  }
  return discs;
}

List<T> _shuffled<T>(List<T> items, DealRandom random) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final item = items[i];
    items[i] = items[j];
    items[j] = item;
  }
  return items;
}
