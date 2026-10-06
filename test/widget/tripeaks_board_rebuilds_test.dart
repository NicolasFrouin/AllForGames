import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_board.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_controller.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/tripeaks/tripeaks_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Future<TriPeaksController> pumpBoard(
  WidgetTester tester,
  TriPeaksState state,
) async {
  useSurface(tester);
  final stores = await createTestStores();
  final controller = TriPeaksController(
    stats: stores.stats,
    saves: stores.saves,
    initialState: state,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(
        body: TriPeaksBoard(
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
/// action itself: a frame only repaints the moving cards (see
/// klondike_board_rebuilds_test.dart).
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
  testWidgets('a drawn card flies and turns without rebuilding the board', (
    tester,
  ) async {
    final controller = await pumpBoard(tester, TriPeaksState.deal(42));
    await expectCheap(tester, controller.draw);
  });

  testWidgets('a played card flies, and the card it uncovers turns over', (
    tester,
  ) async {
    final controller = await pumpBoard(
      tester,
      board(tableau: {9: '9H', 18: '8C', 19: '7D'}, waste: '9S'),
    );
    controller.play(18);
    await tester.pumpAndSettle();
    await expectCheap(tester, () => controller.play(19));
    expect(controller.state.tableau[9]!.faceUp, isTrue);
  });

  testWidgets('a deal rebuilds only the cards that turn over', (tester) async {
    final controller = await pumpBoard(tester, TriPeaksState.deal(42));
    await expectCheap(tester, () => controller.newGame(seed: 7));
  });

  testWidgets('the win, its bonus cards and the celebration rebuild almost '
      'nothing', (tester) async {
    final controller = await pumpBoard(
      tester,
      board(
        tableau: {0: '5C'},
        stock: '2H 3H 4H 5H 6H 7H 8H 9H 10H JH QH KH 2D 3D 4D 5D 6D 7D',
        waste: '4S',
      ),
    );
    await expectCheap(tester, () => controller.play(0));
    expect(controller.result, isNotNull);
  });
}
