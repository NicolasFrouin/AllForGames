import 'dart:math';

import '../../cards/deal_random.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_generator.dart';
import 'mahjong_layout.dart';
import 'mahjong_state.dart';
import 'mahjong_tiles.dart';

/// A board in tray mode, and the tiles waiting in its tray.
///
/// A free tile picked from the board goes into the tray. Two tiles of the
/// same face clear each other at once, so the tray never holds two of a
/// face; when its [capacity] tiles find no pair, the game is lost. The game
/// is won when the board and the tray are empty.
///
/// Immutable, like [MahjongState]: [pick] returns a new one.
class TrayState {
  TrayState(this.board, List<int> tray) : tray = List.unmodifiable(tray);

  static const capacity = 4;

  final MahjongState board;

  /// Ids of the tiles in the tray, in the order they came.
  final List<int> tray;

  bool get isWon => board.isWon && tray.isEmpty;
  bool get isLost => tray.length >= capacity;

  /// Tiles on the board and in the tray.
  int get tileCount => board.tileCount + tray.length;

  /// The tile of the tray that [id] clears when picked, or null.
  int? partnerOf(int id) {
    for (final waiting in tray) {
      if (waiting != id && board.faces[waiting] == board.faces[id]) {
        return waiting;
      }
    }
    return null;
  }

  bool canPick(int id) => !isLost && board.isFree(id);

  /// The board without [id], which goes into the tray or clears its
  /// partner there. Null when [id] cannot be picked.
  TrayState? pick(int id) {
    if (!canPick(id)) return null;
    final partner = partnerOf(id);
    return TrayState(
      board.withSlots([
        for (final tile in board.slots) tile == id ? MahjongState.empty : tile,
      ]),
      partner == null
          ? [...tray, id]
          : [
              for (final waiting in tray)
                if (waiting != partner) waiting,
            ],
    );
  }

  /// The free tiles that clear a tile of the tray.
  List<int> get freeMatches => [
    for (final id in board.tileIds)
      if (board.isFree(id) && partnerOf(id) != null) id,
  ];

  /// The tray is one tile from full and no free tile clears one of it: any
  /// pick loses.
  bool get isStuck =>
      !isLost && tray.length == capacity - 1 && freeMatches.isEmpty;

  /// Whether picking the tiles of [order] one after the other wins: each
  /// tile is free when its turn comes, and the tray never fills.
  bool isSolvedBy(List<int> order) {
    if (order.length != board.tileCount) return false;
    final occupied = [for (final id in board.slots) id != MahjongState.empty];
    final waiting = {for (final id in tray) board.faces[id]};
    if (waiting.length >= capacity) return false;
    for (final id in order) {
      final position = board.positionOf(id);
      if (position == null ||
          !occupied[position] ||
          !board.layout.isFree(position, occupied)) {
        return false;
      }
      occupied[position] = false;
      final face = board.faces[id];
      if (!waiting.remove(face)) {
        waiting.add(face);
        if (waiting.length >= capacity) return false;
      }
    }
    return waiting.isEmpty;
  }
}

/// A tray deal and an order of picks that wins it.
typedef TrayDeal = ({MahjongState state, List<int> solution});

