import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/spider/spider_controller.dart';
import 'package:all_for_games/games/spider/spider_deals.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_screen.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/spider/spider_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Every column holds a card, so the stock can deal: a 9 of hearts on top
/// of the first column, 10s on the others.
final stockBoard = board(
  columns: [
    [card('3C', up: false), card('9H')],
    for (var i = 1; i < 10; i++) [card('10S', deck: i)],
  ],
  stock: [for (var i = 0; i < 10; i++) card('2D', up: false, deck: i)],
  difficulty: SpiderDifficulty.hard,
);

/// A run of spades from the king to the 2 on a face-down card, its ace on
/// another column, and a 4 of hearts that fits only on a 5.
final runBoard = board(
  columns: [
    [card('5D', up: false), ...run(Suit.spades, 13, 2)],
    [card('7C'), card('AS', deck: 1)],
    [card('5H'), card('4H')],
    [card('5S', deck: 1)],
  ],
);

/// The seed 42 deal: a full board, so a save of it can continue.
final deal = SpiderState.deal(42, SpiderDifficulty.medium);

/// Opens [state] in the app routes, with the hub below the game. Opening the
/// game again from the hub continues the saved game.
Future<AppStores> pumpGame(
  WidgetTester tester,
  SpiderState state, {
  DateTime Function()? clock,
  Map<String, Object> data = const {},
}) async {
  useSurface(tester);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/spider',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'spider',
            builder: (context, route) => SpiderScreen(
              stores: stores,
              initialState: route.extra as SpiderState?,
              clock: clock,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(SpiderController.gameId)!,
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
  // The stock cards cover the stock slot and deal when tapped.
  await tester.tapAt(tester.getCenter(byKey('stock')));
  await tester.pumpAndSettle();
}

/// Drags [cardId] (and the cards on it) onto the column [column].
Future<void> dragCard(
  WidgetTester tester,
  String cardId,
  int column, {
  bool settle = true,
}) async {
  // The cards above it leave only the top strip of the card visible.
  final gesture = await tester.startGesture(
    at(tester, cardId) + const Offset(10, 6),
  );
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(byKey('column-$column')));
  await tester.pump();
  await gesture.up();
  if (settle) await tester.pumpAndSettle();
}

Future<void> leaveGame(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(SpiderScreen), findsNothing);
  expect(find.byType(HubScreen), findsOneWidget);
}

Future<void> openFromHub(WidgetTester tester) async {
  await tester.tap(byKey('game-spider'));
  await tester.pumpAndSettle();
  expect(find.byType(SpiderScreen), findsOneWidget);
}

/// Deals a new game from the new game sheet, at [difficulty].
Future<void> chooseNewGame(
  WidgetTester tester, {
  SpiderDifficulty? difficulty,
}) async {
  await tester.tap(byKey('new-game'));
  await tester.pumpAndSettle();
  if (difficulty != null) {
    await tester.tap(byKey('new-game-difficulty-${difficulty.name}'));
    await tester.pumpAndSettle();
  }
  await tester.tap(byKey('new-game-deal'));
  await tester.pumpAndSettle();
  expect(byKey('new-game-deal'), findsNothing);
}

