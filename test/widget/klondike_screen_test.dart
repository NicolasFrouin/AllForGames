import 'dart:math';

import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/klondike/card_view.dart';
import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/klondike/klondike_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Two cards in the stock: the 2♠ is drawn first.
final stockBoard = board(
  stock: [card('KD', up: false), card('2S', up: false)],
  tableau: [
    [card('5C')],
  ],
);

/// The seed 42 deal: a full board, so a save of it can continue.
final deal = KlondikeState.deal(Random(42));

/// Opens [state] in the app routes, with the hub below the game. Opening the
/// game again from the hub continues the saved game.
Future<AppStores> pumpGame(
  WidgetTester tester,
  KlondikeState state, {
  DateTime Function()? clock,
}) async {
  useSurface(tester);
  final stores = await createTestStores();
  final router = GoRouter(
    initialLocation: '/klondike',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'klondike',
            builder: (context, route) => KlondikeScreen(
              stores: stores,
              initialState: route.extra as KlondikeState?,
              clock: clock,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(KlondikeController.gameId)!,
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return stores;
}

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Top-left corner of a card (by card id) or of an empty pile slot.
Offset at(WidgetTester tester, String key) => tester.getTopLeft(byKey(key));

bool isFaceUp(WidgetTester tester, String cardId) => tester
    .widget<CardView>(
      find.descendant(of: byKey(cardId), matching: find.byType(CardView)),
    )
    .card
    .faceUp;

int faceUpCount(WidgetTester tester) => tester
    .widgetList<CardView>(find.byType(CardView))
    .where((view) => view.card.faceUp)
    .length;

bool canUndo(WidgetTester tester) =>
    tester.widget<IconButton>(byKey('undo')).onPressed != null;

Future<void> tapStock(WidgetTester tester) async {
  // The stock cards cover the stock slot and draw when tapped.
  await tester.tapAt(tester.getCenter(byKey('stock')));
  await tester.pumpAndSettle();
}

/// Opacity of a card on the board: 0 while it is dragged.
double opacityOf(WidgetTester tester, String cardId) => tester
    .widget<Opacity>(
      find.descendant(of: byKey(cardId), matching: find.byType(Opacity)).first,
    )
    .opacity;

/// Drags [cardId] (and the cards on it) onto the pile slot [pileKey].
/// [overTarget] runs while the cards are held over the pile.
Future<void> dragCard(
  WidgetTester tester,
  String cardId,
  String pileKey, {
  void Function()? overTarget,
}) async {
  // The cards above it leave only the top strip of the card visible.
  final start = at(tester, cardId) + const Offset(10, 6);
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(byKey(pileKey)));
  await tester.pump();
  overTarget?.call();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> leaveGame(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(KlondikeScreen), findsNothing);
  expect(find.byType(HubScreen), findsOneWidget);
}

Future<void> openFromHub(WidgetTester tester) async {
  await tester.tap(byKey('game-klondike'));
  await tester.pumpAndSettle();
  expect(find.byType(KlondikeScreen), findsOneWidget);
}

/// Checks the top card of each tableau pile of [state] is on its pile, face up.
void expectTableauTops(WidgetTester tester, KlondikeState state) {
  for (var i = 0; i < 7; i++) {
    final top = state.tableau[i].last.id;
    expect(at(tester, top).dx, at(tester, 'tableau-$i').dx, reason: top);
    expect(isFaceUp(tester, top), isTrue, reason: top);
  }
}

Future<void> chooseNewGame(WidgetTester tester, {required int draw}) async {
  await tester.tap(byKey('new-game'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New game · Draw $draw'));
  await tester.pumpAndSettle();
}

const confirmTitle = 'Start a new game?';

void main() {
  testWidgets('tapping the stock turns its top card into the waste', (
    tester,
  ) async {
    await pumpGame(tester, stockBoard);
    expect(textOf('moves-value'), '0');
    expect(canUndo(tester), isFalse);

    await tapStock(tester);

    expect(textOf('moves-value'), '1');
    expect(at(tester, 'spades-2'), at(tester, 'waste'));
    expect(isFaceUp(tester, 'spades-2'), isTrue);
    expect(at(tester, 'diamonds-13'), at(tester, 'stock'));
    expect(isFaceUp(tester, 'diamonds-13'), isFalse);
    expect(canUndo(tester), isTrue);
  });

  testWidgets('undo puts the card back but still counts the move made', (
    tester,
  ) async {
    await pumpGame(tester, stockBoard);
    await tapStock(tester);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();

    // Moves counts the moves made: undo does not take one back.
    expect(textOf('moves-value'), '1');
    expect(at(tester, 'spades-2'), at(tester, 'stock'));
    expect(isFaceUp(tester, 'spades-2'), isFalse);
    expect(canUndo(tester), isFalse);
  });

  testWidgets('tapping a card that fits a foundation moves it there', (
    tester,
  ) async {
    await pumpGame(
      tester,
      board(
        stock: [card('KD', up: false)],
        tableau: [
          [card('5C', up: false), card('AH')],
        ],
      ),
    );

    await tester.tap(byKey('hearts-1'));
    await tester.pumpAndSettle();

    expect(at(tester, 'hearts-1'), at(tester, 'foundation-2'));
    expect(isFaceUp(tester, 'clubs-5'), isTrue);
    expect(textOf('moves-value'), '1');
    expect(textOf('score-value'), '15');
  });

  group('dragging', () {
    final dragBoard = board(
      stock: [card('KD', up: false)],
      tableau: [
        [card('3D', up: false), card('9H'), card('8C')],
        [card('10S')],
        [card('10H')],
      ],
    );

    testWidgets('a run onto a legal pile moves it', (tester) async {
      await pumpGame(tester, dragBoard);

      await dragCard(tester, 'hearts-9', 'tableau-1');

      final pileX = at(tester, 'tableau-1').dx;
      expect(at(tester, 'hearts-9').dx, pileX);
      expect(at(tester, 'clubs-8').dx, pileX);
      expect(at(tester, 'clubs-8').dy, greaterThan(at(tester, 'hearts-9').dy));
      expect(isFaceUp(tester, 'diamonds-3'), isTrue);
      expect(textOf('moves-value'), '1');
      expect(textOf('score-value'), '5');
    });

    testWidgets('onto an illegal pile changes nothing', (tester) async {
      await pumpGame(tester, dragBoard);
      final nine = at(tester, 'hearts-9');
      final eight = at(tester, 'clubs-8');

      // A red 9 cannot go on a red 10.
      await dragCard(
        tester,
        'hearts-9',
        'tableau-2',
        overTarget: () {
          expect(opacityOf(tester, 'hearts-9'), 0, reason: 'being dragged');
          expect(opacityOf(tester, 'clubs-8'), 0, reason: 'being dragged');
        },
      );

      expect(at(tester, 'hearts-9'), nine);
      expect(at(tester, 'clubs-8'), eight);
      expect(opacityOf(tester, 'hearts-9'), 1);
      expect(opacityOf(tester, 'clubs-8'), 1);
      expect(isFaceUp(tester, 'diamonds-3'), isFalse);
      expect(textOf('moves-value'), '0');
      expect(canUndo(tester), isFalse);
    });
  });

  group('auto-complete', () {
    // Only the kings of clubs, hearts and spades and the queen of hearts are
    // left, all face up.
    final finishBoard = board(
      foundations: foundationsUpTo([12, 13, 11, 12]),
      tableau: [
        [card('KC')],
        [card('KS'), card('QH')],
        [card('KH')],
      ],
    );

    Future<AppStores> finish(WidgetTester tester) async {
      final stores = await pumpGame(tester, finishBoard);
      await tester.tap(byKey('auto-complete'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
      return stores;
    }

    testWidgets('wins the game, then play again starts a new one', (
      tester,
    ) async {
      final stores = await finish(tester);
      expect(at(tester, 'spades-13'), at(tester, 'foundation-3'));
      final record = stores.stats.records.single;
      expect(record.outcome, GameOutcome.won);
      expect(record.moves, 1);
      expect(record.details[KlondikeStatKeys.autoCompleted], 1);

      await tester.tap(byKey('play-again'));
      await tester.pumpAndSettle();

      expect(find.text('You won!'), findsNothing);
      expect(textOf('moves-value'), '0');
      expect(textOf('score-value'), '0');
      expect(byKey('auto-complete'), findsNothing);
      expect(stores.stats.records, hasLength(1));
    });

    testWidgets('back to games shows the win on the hub', (tester) async {
      final stores = await finish(tester);

      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(find.byType(KlondikeScreen), findsNothing);
      expect(textOf('summary-klondike'), startsWith('1 played · 100% won'));
      expect(stores.stats.records.single.outcome, GameOutcome.won);
    });

    testWidgets('a win removes the saved game: the next visit deals anew', (
      tester,
    ) async {
      final stores = await pumpGame(tester, finishBoard);
      await tester.tap(byKey('hearts-12'));
      await tester.pumpAndSettle();
      expect(stores.saves[KlondikeController.gameId]!.moves, 1);

      await tester.tap(byKey('auto-complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(stores.saves[KlondikeController.gameId], isNull);
      expect(await storedSave(KlondikeController.gameId), isNull);
      expect(byKey('resume-klondike'), findsNothing);

      await openFromHub(tester);
      expect(textOf('moves-value'), '0');
      expect(byKey('auto-complete'), findsNothing);
      // A new deal shows the 7 tableau tops.
      expect(faceUpCount(tester), 7);
    });
  });

  testWidgets('leaving saves the game and the hub continues it, undo too', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final stores = await pumpGame(tester, deal, clock: () => now);
    final drawn = deal.stock.last.id;
    now = now.add(const Duration(seconds: 20));
    await tapStock(tester);
    expect(at(tester, drawn), at(tester, 'waste'));

    await leaveGame(tester);

    expect(stores.stats.records, isEmpty);
    expect(await storedRecords(), isEmpty);
    expect(textOf('resume-klondike'), 'Continue · 1 move · 0:20');
    expect(textOf('summary-klondike'), 'Not played yet · Tap to play');

    await openFromHub(tester);
    expect(textOf('moves-value'), '1');
    expect(textOf('time-value'), '0:20');
    expect(at(tester, drawn), at(tester, 'waste'));
    expect(isFaceUp(tester, drawn), isTrue);
    expectTableauTops(tester, deal);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(at(tester, drawn), at(tester, 'stock'));
    expect(isFaceUp(tester, drawn), isFalse);
    expect(canUndo(tester), isFalse);
    expect(stores.stats.records, isEmpty);
  });

  testWidgets('leaving without a move keeps the deal, not shown on the hub', (
    tester,
  ) async {
    final stores = await pumpGame(tester, deal);

    await leaveGame(tester);

    expect(stores.stats.records, isEmpty);
    expect(byKey('resume-klondike'), findsNothing);

    await openFromHub(tester);
    expect(textOf('moves-value'), '0');
    expectTableauTops(tester, deal);
  });

  testWidgets('a link to a deal records the saved game as abandoned', (
    tester,
  ) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(stores: stores, initialLocation: '/klondike?seed=42'),
    );
    await tester.pumpAndSettle();
    await tapStock(tester);
    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);

    GoRouter.of(tester.element(find.byType(HubScreen))).go('/klondike?seed=7');
    await tester.pumpAndSettle();

    expect(textOf('moves-value'), '0');
    expectTableauTops(tester, KlondikeState.deal(Random(7)));
    final record = stores.stats.records.single;
    expect(
      (record.seed, record.outcome, record.moves),
      (42, GameOutcome.abandoned, 1),
    );
    expect(stores.saves[KlondikeController.gameId]!.moves, 0);
  });

  testWidgets('the stats page keeps the game running behind it', (
    tester,
  ) async {
    final stores = await pumpGame(tester, stockBoard);
    await tapStock(tester);

    await tester.tap(byKey('open-stats'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsNothing);
    expect(textOf('moves-value'), '1');
    expect(at(tester, 'spades-2'), at(tester, 'waste'));
    expect(stores.stats.records, isEmpty);
  });

  testWidgets('a second finger cannot change the board during a drag', (
    tester,
  ) async {
    await pumpGame(
      tester,
      board(
        stock: [card('7D', up: false)],
        waste: [card('7H')],
        tableau: [
          [card('8S')],
        ],
      ),
    );
    final gesture = await tester.startGesture(
      at(tester, 'hearts-7') + const Offset(10, 6),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();

    // Without the guard, this draw puts the 7♦ on the waste and the drop
    // moves the 7♦ instead of the held 7♥.
    await tester.tapAt(tester.getCenter(byKey('stock')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(byKey('tableau-0')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(at(tester, 'hearts-7').dx, at(tester, 'tableau-0').dx);
    expect(at(tester, 'diamonds-7'), at(tester, 'stock'));
    expect(textOf('moves-value'), '1');
  });

  testWidgets(
    'play time stops under the stats page, also after a browser back',
    (tester) async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final stores = await pumpGame(tester, stockBoard, clock: () => now);
      now = now.add(const Duration(seconds: 10));
      await tapStock(tester);

      await tester.tap(byKey('open-stats'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(minutes: 5));

      // A browser back sets the route path: the stats page is not popped.
      GoRouter.of(tester.element(find.byType(StatsScreen))).go('/klondike');
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsNothing);
      now = now.add(const Duration(seconds: 20));

      await leaveGame(tester);
      expect(
        stores.saves[KlondikeController.gameId]!.playTime,
        const Duration(seconds: 30),
      );
    },
  );

  testWidgets('new game asks first; cancel keeps the game', (tester) async {
    final stores = await pumpGame(tester, stockBoard);
    await tapStock(tester);

    await chooseNewGame(tester, draw: 3);
    expect(find.text(confirmTitle), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text(confirmTitle), findsNothing);
    expect(textOf('moves-value'), '1');
    expect(textOf('draw-value'), 'Draw 1');
    expect(at(tester, 'spades-2'), at(tester, 'waste'));
    expect(stores.stats.records, isEmpty);
  });

  testWidgets('new game without a move deals again without asking', (
    tester,
  ) async {
    final stores = await pumpGame(tester, stockBoard);

    await chooseNewGame(tester, draw: 3);

    expect(find.text(confirmTitle), findsNothing);
    expect(textOf('draw-value'), 'Draw 3');
    expect(faceUpCount(tester), 7);
    expect(stores.stats.records, isEmpty);
  });

  testWidgets('new game in Draw 3 deals again and records the old game', (
    tester,
  ) async {
    final stores = await pumpGame(tester, stockBoard);
    expect(textOf('draw-value'), 'Draw 1');
    await tapStock(tester);

    await chooseNewGame(tester, draw: 3);
    await tester.tap(byKey('confirm-new-game'));
    await tester.pumpAndSettle();

    expect(textOf('draw-value'), 'Draw 3');
    expect(textOf('moves-value'), '0');
    final record = stores.stats.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.variant, 'draw1');
    expect(stores.saves[KlondikeController.gameId]!.moves, 0);

    // A new deal shows the 7 tableau tops; a draw then turns 3 cards.
    expect(faceUpCount(tester), 7);
    await tapStock(tester);
    expect(faceUpCount(tester), 10);
  });
}