/// Deals a tray board of [layout] that can be won, from [seed]: the same
/// seed always gives the same deal.
///
/// The deal is built forwards: it picks one free tile after the other from
/// the full layout (one is always free), and decides at each pick whether
/// the tile waits in the tray or clears a tile that waits, as [level] says.
/// A tile that waits gets a face not in the tray: a new one, or the face of
/// a pair already cleared (each face has four tiles: two pairs). So picking
/// the tiles in that order never holds more than `level.held` tiles.
///
/// Tiles of a face that are free at the same time show the player a pair:
/// the level decides which ones may (pairs free together, decoys); others
/// are kept apart as much as the layout allows.
TrayDeal generateTrayDeal(
  MahjongLayout layout,
  int seed,
  TrayLevel level, {
  int hiddenPercent = 0,
}) {
  final random = DealRandom(seed);
  final count = layout.length;
  final occupied = List.filled(count, true);
  // For each position, the first step at which it is free (before that
  // step's pick), and the step it is picked.
  final freeSince = List.filled(count, -1);
  final pickedAt = List.filled(count, -1);
  final faces = List.filled(count, 0);
  final order = <int>[];

  final newFaces = _shuffle([
    for (var face = 0; face < TileFace.count; face++) face,
  ], random);
  var usedFaces = 0;
  final tilesOf = <int, List<int>>{};

  /// The tiles waiting in the tray: face, position, step, and whether its
  /// pair is the second one of the face.
  final waiting = <(int, int, int, bool)>[];

  /// Faces with one pair cleared and the other not started.
  final halfDone = <int>[];

  /// Faces whose first pair is in the tray: their second pair is to come.
  var halfWaiting = 0;
  var toOpen = count ~/ 2;

  // The positions under each position, directly or not.
  final under = List.generate(count, (_) => <int>{});
  final byLayer = [for (var p = 0; p < count; p++) p]
    ..sort((a, b) => layout.positions[a].z.compareTo(layout.positions[b].z));
  for (final q in byLayer) {
    for (final p in layout.above[q]) {
      under[p]
        ..add(q)
        ..addAll(under[q]);
    }
  }

  /// For how many steps the tile at [p], picked now, was free together
  /// with the tiles of [face] picked before.
  int seenWith(int p, int face) {
    var steps = 0;
    for (final q in tilesOf[face] ?? const <int>[]) {
      final since = max(freeSince[p], freeSince[q]);
      final together = pickedAt[q] - since + 1;
      if (together > 0) steps += together;
    }
    return steps;
  }

  /// Whether a tile of [face] picked before lies right on [p]: the player
  /// would find a tile on its pair.
  bool onItsFace(int p, int face) {
    final place = layout.positions[p];
    for (final q in tilesOf[face] ?? const <int>[]) {
      final above = layout.positions[q];
      if (above.z == place.z + 1 && place.overlaps(above)) return true;
    }
    return false;
  }

  /// The [choices] (a face and a position) not right under a tile of their
  /// face (unless [stacks]), then whose tile was seen with its face as little
  /// as possible (then the lowest [cost]), or at least once when [seen].
  List<(int, int)> fitting(
    List<(int, int)> choices, {
    required bool seen,
    int Function(int position)? cost,
    bool stacks = false,
  }) {
    final seenFor = [for (final (face, p) in choices) seenWith(p, face)];
    final stacked = [
      for (final (face, p) in choices) !stacks && onItsFace(p, face),
    ];
    if (seen) {
      final visible = [
        for (final (i, choice) in choices.indexed)
          if (seenFor[i] > 0) (choice, stacked[i]),
      ];
      if (visible.isNotEmpty) {
        final apart = [
          for (final (choice, onFace) in visible)
            if (!onFace) choice,
        ];
        return apart.isNotEmpty ? apart : [for (final (c, _) in visible) c];
      }
    }
    final costs = [
      for (final (i, (_, p)) in choices.indexed)
        (stacked[i] ? 1 << 24 : 0) + seenFor[i] * 4 + (cost?.call(p) ?? 0),
    ];
    final lowest = costs.reduce(min);
    return [
      for (final (i, choice) in choices.indexed)
        if (costs[i] == lowest) choice,
    ];
  }

  for (var step = 0; step < count; step++) {
    final free = <int>[];
    for (var p = 0; p < count; p++) {
      if (!occupied[p] || !layout.isFree(p, occupied)) continue;
      free.add(p);
      if (freeSince[p] < 0) freeSince[p] = step;
    }
    // Every face started needs its second pair: once only those are left,
    // a waiting tile takes the face of a cleared pair.
    final onlySecondPairs = toOpen == halfDone.length + halfWaiting;
    final canWait =
        toOpen > 0 &&
        waiting.length < level.held &&
        !(onlySecondPairs && halfDone.isEmpty);
    // A blind pair: its first tile goes into the tray before its partner
    // is free. Its partner is then the waiting tile that a free tile can
    // clear unseen, the oldest first.
    final blind = random.nextInt(100) < level.blindPercent;
    var closing = 0;
    for (final (i, (face, _, _, _)) in waiting.indexed) {
      if (free.any((p) => (seenWith(p, face) == 0) == blind)) {
        closing = i;
        break;
      }
    }
    final waits =
        waiting.isEmpty || (canWait && random.nextInt(100) < level.waitPercent);

    final (int, int) choice;
    if (waits) {
      final second =
          onlySecondPairs ||
          (halfDone.isNotEmpty && random.nextInt(toOpen) < halfDone.length);
      if (second) {
        // A decoy can be seen while the first pair of its face waits.
        final decoy = random.nextInt(100) < level.decoyPercent;
        choice = _pickOne(
          _oldest(
            fitting([
              for (final face in halfDone)
                for (final p in free) (face, p),
            ], seen: decoy),
            (choice) => freeSince[choice.$2],
          ),
          random,
        );
        halfDone.remove(choice.$1);
      } else {
        // The tiles free for the longest time go first: a tile left free
        // for long shows its face next to more tiles.
        choice = (
          newFaces[usedFaces++],
          _pickOne(_oldest(free, (p) => freeSince[p]), random),
        );
        halfWaiting++;
      }
      waiting.add((choice.$1, choice.$2, step, second));
      toOpen--;
    } else {
      final (face, first, since, second) = waiting.removeAt(closing);
      // Where the partner goes follows a pattern picked for each pair. One
      // freed by the first tile alone is easy to guess.
      final pattern = _patterns[random.nextInt(_patterns.length)];
      choice = _pickOne(
        fitting(
          [for (final p in free) (face, p)],
          seen: !blind,
          cost: (p) =>
              pattern.cost(layout, first, p, under: under[first].contains(p)) +
              (freeSince[p] == since + 1 ? 1 : 0),
          stacks: pattern == _PairPattern.under,
        ),
        random,
      );
      if (!second) {
        halfWaiting--;
        halfDone.add(face);
      }
    }
    final (face, picked) = choice;
    faces[picked] = face;
    (tilesOf[face] ??= []).add(picked);
    pickedAt[picked] = step;
    occupied[picked] = false;
    order.add(picked);
  }
  // A tile id is the position of the tile in the deal.
  return (
    state: MahjongState(
      layout: layout,
      faces: faces,
      slots: [for (var i = 0; i < count; i++) i],
      hidden: hiddenTiles(count, seed, hiddenPercent),
    ),
    solution: order,
  );
}

