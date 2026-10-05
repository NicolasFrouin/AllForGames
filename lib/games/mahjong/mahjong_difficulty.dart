import 'mahjong_layout.dart';

/// Levels of Mahjong deals: a layout, and the share of faces placed as traps
/// by the generator (`generateDeal`). `tool/mahjong_difficulty.dart` checks
/// them with simulated players.
///
/// Pure Dart: the rules, the generator and the tool use it without Flutter.
enum MahjongDifficulty {
  easy('pyramid', 0),
  medium('turtle', 15),
  hard('turtle', 50);

  const MahjongDifficulty(this.layoutId, this.trapPercent);

  final String layoutId;
  final int trapPercent;

  MahjongLayout layout({bool transposed = false}) =>
      layoutById(layoutId, transposed: transposed)!;
}
