import 'mahjong_layout.dart';
import 'mahjong_tiles.dart';

/// Two tiles that match, by tile id.
typedef TilePair = (int, int);

/// A Mahjong solitaire board: which tile is on which position of [layout].
///
/// Immutable: [match] returns a new board. Each tile keeps its id (its
/// position in the deal) and its face for the whole game, also when a
/// shuffle moves it.
class MahjongState {
  MahjongState({
    required this.layout,
    required this.faces,
    required List<int> slots,
    this.hidden = const {},
  }) : slots = List.unmodifiable(slots),
       assert(slots.length == layout.length);

  /// Face code ([TileFace.code]) of each tile, by tile id.
  final List<int> faces;

  /// Ids of the tiles that lie face down. They follow the same rules: the
  /// player turns one over to see it (the controller keeps which one).
  final Set<int> hidden;

  /// The discs of the discs mode ([MahjongLayout.discs]): each is free once
  /// no tile lies on it ([isDiscFree]).
  List<TilePosition> get discs => layout.discs;

  /// The id of the tile on each position of [layout], or [empty].
  final List<int> slots;
  final MahjongLayout layout;

  static const empty = -1;

  late final List<bool> _occupied = [for (final id in slots) id != empty];

  late final Map<int, int> _positions = {
    for (final (position, id) in slots.indexed)
      if (id != empty) id: position,
  };

  int get tileCount => _positions.length;
  bool get isWon => _positions.isEmpty;

  /// Ids of the tiles on the board.
  Iterable<int> get tileIds => _positions.keys;

  TileFace faceOf(int id) => TileFace(faces[id]);

  bool isHidden(int id) => hidden.contains(id);

  bool isDiscFree(int disc) =>
      !layout.discCovers[disc].any((p) => _occupied[p]);

  int get freeDiscs =>
      [for (var i = 0; i < discs.length; i++) i].where(isDiscFree).length;

  /// The goal of the discs mode.
  bool get discsFree => discs.isNotEmpty && freeDiscs == discs.length;

  /// The position of tile [id], or null when it is gone.
  int? positionOf(int id) => _positions[id];

  bool isFree(int id) {
    final position = _positions[id];
    return position != null && layout.isFree(position, _occupied);
  }

  /// Whether [a] and [b] are two free tiles of the same face.
  bool canMatch(int a, int b) =>
      a != b && isFree(a) && isFree(b) && faces[a] == faces[b];

  /// The board without [a] and [b], or null when they cannot be matched.
  MahjongState? match(int a, int b) {
    if (!canMatch(a, b)) return null;
    return withSlots([for (final id in slots) id == a || id == b ? empty : id]);
  }

  /// This board with the tiles on other positions (a shuffle, an undo).
  MahjongState withSlots(List<int> slots) =>
      MahjongState(layout: layout, faces: faces, slots: slots, hidden: hidden);

  /// This board with [discs] lying under its tiles.
  MahjongState withDiscs(List<TilePosition> discs) => MahjongState(
    layout: layout.withDiscs(discs),
    faces: faces,
    slots: slots,
    hidden: hidden,
  );

  /// Every pair of free tiles that match.
  late final List<TilePair> freePairs = _freePairs();

  List<TilePair> _freePairs() {
    final byFace = <int, List<int>>{};
    for (final id in _positions.keys) {
      if (isFree(id)) (byFace[faces[id]] ??= []).add(id);
    }
    return [
      for (final ids in byFace.values)
        for (var i = 0; i < ids.length; i++)
          for (var j = i + 1; j < ids.length; j++) (ids[i], ids[j]),
    ];
  }

  /// No match is left, but tiles are.
  bool get isStuck => !isWon && freePairs.isEmpty;

  /// Whether removing the pairs of [order] one after the other clears the
  /// board, each pair being free and matching when its turn comes.
  bool isSolvedBy(List<TilePair> order) {
    if (order.length * 2 != tileCount) return false;
    final occupied = [..._occupied];
    for (final (a, b) in order) {
      final pa = _positions[a];
      final pb = _positions[b];
      if (pa == null ||
          pb == null ||
          pa == pb ||
          !occupied[pa] ||
          !occupied[pb] ||
          faces[a] != faces[b] ||
          !layout.isFree(pa, occupied) ||
          !layout.isFree(pb, occupied)) {
        return false;
      }
      occupied[pa] = false;
      occupied[pb] = false;
    }
    return true;
  }
}