/// Where the partner of a pair goes, among the places that keep the pair
/// blind or seen as the level asks. Always under its first tile, a quarter of
/// the tiles lay right on a tile of their face: each pair now picks one of
/// these patterns.
enum _PairPattern {
  /// Under its first tile: it cannot show beside it in any order.
  under,

  /// Within a few tiles of the first one.
  near,

  /// Across the board from it.
  far,

  /// Any place.
  anywhere;

  /// From 0 (the place fits the pattern best) to 2.
  int cost(MahjongLayout layout, int first, int place, {required bool under}) {
    if (this == _PairPattern.under) return under ? 0 : 2;
    if (under) return 2;
    final a = layout.positions[first];
    final b = layout.positions[place];
    // In tiles.
    final distance = sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)) / 2;
    return switch (this) {
      _PairPattern.near => distance <= 2.5 ? 0 : (distance <= 4.5 ? 1 : 2),
      _PairPattern.far => distance >= 6 ? 0 : (distance >= 3 ? 1 : 2),
      _ => 0,
    };
  }
}

/// The patterns, as often as they are picked.
const _patterns = [
  _PairPattern.under,
  _PairPattern.near,
  _PairPattern.near,
  _PairPattern.far,
  _PairPattern.far,
  _PairPattern.anywhere,
  _PairPattern.anywhere,
];

T _pickOne<T>(List<T> items, DealRandom random) =>
    items[random.nextInt(items.length)];

