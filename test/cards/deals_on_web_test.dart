import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../games/freecell/freecell_state_test.dart' as freecell;
import '../games/klondike/klondike_state_test.dart' as klondike;
import '../games/mahjong/mahjong_generator_test.dart' as mahjong;
import '../games/mahjong/mahjong_tray_test.dart' as tray;
import '../games/spider/spider_state_test.dart' as spider;
import '../games/tripeaks/tripeaks_state_test.dart' as tripeaks;

/// Every game deals from a seed, and the lists of winnable deals were proven
/// on the Dart VM. CI runs this file in Chrome with WebAssembly (the release
/// build): each deal must be the one the VM gives.
void main() {
  test('Klondike', () {
    expect(KlondikeState.deal(1).encode(), klondike.seed1Deal);
  });

  test('FreeCell', () {
    expect(FreeCellState.deal(1).encode(), freecell.seed1Deal);
  });

  test('Spider', () {
    expect(
      SpiderState.deal(1, SpiderDifficulty.hard).encode(),
      spider.seed1HardDeal,
    );
  });

  test('TriPeaks', () {
    expect(TriPeaksState.deal(1).encode(), tripeaks.seed1Deal);
  });

  test('Mahjong', () {
    final faces = mahjong.deal(MahjongDifficulty.medium, 1).state.faces;
    expect(
      faces.take(mahjong.seed1MediumFaces.length),
      mahjong.seed1MediumFaces,
    );
  });

  test('Mahjong tray mode', () {
    final faces = tray.trayDeal(MahjongDifficulty.medium, 1).state.faces;
    expect(
      faces.take(tray.seed1MediumTrayFaces.length),
      tray.seed1MediumTrayFaces,
    );
  });
}
