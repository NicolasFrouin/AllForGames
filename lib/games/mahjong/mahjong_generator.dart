import '../../cards/deal_random.dart';
import 'mahjong_layout.dart';
import 'mahjong_state.dart';
import 'mahjong_tiles.dart';

/// A board and an order of pairs that clears it.
typedef MahjongDeal = ({MahjongState state, List<TilePair> solution});

/// Deals a board of [layout] that can be cleared, from [seed]: the same
/// seed always gives the same deal.
///
/// The deal is built backwards from the empty board's point of view: it
/// removes two positions that are free together, again and again, from the
/// full layout (starting over when it gets stuck), then gives each removed
/// pair of positions a face. Removing the pairs in that order clears the
/// board.
MahjongDeal generateDeal(
  MahjongLayout layout,
  int seed, {
  int trapPercent = 50,
}) {
  final random = DealRandom(seed);
  final order = removalOrder(
    layout,
    List.filled(layout.length, true),
    random,
    attempts: 1000,
  );
  if (order == null) {
    throw StateError('Layout ${layout.id} cannot be cleared');
  }
  final pairFaces = _pairFaces(layout, order, trapPercent, random);
  final faces = List.filled(layout.length, 0);
  for (final (i, (a, b)) in order.indexed) {
    faces[a] = pairFaces[i];
    faces[b] = pairFaces[i];
  }
  // A tile id is the position of the tile in the deal.
  return (
    state: MahjongState(
      layout: layout,
      faces: faces,
      slots: [for (var i = 0; i < layout.length; i++) i],
    ),
    solution: order,
  );
}

/// Moves the tiles of [state] to other places, so that the board can be
/// cleared again. Tiles keep their positions' shape when it can be cleared,
/// otherwise they go down to the lowest positions of the layout.
MahjongDeal shuffleTiles(MahjongState state, DealRandom random) {
  final layout = state.layout;
  final order =
      removalOrder(
        layout,
        [for (final id in state.slots) id != MahjongState.empty],
        random,
        attempts: 60,
      ) ??
      removalOrder(
        layout,
        _lowestPositions(layout, state.tileCount),
        random,
        attempts: 1000,
      );
  if (order == null) throw StateError('Cannot shuffle ${state.slots}');

  // The tiles in matching pairs, in a random order.
  final byFace = <int, List<int>>{};
  for (final id in state.tileIds) {
    (byFace[state.faces[id]] ??= []).add(id);
  }
  final pairs = <TilePair>[];
  for (final ids in byFace.values) {
    _shuffle(ids, random);
    for (var i = 0; i + 1 < ids.length; i += 2) {
      pairs.add((ids[i], ids[i + 1]));
    }
  }
  _shuffle(pairs, random);

  final slots = List.filled(layout.length, MahjongState.empty);
  for (final (i, (a, b)) in order.indexed) {
    final (tileA, tileB) = pairs[i];
    slots[a] = tileA;
    slots[b] = tileB;
  }
  return (state: state.withSlots(slots), solution: pairs);
}

/// The positions where `occupied` is true, two by two, so that each pair is
/// free when the pairs before it are gone. Picks pairs at random and starts
/// over when only one free position is left; null after [attempts] tries.
List<(int, int)>? removalOrder(
  MahjongLayout layout,
  List<bool> occupied,
  DealRandom random, {
  required int attempts,
}) {
  final count = occupied.where((o) => o).length;
  if (count.isOdd) return null;
  for (var attempt = 0; attempt < attempts; attempt++) {
    final left = [...occupied];
    final order = <(int, int)>[];
    while (order.length * 2 < count) {
      final free = [
        for (var p = 0; p < left.length; p++)
          if (left[p] && layout.isFree(p, left)) p,
      ];
      if (free.length < 2) break;
      final a = free.removeAt(random.nextInt(free.length));
      final b = free[random.nextInt(free.length)];
      left[a] = false;
      left[b] = false;
      order.add((a, b));
    }
    if (order.length * 2 == count) return order;
  }
  return null;
}

