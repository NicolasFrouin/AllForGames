import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_board.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_controller.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:flutter/rendering.dart'
    show RenderCustomPaint, debugOnProfilePaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/minesweeper/minesweeper_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Widget builds per frame while the cells move, after the frame of the
/// action itself, and paints of the layer of the cells at rest.
typedef BuildRates = ({int frames, double all, int stillPaints});

/// An Expert board (seed 42) once it has popped in, or [state].
Future<MinesweeperController> pumpBoard(
  WidgetTester tester, {
  MinesweeperState? state,
}) async {
  useSurface(tester);
  final stores = await createTestStores();
  final controller = MinesweeperController(
    stats: stores.stats,
    saves: stores.saves,
    difficulty: MinesweeperDifficulty.hard,
    seed: 42,
    initialState: state,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: MinesweeperBoard(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<BuildRates> buildRates(WidgetTester tester, VoidCallback action) async {
  // The board paints the cells at rest first, then the cells in motion.
  final still = tester
      .renderObjectList<RenderCustomPaint>(
        find.descendant(
          of: find.byType(MinesweeperBoard),
          matching: find.byType(CustomPaint),
        ),
      )
      .first;
  action();
  await tester.pump();
  var all = 0;
  var stillPaints = 0;
  debugOnRebuildDirtyWidget = (element, _) => all++;
  debugOnProfilePaint = (renderObject) {
    if (renderObject == still) stillPaints++;
  };
  addTearDown(() {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
  });
  var frames = 0;
  while (tester.binding.hasScheduledFrame) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  debugOnRebuildDirtyWidget = null;
  debugOnProfilePaint = null;
  return (frames: frames, all: all / frames, stillPaints: stillPaints);
}

/// A frame only repaints the cells in motion: no widget builds (but the
/// confetti layer once), and the cells at rest paint again only when the
/// motions end.
void expectCheap(BuildRates rates) {
  expect(rates.frames, greaterThan(10), reason: 'the cells moved');
  expect(rates.all, lessThan(0.2));
  expect(rates.stillPaints, lessThanOrEqualTo(2));
}

void main() {
  testWidgets('a new board pops in without rebuilding', (tester) async {
    final controller = await pumpBoard(tester);
    expectCheap(await buildRates(tester, () => controller.newGame(seed: 7)));
  });

  testWidgets('the first reveal spreads without rebuilding', (tester) async {
    final controller = await pumpBoard(tester);
    expectCheap(await buildRates(tester, () => controller.open(8 * 30 + 15)));
    expect(controller.state.openCount, greaterThan(9));
  });

  testWidgets('a flag pops and a hint glows without rebuilding', (
    tester,
  ) async {
    final controller = await pumpBoard(tester, state: cornerBoard);
    controller.open(cornerTap);
    await tester.pumpAndSettle();

    expectCheap(await buildRates(tester, () => controller.toggleFlag(0)));
    expectCheap(await buildRates(tester, controller.hint));
  });

  testWidgets('the mines of a lost game show without rebuilding', (
    tester,
  ) async {
    final controller = await pumpBoard(tester);
    controller.open(8 * 30 + 15);
    await tester.pumpAndSettle();

    expectCheap(
      await buildRates(
        tester,
        () => controller.open(controller.state.mines[0]),
      ),
    );
    expect(controller.state.isLost, isTrue);
  });

  testWidgets('the win celebration rebuilds almost nothing', (tester) async {
    final controller = await pumpBoard(tester, state: cornerBoard);
    controller
      ..open(cornerTap)
      ..open(0);
    await tester.pumpAndSettle();

    expectCheap(await buildRates(tester, () => controller.open(1)));
    expect(controller.result?.won, isTrue);
  });
}
