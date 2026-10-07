import 'mahjong_layout.dart';

/// The ways to play Mahjong: [classic] matches two free tiles at a time;
/// in [tray], each tile tapped goes into a tray of four places, where two
/// tiles of a face clear each other, and a full tray loses the game.
///
/// Pure Dart: the settings and the offline tool use it.
enum MahjongMode { classic, tray }

/// Where the tray of the tray mode is, next to the board (a setting).
enum MahjongTraySide { top, bottom, left, right }

/// How the tray deals of a level are built (`generateTrayDeal`): the order
/// that wins a deal holds at most [held] tiles in the tray at once. After a
/// pick that waits in the tray, the next one waits too with [waitPercent]
/// chances. [blindPercent] of the pairs are not free together: their first
/// tile goes into the tray before its partner is free, so the player must
/// guess it. [decoyPercent] of the second pairs of a face can be seen with
/// the first pair: more pairs to see, in an order other than the winning
/// one. `tool/mahjong_difficulty.dart` shows that seen pairs make a deal
/// easier, blind pairs and held tiles harder.
class TrayLevel {
  const TrayLevel({
    required this.held,
    required this.waitPercent,
    required this.blindPercent,
    required this.decoyPercent,
  }) : assert(held >= 1 && held < 4);

  final int held;
  final int waitPercent;
  final int blindPercent;
  final int decoyPercent;
}

/// Levels of Mahjong deals: a layout, and the share of faces placed as traps
/// by the generator (`generateDeal`), or the tray deal level ([tray]).
/// `tool/mahjong_difficulty.dart` checks them with simulated players.
///
/// Pure Dart: the rules, the generator and the tool use it without Flutter.
enum MahjongDifficulty {
  easy(
    'pyramid',
    0,
    TrayLevel(held: 1, waitPercent: 0, blindPercent: 0, decoyPercent: 0),
  ),
  medium(
    'turtle',
    15,
    TrayLevel(held: 2, waitPercent: 40, blindPercent: 50, decoyPercent: 30),
  ),
  hard(
    'turtle',
    50,
    TrayLevel(held: 3, waitPercent: 80, blindPercent: 100, decoyPercent: 0),
  );

  const MahjongDifficulty(this.layoutId, this.trapPercent, this.tray);

  final String layoutId;
  final int trapPercent;
  final TrayLevel tray;

  MahjongLayout layout({bool transposed = false}) =>
      layoutById(layoutId, transposed: transposed)!;
}
