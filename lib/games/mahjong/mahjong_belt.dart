import 'dart:math';

import 'mahjong_layout.dart';
import 'mahjong_state.dart';
import 'mahjong_tiles.dart';
import 'mahjong_tray.dart';

/// The id of [layoutId] with a conveyor belt: records name the variant by it.
String beltLayoutId(String layoutId) => 'belt-$layoutId';

/// [layout] with a conveyor belt: a loop of tiles on the table layer, as
/// wide as the board, one row in from its top and bottom edges (the still
/// tiles there, and the pile inside the loop, do not move). Tiles that lay
/// on the loop's places go, with those that rested on them; the loop's
/// places are all filled. A stack more than three layers above a tile
/// beside it would hide the middle of that tile (layers are drawn up and to
/// the left): its top goes too. The count stays a multiple of four, at most four
/// tiles of each face: the highest tiles go first. Its tiles go round
/// [clockwise] on screen or not.
///
/// Pure Dart: the deal is built on it at runtime, like the shapes.
MahjongLayout withBelt(MahjongLayout layout, {required bool clockwise}) {
  final positions = layout.positions;
  final minX = positions.map((p) => p.x).reduce(min);
  final minY = positions.map((p) => p.y).reduce(min);
  final maxX = positions.map((p) => p.x).reduce(max);
  final maxY = positions.map((p) => p.y).reduce(max);
  final right = minX + (maxX - minX) ~/ 2 * 2;
  final rows = (maxY - minY) ~/ 2 + 1;
  final top = rows >= 5 ? minY + 2 : minY;
  final bottom = top + ((rows >= 5 ? maxY - 2 : maxY) - top) ~/ 2 * 2;
  if (right == minX || bottom == top) return layout;

  final loop = [
    for (var x = minX; x <= right; x += 2) TilePosition(x, top, 0),
    for (var y = top + 2; y < bottom; y += 2) TilePosition(right, y, 0),
    for (var x = right; x >= minX; x -= 2) TilePosition(x, bottom, 0),
    for (var y = bottom - 2; y > top; y -= 2) TilePosition(minX, y, 0),
  ];
  var kept = [
    for (final p in positions)
      if (!loop.any(p.overlaps)) p,
  ];
  // A tile needs a tile under it.
  while (true) {
    final resting = [
      for (final p in kept)
        if (p.z == 0 || kept.any((q) => q.z == p.z - 1 && q.overlaps(p))) p,
    ];
    if (resting.length == kept.length) break;
    kept = resting;
  }
  // Steep steps go from the top down, one layer a round.
  while (true) {
    final all = [...kept, ...loop];
    int height(int x, int y) => all.fold(
      0,
      (h, q) => q.x == x && q.y == y && q.z + 1 > h ? q.z + 1 : h,
    );
    bool steep(TilePosition p) {
      for (final dx in const [-2, 0, 2]) {
        for (final dy in const [-2, 0, 2]) {
          if (dx == 0 && dy == 0) continue;
          final beside = height(p.x + dx, p.y + dy);
          if (beside > 0 && p.z + 1 - beside > 3) return true;
        }
      }
      return false;
    }

    bool covered(TilePosition p) =>
        kept.any((q) => q.z == p.z + 1 && q.overlaps(p));
    final cut = kept.where((p) => !covered(p) && steep(p)).toList();
    if (cut.isEmpty) break;
    kept.removeWhere(cut.contains);
  }
  while ((kept.length + loop.length) % 4 != 0 ||
      kept.length + loop.length > TileFace.count * 4) {
    bool covered(TilePosition p) =>
        kept.any((q) => q.z == p.z + 1 && q.overlaps(p));
    final open = kept.where((p) => !covered(p)).toList();
    if (open.isEmpty) return layout;
    final highest = open.map((p) => p.z).reduce(max);
    kept.remove(open.lastWhere((p) => p.z == highest));
  }
  final ordered = clockwise ? loop : loop.reversed.toList();
  return MahjongLayout(
    beltLayoutId(layout.id),
    [...kept, ...ordered],
    transposed: layout.transposed,
    belt: [for (var i = 0; i < ordered.length; i++) kept.length + i],
  );
}