/// The face of each pair of [order].
///
/// Each face has four tiles: two pairs.
/// When tiles of both pairs are free at the same time, the player chooses
/// which go together, and a wrong choice can leave a tile under its only
/// partner. So the second pair of a face is chosen either safe (its tiles
/// are free with the first pair's, so all four can go in any order) or, for
/// [trapPercent] % of the faces, as a trap (one of its tiles is free before
/// the first pair goes, the other one lies under the first pair).
List<int> _pairFaces(
  MahjongLayout layout,
  List<(int, int)> order,
  int trapPercent,
  DealRandom random,
) {
  final count = order.length;
  final freeAt = _freeSteps(layout, order);
  bool isFreeAt(int position, int step) => freeAt[position] <= step;
  bool safe(int first, int later) =>
      isFreeAt(order[later].$1, first) && isFreeAt(order[later].$2, first);
  bool tempting(int first, int later) =>
      isFreeAt(order[later].$1, first) || isFreeAt(order[later].$2, first);
  bool trap(int first, int later) {
    if (!tempting(first, later)) return false;
    final (a, b) = order[first];
    for (final p in [order[later].$1, order[later].$2]) {
      final above = layout.above[p];
      if (above.contains(a) || above.contains(b)) return true;
    }
    return false;
  }

  // Pairs of the order that get the same face, the first one first.
  final couples = <(int, int?)>[];
  final paired = List.filled(count, false);
  for (var i = 0; i < count; i++) {
    if (paired[i]) continue;
    paired[i] = true;
    final open = [
      for (var j = i + 1; j < count; j++)
        if (!paired[j]) j,
    ];
    final tests = random.nextInt(100) < trapPercent ? [trap, tempting] : [safe];
    int? partner;
    for (final test in [...tests, (int i, int j) => true]) {
      final fitting = [
        for (final j in open)
          if (test(i, j)) j,
      ];
      if (fitting.isNotEmpty) {
        partner = fitting[random.nextInt(fitting.length)];
        break;
      }
    }
    if (partner != null) paired[partner] = true;
    couples.add((i, partner));
  }

  final shuffled = _shuffle([
    for (var face = 0; face < TileFace.count; face++) face,
  ], random);
  final faces = List.filled(count, 0);
  for (final (k, (first, second)) in couples.indexed) {
    faces[first] = shuffled[k];
    if (second != null) faces[second] = shuffled[k];
  }
  return faces;
}

/// For each position, the first step of [order] at which it is free (step
/// `k`: before pair `k` is removed).
List<int> _freeSteps(MahjongLayout layout, List<(int, int)> order) {
  final occupied = List.filled(layout.length, true);
  final freeAt = List.filled(layout.length, order.length);
  for (final (k, (a, b)) in order.indexed) {
    for (var p = 0; p < layout.length; p++) {
      if (occupied[p] && freeAt[p] > k && layout.isFree(p, occupied)) {
        freeAt[p] = k;
      }
    }
    occupied[a] = false;
    occupied[b] = false;
  }
  return freeAt;
}

/// [count] positions of [layout], layer by layer from the bottom, and from
/// the middle of each layer outwards.
List<bool> _lowestPositions(MahjongLayout layout, int count) {
  final centerX = layout.width / 2 - 1;
  final centerY = layout.height / 2 - 1;
  double distance(TilePosition p) =>
      (p.x - centerX) * (p.x - centerX) + (p.y - centerY) * (p.y - centerY);
  final positions = [for (var i = 0; i < layout.length; i++) i]
    ..sort((a, b) {
      final pa = layout.positions[a];
      final pb = layout.positions[b];
      final byLayer = pa.z.compareTo(pb.z);
      return byLayer != 0 ? byLayer : distance(pa).compareTo(distance(pb));
    });
  final chosen = positions.take(count).toSet();
  return [for (var i = 0; i < layout.length; i++) chosen.contains(i)];
}

/// Fisher-Yates with [random], so the result is the same on every platform.
List<T> _shuffle<T>(List<T> items, DealRandom random) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final item = items[i];
    items[i] = items[j];
    items[j] = item;
  }
  return items;
}
