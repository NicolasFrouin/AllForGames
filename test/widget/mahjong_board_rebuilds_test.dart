import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/mahjong/mahjong_board.dart';
import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tile_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/mahjong/mahjong_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Widget builds per frame while the tiles move, after the frame of the
/// action itself.
typedef BuildRates = ({int frames, double all, double tileViews});

/// A board of 144 tiles (seed 42, Medium) once it has dropped in, or
/// [state].
Future<MahjongController> pumpBoard(
  WidgetTester tester, {
  MahjongState? state,
  MahjongMode mode = MahjongMode.classic,
}) async {
  useSurface(tester);
  final stores = await createTestStores();
  final controller = MahjongController(
    stats: stores.stats,
    saves: stores.saves,
    mode: mode,
    seed: 42,
    initialState: state,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: MahjongBoard(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<BuildRates> buildRates(WidgetTester tester, VoidCallback action) async {
  action();
  await tester.pump();
  var all = 0;
  var tileViews = 0;
  debugOnRebuildDirtyWidget = (element, _) {
    all++;
    if (element.widget is MahjongTileView) tileViews++;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  var frames = 0;
  while (tester.binding.hasScheduledFrame) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  debugOnRebuildDirtyWidget = null;
  return (frames: frames, all: all / frames, tileViews: tileViews / frames);
}

/// Before the moving tiles, every frame rebuilt the whole board: 144 tile
/// views and about 1010 widgets. Now a frame only repaints the tiles that
/// move or glow; a few widgets build when the paint order changes or a
/// selected tile goes down.
void expectCheap(BuildRates rates) {
  expect(rates.frames, greaterThan(10), reason: 'the tiles moved');
  expect(rates.tileViews, 0);
  expect(rates.all, lessThan(0.5));
}

void main() {
  testWidgets('a new deal drops in without rebuilding the tiles', (
    tester,
  ) async {
    final controller = await pumpBoard(tester);
    expectCheap(await buildRates(tester, () => controller.newGame(seed: 7)));
  });

  testWidgets('a matched pair vanishes without rebuilding the board', (
    tester,
  ) async {
    final controller = await pumpBoard(tester);
    final (a, b) = controller.state.freePairs.first;
    take(controller, a);
    await tester.pumpAndSettle();

    // A face-down b goes with a as it turns over.
    expectCheap(await buildRates(tester, () => take(controller, b)));
    expect(controller.state.tileCount, 142);
  });

  testWidgets('a hint pulses without rebuilding the board', (tester) async {
    final controller = await pumpBoard(tester);
    expectCheap(await buildRates(tester, controller.hint));
  });

  testWidgets('the win celebration rebuilds almost nothing', (tester) async {
    final controller = await pumpBoard(
      tester,
      state: board(row(2), [dots1, dots1]),
    );
    controller.tap(0);
    await tester.pumpAndSettle();

    expectCheap(await buildRates(tester, () => controller.tap(1)));
    expect(controller.result?.won, isTrue);
  });

  group('tray mode', () {
    testWidgets('a tile flies into the tray, and a pair pops, without '
        'rebuilding the board', (tester) async {
      final controller = await pumpBoard(tester, mode: MahjongMode.tray);
      expectCheap(
        await buildRates(tester, () => controller.tap(controller.hintPick()!)),
      );
      // The picks of the winning order, until one clears a tile of the tray.
      while (true) {
        final pick = controller.hintPick()!;
        await tester.pumpAndSettle();
        if (controller.trayState.partnerOf(pick) != null) {
          final held = controller.tray.length;
          expectCheap(await buildRates(tester, () => controller.tap(pick)));
          expect(controller.tray, hasLength(held - 1));
          break;
        }
        controller.tap(pick);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a full tray flashes without rebuilding the board', (
      tester,
    ) async {
      final controller = await pumpBoard(tester, mode: MahjongMode.tray);
      final state = controller.state;
      final picks = <int>[];
      for (final id in state.tileIds) {
        final face = state.faces[id];
        if (state.isFree(id) &&
            picks.every((pick) => state.faces[pick] != face)) {
          picks.add(id);
        }
      }
      for (final id in picks.take(3)) {
        take(controller, id);
        await tester.pumpAndSettle();
      }
      if (!controller.isFaceUp(picks[3])) controller.tap(picks[3]);
      await tester.pumpAndSettle();

      expectCheap(await buildRates(tester, () => controller.tap(picks[3])));
      expect(controller.isLost, isTrue);
    });
  });
}
