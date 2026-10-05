import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/games/spider/spider_board.dart';
import 'package:all_for_games/games/spider/spider_controller.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/spider/spider_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Future<SpiderController> pumpBoard(
  WidgetTester tester,
  SpiderState state,
) async {
  useSurface(tester);
  final stores = await createTestStores();
  final controller = SpiderController(
    stats: stores.stats,
    saves: stores.saves,
    initialState: state,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(
        body: SpiderBoard(
          controller: controller,
          // A back with a pattern: the most painting per card.
          cardBack: cardBackById('emerald'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Widget builds per frame while the cards move, after the frame of the
/// action itself: with 104 cards on the table, a frame only repaints the
/// moving cards (see klondike_board_rebuilds_test.dart).
Future<void> expectCheap(WidgetTester tester, VoidCallback action) async {
  action();
  await tester.pump();
  var all = 0;
  var cardViews = 0;
  debugOnRebuildDirtyWidget = (element, _) {
    all++;
    if (element.widget is CardView) cardViews++;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  var frames = 0;
  while (tester.binding.hasScheduledFrame) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  debugOnRebuildDirtyWidget = null;
  expect(frames, greaterThan(10), reason: 'the cards moved');
  expect(cardViews / frames, lessThan(1));
  expect(all / frames, lessThan(5));
}

void main() {
  testWidgets('a stock deal flies without rebuilding the board', (
    tester,
  ) async {
    final controller = await pumpBoard(
      tester,
      SpiderState.deal(42, SpiderDifficulty.hard),
    );
    await expectCheap(tester, controller.dealStock);
  });

  testWidgets('the last run and the celebration rebuild almost nothing', (
    tester,
  ) async {
    final controller = await pumpBoard(tester, nearWon());
    await expectCheap(tester, () => controller.move(1, 1, 0));
    expect(controller.result, isNotNull);
  });
}