/// The [items] with the lowest [age].
List<T> _oldest<T>(List<T> items, int Function(T) age) {
  final lowest = items.map(age).reduce(min);
  return [
    for (final item in items)
      if (age(item) == lowest) item,
  ];
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

/// An order of picks that wins [state], or null when there is none, or when
/// the search gives up after [budget] boards (it runs on the UI thread, like
/// `solveMahjong`).
///
/// A depth-first search that never visits a board twice (the tiles gone
/// tell which faces wait in the tray). It tries the tiles that clear a tile
/// of the tray first, then, while the tray has room, the tiles of free
/// pairs, then the tiles that uncover the most. It starts over with
/// shuffled ties every [_restartBoards] boards.
List<int>? solveTray(TrayState state, {int budget = 20000}) {
  if (state.isLost) return null;
  final solver = _TraySolver(state);
  for (var run = 0; run * _restartBoards < budget; run++) {
    final solution = solver.run(
      min(_restartBoards, budget - run * _restartBoards),
      run == 0 ? null : Random(run),
    );
    if (solution != null) return solution;
    if (!solver.gaveUp) return null;
  }
  return null;
}

const _restartBoards = 1000;

class _TraySolver {
  _TraySolver(TrayState state)
    : layout = state.board.layout,
      slots = state.board.slots,
      faces = state.board.faces,
      startTray = [for (final id in state.tray) state.board.faces[id]] {
    for (var p = 0; p < layout.length; p++) {
      for (final q in [
        ...layout.above[p],
        ...layout.left[p],
        ...layout.right[p],
      ]) {
        blocks[q].add(p);
      }
    }
  }

  final MahjongLayout layout;
  final List<int> slots;
  final List<int> faces;
  final List<int> startTray;

  /// The positions that each position blocks: those it lies on or beside.
  late final blocks = List.generate(layout.length, (_) => <int>[]);

  late List<bool> occupied;
  late Set<int> tray;
  final path = <int>[];
  int remaining = 0;
  int boards = 0;
  int budget = 0;
  bool gaveUp = false;
  Random? random;

  List<int>? run(int budget, Random? random) {
    occupied = [for (final id in slots) id != MahjongState.empty];
    tray = {...startTray};
    path.clear();
    remaining = occupied.where((o) => o).length;
    this.budget = budget;
    this.random = random;
    boards = 0;
    gaveUp = false;
    return _search(<String>{}) == true ? [...path] : null;
  }

  String _key() {
    final codes = <int>[];
    for (var p = 0; p < occupied.length; p += 16) {
      var code = 0;
      for (var q = p; q < p + 16 && q < occupied.length; q++) {
        if (occupied[q]) code |= 1 << (q - p);
      }
      codes.add(code);
    }
    return String.fromCharCodes(codes);
  }

  int _uncovered(int p) {
    var count = 0;
    for (final q in blocks[p]) {
      if (occupied[q]) count++;
    }
    return count;
  }

  /// True when won, false when there is no way on, null when the budget is
  /// out.
  bool? _search(Set<String> visited) {
    if (remaining == 0) return tray.isEmpty;
    if (++boards > budget) {
      gaveUp = true;
      return null;
    }
    if (!visited.add(_key())) return false;
    final free = <int>[];
    final freeByFace = <int, int>{};
    for (var p = 0; p < occupied.length; p++) {
      if (occupied[p] && layout.isFree(p, occupied)) {
        free.add(p);
        final face = faces[slots[p]];
        freeByFace[face] = (freeByFace[face] ?? 0) + 1;
      }
    }
    final room = tray.length < TrayState.capacity - 1;
    final moves = <(int, double)>[];
    for (final p in free) {
      final face = faces[slots[p]];
      final double rank;
      if (tray.contains(face)) {
        rank = 1000;
      } else if (!room) {
        continue;
      } else if (freeByFace[face]! >= 2) {
        rank = 500;
      } else {
        rank = 0;
      }
      moves.add((p, rank + _uncovered(p) + (random?.nextDouble() ?? 0)));
    }
    moves.sort((x, y) => y.$2.compareTo(x.$2));
    for (final (p, _) in moves) {
      final face = faces[slots[p]];
      final cleared = tray.remove(face);
      if (!cleared) tray.add(face);
      occupied[p] = false;
      remaining--;
      path.add(slots[p]);
      final result = _search(visited);
      if (result != false) return result;
      path.removeLast();
      remaining++;
      occupied[p] = true;
      if (cleared) {
        tray.add(face);
      } else {
        tray.remove(face);
      }
    }
    return false;
  }
}