/// An order of pairs that clears [state], whose belt turns after each match,
/// or null when there is none or the search gives up after [budget] boards.
///
/// `solveMahjong` knows where each tile stays; with a belt they move, so
/// this simpler search plays the board: the pairs that block the most tiles
/// first, never a board twice, and never two last tiles of a face that lie
/// one on the other.
List<TilePair>? solveBelt(MahjongState state, {int budget = 4000}) {
  final weight = _blockWeight(state.layout);
  final seen = <String>{};
  final path = <TilePair>[];
  var boards = 0;

  bool deadEnd(MahjongState board) {
    final byFace = <int, List<int>>{};
    for (final id in board.tileIds) {
      (byFace[board.faces[id]] ??= []).add(board.positionOf(id)!);
    }
    for (final places in byFace.values) {
      if (places.length != 2) continue;
      final [a, b] = places;
      final above = board.layout.above;
      if (above[a].contains(b) || above[b].contains(a)) return true;
    }
    return false;
  }

  bool search(MahjongState board) {
    if (board.isWon) return true;
    if (boards++ >= budget ||
        !seen.add(board.slots.join(',')) ||
        deadEnd(board)) {
      return false;
    }
    int score(TilePair pair) => weight(board, pair.$1) + weight(board, pair.$2);
    final pairs = [...board.freePairs]
      ..sort((x, y) => score(y).compareTo(score(x)));
    for (final (a, b) in pairs) {
      path.add((a, b));
      if (search(board.match(a, b)!)) return true;
      path.removeLast();
      if (boards >= budget) return false;
    }
    return false;
  }

  return search(state) ? path : null;
}

/// An order of picks that wins [state] in tray mode, whose belt turns after
/// each pick, or null when there is none or the search gives up after
/// [budget] boards: picks that clear the tray first, then tiles whose
/// partner is free too, then those that block the most tiles.
List<int>? solveBeltTray(TrayState state, {int budget = 4000}) {
  final weight = _blockWeight(state.board.layout);
  final seen = <String>{};
  final path = <int>[];
  var boards = 0;

  bool search(TrayState current) {
    if (current.isWon) return true;
    final board = current.board;
    if (current.isLost ||
        boards++ >= budget ||
        !seen.add('${board.slots.join(',')}|${[...current.tray]..sort()}')) {
      return false;
    }
    final free = [
      for (final id in board.tileIds)
        if (board.isFree(id)) id,
    ];
    int rank(int id) {
      if (current.partnerOf(id) != null) return 0;
      final pairFree = free.any(
        (other) => other != id && board.faces[other] == board.faces[id],
      );
      return pairFree ? 1 : 2;
    }

    final last = current.tray.length == TrayState.capacity - 1;
    final picks =
        [
          for (final id in free)
            if (!last || current.partnerOf(id) != null) id,
        ]..sort((a, b) {
          final byRank = rank(a).compareTo(rank(b));
          return byRank != 0
              ? byRank
              : weight(board, b).compareTo(weight(board, a));
        });
    for (final id in picks) {
      path.add(id);
      if (search(current.pick(id)!)) return true;
      path.removeLast();
      if (boards >= budget) return false;
    }
    return false;
  }

  return search(state) ? path : null;
}

/// How many tiles the tile [id] of a board holds back: those it lies on or
/// lies beside.
int Function(MahjongState board, int id) _blockWeight(MahjongLayout layout) {
  final blocks = List.generate(layout.length, (_) => <int>[]);
  for (var p = 0; p < layout.length; p++) {
    for (final q in [
      ...layout.above[p],
      ...layout.left[p],
      ...layout.right[p],
    ]) {
      blocks[q].add(p);
    }
  }
  return (board, id) {
    var count = 0;
    for (final p in blocks[board.positionOf(id)!]) {
      if (board.slots[p] != MahjongState.empty) count++;
    }
    return count;
  };
}
