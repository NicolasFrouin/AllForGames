import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/klondike/klondike_board.dart';
import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/klondike/klondike_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Widget builds per frame while the cards move, after the frame of the
/// action itself.
typedef BuildRates = ({int frames, double all, double cardViews, int drags});

Future<KlondikeController> pumpBoard(
  WidgetTester tester,
  KlondikeState state,
) async {
  useSurface(tester);
  final stores = await createTestStores();
  final controller = KlondikeController(
    stats: stores.stats,
    saves: stores.saves,
    initialState: state,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(
        body: KlondikeBoard(
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

Future<BuildRates> buildRates(WidgetTester tester, VoidCallback action) async {
  action();
  await tester.pump();
  var all = 0;
  var cardViews = 0;
  var drags = 0;
  debugOnRebuildDirtyWidget = (element, _) {
    all++;
    if (element.widget is CardView) cardViews++;
    if (element.widget is Draggable) drags++;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  var frames = 0;
  while (tester.binding.hasScheduledFrame) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  debugOnRebuildDirtyWidget = null;
  return (
    frames: frames,
    all: all / frames,
    cardViews: cardViews / frames,
    drags: drags,
  );
}

/// Before the shared card table, every frame rebuilt the whole board: 52
/// card views and 430 to 650 widgets. Now a frame only repaints the moving
/// cards; widgets build when a card turns over or the paint order changes.
void expectCheap(BuildRates rates) {
  expect(rates.frames, greaterThan(10), reason: 'the cards moved');
  expect(rates.cardViews, lessThan(1));
  expect(rates.all, lessThan(5));
  expect(rates.drags, 0);
}

void main() {
  testWidgets('a drawn card flies and turns without rebuilding the board', (
    tester,
  ) async {
    final controller = await pumpBoard(tester, KlondikeState.deal(42));
    expectCheap(await buildRates(tester, controller.draw));
  });

  testWidgets('a deal rebuilds only the cards that turn over', (tester) async {
    final controller = await pumpBoard(tester, KlondikeState.deal(42));
    expectCheap(await buildRates(tester, () => controller.newGame(seed: 7)));
  });

  testWidgets('the win cascade and celebration rebuild almost nothing', (
    tester,
  ) async {
    // Four columns of 13 face-up cards, king to ace: all 52 cards fly.
    final controller = await pumpBoard(
      tester,
      board(
        tableau: [
          for (final suit in Suit.values)
            [
              for (var rank = 13; rank >= 1; rank--)
                PlayingCard(suit, rank, faceUp: true),
            ],
        ],
      ),
    );
    expectCheap(await buildRates(tester, controller.autoComplete));
    expect(controller.result, isNotNull);
  });
}