int savedSeed(AppStores stores) =>
    stores.saves[SpiderController.gameId]!.data['seed']! as int;

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets('a deal shows the tops face up, the stock and its deals', (
    tester,
  ) async {
    await pumpGame(tester, deal);

    expect(faceUpCount(tester), 10);
    expect(textOf('deals-left'), '5');
    expect(textOf('moves-value'), '0');
    expect(textOf('score-value'), '500');
    expect(textOf('difficulty-value'), '2 suits');
    for (var i = 0; i < 10; i++) {
      final top = deal.columns[i].last.id;
      expect(at(tester, top).dx, at(tester, 'column-$i').dx, reason: top);
    }
  });

  testWidgets('tapping the stock deals a card on each column; undo takes '
      'them back', (tester) async {
    await pumpGame(tester, stockBoard);
    expect(canUndo(tester), isFalse);

    await tapStock(tester);
    expect(textOf('moves-value'), '1');
    expect(textOf('score-value'), '499');
    expect(byKey('deals-left'), findsNothing, reason: 'the stock is empty');
    for (var i = 0; i < 10; i++) {
      final dealt = card('2D', deck: 9 - i).id;
      expect(at(tester, dealt).dx, at(tester, 'column-$i').dx, reason: dealt);
      expect(isFaceUp(tester, dealt), isTrue);
    }

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(textOf('deals-left'), '1');
    expect(at(tester, 'diamonds-2-9'), isNot(at(tester, 'column-0')));
    expect(isFaceUp(tester, 'diamonds-2-9'), isFalse);
    expect(textOf('score-value'), '498');
  });

  testWidgets('the stock does not deal while a column is empty', (
    tester,
  ) async {
    final empty = board(
      columns: stockBoard.columns.sublist(0, 9),
      stock: stockBoard.stock,
    );
    await pumpGame(tester, empty);

    await tester.tapAt(tester.getCenter(byKey('stock')));
    await tester.pump();
    expect(
      find.text('Every column needs a card before a deal.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(textOf('moves-value'), '0');
    expect(textOf('deals-left'), '1');
  });

  testWidgets('a tap moves a run to the best column, or shakes it', (
    tester,
  ) async {
    await pumpGame(tester, runBoard);

    // The 4 of hearts fits on the 5 of spades only.
    await tester.tap(byKey('hearts-4'));
    await tester.pumpAndSettle();
    expect(at(tester, 'hearts-4').dx, at(tester, 'column-3').dx);
    expect(textOf('moves-value'), '1');

    // The 5 of hearts, alone in its column, has nowhere to go.
    await tester.tap(byKey('hearts-5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(at(tester, 'hearts-5').dx, isNot(at(tester, 'column-2').dx));
    await tester.pumpAndSettle();
    expect(at(tester, 'hearts-5').dx, at(tester, 'column-2').dx);
    expect(textOf('moves-value'), '1');
  });

  testWidgets('a completed run lands on its column, then flies to the '
      'foundations one card after the other', (tester) async {
    final stores = await pumpGame(tester, runBoard);
    final ace = card('AS', deck: 1).id;
    final two = at(tester, 'spades-2');

    await dragCard(tester, ace, 0, settle: false);
    // The drop glides onto the 2 first, then the ace leaves first.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(at(tester, ace).dx, two.dx);
    expect(at(tester, ace).dy, greaterThan(two.dy));
    expect(at(tester, 'spades-13'), isNot(at(tester, 'foundation-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(at(tester, ace), at(tester, 'foundation-0'));
    expect(at(tester, 'spades-13').dx, two.dx, reason: 'the king leaves last');
    await tester.pumpAndSettle();

    expect(at(tester, 'spades-13'), at(tester, 'foundation-0'));
    expect(at(tester, ace), at(tester, 'foundation-0'));
    expect(isFaceUp(tester, 'diamonds-5'), isTrue);
    expect(textOf('score-value'), '599');
    expect(stores.stats.records, isEmpty);
  });

  testWidgets('a drop where the run cannot go flies back', (tester) async {
    await pumpGame(tester, runBoard);
    final four = at(tester, 'hearts-4');

    await dragCard(tester, 'hearts-4', 1);

    expect(at(tester, 'hearts-4'), four);
    expect(textOf('moves-value'), '0');
    expect(canUndo(tester), isFalse);
  });

  group('win', () {
    Future<AppStores> win(WidgetTester tester) async {
      final stores = await pumpGame(tester, nearWon());
      await tester.tap(byKey('spades-1-7'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
      return stores;
    }

    testWidgets('the last run wins; play again deals the same level', (
      tester,
    ) async {
      final stores = await win(tester);
      for (var i = 0; i < 8; i++) {
        expect(byKey('foundation-$i'), findsOneWidget);
      }
      expect(at(tester, 'spades-13-7'), at(tester, 'foundation-7'));
      final record = stores.stats.records.single;
      expect(
        (record.outcome, record.variant, record.moves, record.score),
        (GameOutcome.won, 'suits1', 1, 1299),
      );
      expect(stores.saves[SpiderController.gameId], isNull);

      await tester.tap(byKey('play-again'));
      await tester.pumpAndSettle();
      expect(textOf('difficulty-value'), '1 suit');
      expect(textOf('moves-value'), '0');
      expect(spiderDeals['easy'], contains(savedSeed(stores)));
      expect(faceUpCount(tester), 10);
    });

    testWidgets('the dialog waits for the run and the celebration', (
      tester,
    ) async {
      await pumpGame(tester, nearWon());
      await tester.tap(byKey('spades-1-7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(at(tester, 'spades-13-7'), isNot(at(tester, 'foundation-7')));
      // The king leaves last, after the twelve other cards.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(at(tester, 'spades-13-7'), at(tester, 'foundation-7'));
      expect(find.text('You won!'), findsNothing, reason: 'kings still hop');

      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('with reduced motion, the dialog comes at once', (
      tester,
    ) async {
      useReducedMotion(tester);
      await pumpGame(tester, nearWon());
      await tester.tap(byKey('spades-1-7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('You won!'), findsOneWidget);
    });
  });

  testWidgets('leaving saves the game and the hub continues it, undo too', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final stores = await pumpGame(tester, deal, clock: () => now);
    now = now.add(const Duration(seconds: 20));
    await tapStock(tester);
    final dealt = deal.stock.last.id;
    expect(at(tester, dealt).dx, at(tester, 'column-0').dx);

    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);
    expect(textOf('resume-spider'), 'Continue · 1 move · 0:20');

    await openFromHub(tester);
    expect(textOf('moves-value'), '1');
    expect(textOf('deals-left'), '4');
    expect(at(tester, dealt).dx, at(tester, 'column-0').dx);
    expect(isFaceUp(tester, dealt), isTrue);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(textOf('deals-left'), '5');
    expect(isFaceUp(tester, dealt), isFalse);
    expect(canUndo(tester), isFalse);
  });

  testWidgets('the new game sheet deals a Hard game, records the old one '
      'and keeps the choice', (tester) async {
    final stores = await pumpGame(tester, deal);
    await tapStock(tester);

    await tester.tap(byKey('new-game'));
    await tester.pumpAndSettle();
    expect(byKey('new-game-abandons'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(byKey('new-game-difficulty-medium')).selected,
      isTrue,
    );
    await tester.tap(byKey('new-game-difficulty-hard'));
    await tester.pumpAndSettle();
    expect(textOf('new-game-hint'), 'All four suits: the classic challenge.');
    await tester.tap(byKey('new-game-deal'));
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), '4 suits');
    expect(textOf('moves-value'), '0');
    expect(spiderDeals['hard'], contains(savedSeed(stores)));
    final record = stores.stats.records.single;
    expect(
      (record.outcome, record.variant, record.moves),
      (GameOutcome.abandoned, 'suits2', 1),
    );
    expect(
      (await SettingsStore.load()).spiderDifficulty,
      SpiderDifficulty.hard,
    );
  });

  testWidgets('a game from the hub has the difficulty of the settings; a '
      'link deals its seed and level', (tester) async {
    useSurface(tester);
    final stores = await createTestStores({
      SettingsStore.spiderDifficultyKey: 'easy',
    });
    await tester.pumpWidget(AllForGamesApp(stores: stores));
    await tester.pumpAndSettle();
    await openFromHub(tester);
    expect(textOf('difficulty-value'), '1 suit');
    await tapStock(tester);
    expect(spiderDeals['easy'], contains(savedSeed(stores)));
    await leaveGame(tester);

    GoRouter.of(tester.element(find.byType(HubScreen)))
        .go('/spider?difficulty=hard&seed=42');
    await tester.pumpAndSettle();
    expect(textOf('difficulty-value'), '4 suits');
    expect(textOf('moves-value'), '0');
    expect(savedSeed(stores), 42);
    final top = SpiderState.deal(42, SpiderDifficulty.hard).columns[0].last;
    expect(at(tester, top.id).dx, at(tester, 'column-0').dx);
    expect(stores.stats.records.single.outcome, GameOutcome.abandoned);
  });
}
