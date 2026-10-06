import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_controller.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deal_picker.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deals.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_difficulty.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_screen.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/l10n/app_localizations.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/tripeaks/tripeaks_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// The seed 42 deal: a full board, so a save of it can continue. From its
/// A♣ on the waste, only the K♥ of the bottom row fits.
final deal = TriPeaksState.deal(42);

/// The 5♣ on the last peak top wins, with three cards left in the stock.
final lastCard = board(tableau: {0: '5C'}, stock: '2H 9D JS', waste: '4S');

/// Opens [state] in the app routes, with the hub below the game. Opening the
/// game again from the hub continues the saved game.
Future<AppStores> pumpGame(
  WidgetTester tester,
  TriPeaksState state, {
  DateTime Function()? clock,
  Map<String, Object> data = const {},
  Size size = const Size(1280, 900),
  Locale? locale,
}) async {
  useSurface(tester, size);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/tripeaks',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'tripeaks',
            builder: (context, route) => TriPeaksScreen(
              stores: stores,
              initialState: route.extra as TriPeaksState?,
              clock: clock,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(TriPeaksController.gameId)!,
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
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return stores;
}

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Top-left corner of a card (by card id) or of a pile slot.
Offset at(WidgetTester tester, String key) => tester.getTopLeft(byKey(key));

/// Whether the card [id] shows its face.
bool faceUp(WidgetTester tester, String id) => tester
    .widget<CardView>(
      find.descendant(of: byKey(id), matching: find.byType(CardView)),
    )
    .card
    .faceUp;

bool canUndo(WidgetTester tester) =>
    tester.widget<IconButton>(byKey('undo')).onPressed != null;

Future<void> tapCard(WidgetTester tester, String cardId) async {
  // The card on its right in the row leaves its left part visible.
  await tester.tapAt(at(tester, cardId) + const Offset(10, 6));
  await tester.pumpAndSettle();
}

Future<void> tapStock(WidgetTester tester) async {
  // The top stock card covers the slot and draws on tap too.
  await tester.tap(byKey('stock'), warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> leaveGame(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(TriPeaksScreen), findsNothing);
  expect(find.byType(HubScreen), findsOneWidget);
}

Future<void> openFromHub(WidgetTester tester) async {
  final tile = byKey('game-tripeaks');
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byType(TriPeaksScreen), findsOneWidget);
}

Future<void> openNewGameSheet(WidgetTester tester) async {
  await tester.tap(byKey('new-game'));
  await tester.pumpAndSettle();
  expect(byKey('new-game-deal'), findsOneWidget);
}

bool isChosen(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(byKey(key)).selected;

/// The seed of the saved game.
int savedSeed(AppStores stores) =>
    stores.saves[TriPeaksController.gameId]!.data['seed']! as int;

void main() {
  testWidgets('deals three peaks of 28 cards, the bottom row face up, a '
      'waste card and the stock', (tester) async {
    await pumpGame(tester, deal);

    expect(find.byType(CardView), findsNWidgets(52));
    for (final (i, card) in deal.tableau.indexed) {
      expect(faceUp(tester, card!.id), i >= 18, reason: 'place $i');
    }
    final bottom = [for (final card in deal.tableau.skip(18)) card!.id];
    for (var i = 1; i < bottom.length; i++) {
      final left = at(tester, bottom[i - 1]);
      expect(at(tester, bottom[i]).dy, left.dy);
      expect(at(tester, bottom[i]).dx, greaterThan(left.dx));
    }
    final peakTop = at(tester, deal.tableau[0]!.id);
    expect(peakTop.dy, lessThan(at(tester, bottom.first).dy));
    expect(at(tester, deal.wasteTop.id), at(tester, 'waste'));
    expect(faceUp(tester, deal.wasteTop.id), isTrue);
    expect(at(tester, deal.stock.first.id), at(tester, 'stock'));
    expect(textOf('moves-value'), '0');
    expect(textOf('stock-value'), '23');
    expect(textOf('run-value'), '0');
    expect(canUndo(tester), isFalse);
    expect(byKey('stuck-banner'), findsNothing);
  });

  testWidgets('a tapped card that fits flies onto the waste; undo puts it '
      'back', (tester) async {
    await pumpGame(tester, deal);
    final king = deal.tableau[deal.playable.single]!.id;
    final dealt = at(tester, king);

    await tapCard(tester, king);
    expect(at(tester, king), at(tester, 'waste'));
    expect(textOf('moves-value'), '1');
    expect(textOf('run-value'), '1');
    expect(textOf('score-value'), '10');
    expect(canUndo(tester), isTrue);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(at(tester, king), dealt);
    expect(at(tester, deal.wasteTop.id), at(tester, 'waste'));
    expect(textOf('moves-value'), '1');
    expect(textOf('run-value'), '0');
    expect(textOf('score-value'), '0');
  });

  testWidgets('a tapped card that does not fit shakes and changes nothing', (
    tester,
  ) async {
    await pumpGame(tester, deal);
    final misfit = deal.tableau[18]!.id;
    expect(deal.canPlay(18), isFalse);
    final place = at(tester, misfit);

    await tester.tapAt(place + const Offset(10, 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(at(tester, misfit), isNot(place), reason: 'shaking');
    await tester.pumpAndSettle();

    expect(at(tester, misfit), place);
    expect(textOf('moves-value'), '0');
    expect(canUndo(tester), isFalse);
  });

  testWidgets('the stock turns its top card onto the waste and ends the run', (
    tester,
  ) async {
    await pumpGame(tester, deal);
    await tapCard(tester, deal.tableau[deal.playable.single]!.id);
    final top = deal.stock.last.id;
    expect(faceUp(tester, top), isFalse);

    await tapStock(tester);
    expect(at(tester, top), at(tester, 'waste'));
    expect(faceUp(tester, top), isTrue);
    expect(textOf('stock-value'), '22');
    expect(textOf('moves-value'), '2');
    expect(textOf('run-value'), '0');

    await tapStock(tester);
    await tapStock(tester);
    expect(textOf('stock-value'), '20');
    expect(
      find.byType(CardView),
      findsNWidgets(51),
      reason: 'the A♣ is hidden under the top four cards of the waste',
    );
  });

  testWidgets('a card turns over once both cards below it are gone', (
    tester,
  ) async {
    await pumpGame(
      tester,
      board(tableau: {9: '9H', 18: '8C', 19: '7D'}, waste: '9S'),
    );
    expect(faceUp(tester, 'hearts-9'), isFalse);

    await tapCard(tester, 'clubs-8');
    expect(faceUp(tester, 'hearts-9'), isFalse);
    await tapCard(tester, 'diamonds-7');
    expect(faceUp(tester, 'hearts-9'), isTrue);
  });

  testWidgets('stuck: the banner offers undo and a new game', (tester) async {
    await pumpGame(
      tester,
      board(tableau: {18: '5C', 19: '9H'}, stock: 'JD', waste: '4S'),
    );
    await tapCard(tester, 'clubs-5');
    await tapStock(tester);
    expect(byKey('stuck-banner'), findsOneWidget);
    expect(find.text('No card fits and the stock is empty.'), findsOneWidget);

    await tester.tap(byKey('stuck-undo'));
    await tester.pumpAndSettle();
    expect(byKey('stuck-banner'), findsNothing);
    expect(textOf('stock-value'), '1');

    await tapStock(tester);
    await tester.tap(byKey('stuck-new-game'));
    await tester.pumpAndSettle();
    expect(byKey('new-game-abandons'), findsOneWidget);
    await tester.tap(byKey('new-game-deal'));
    await tester.pumpAndSettle();
    expect(byKey('stuck-banner'), findsNothing);
    expect(textOf('moves-value'), '0');
    expect(textOf('stock-value'), '23');
  });

  testWidgets('the stuck banner fits a small phone, in French, text x2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpGame(
      tester,
      board(tableau: {18: '5C', 19: '9H'}, stock: 'JD', waste: '4S'),
      size: const Size(360, 640),
      locale: const Locale('fr'),
    );
    await tapCard(tester, 'clubs-5');
    await tapStock(tester);

    expect(byKey('stuck-banner'), findsOneWidget);
    expect(byKey('stuck-undo'), findsOneWidget);
    expect(byKey('stuck-new-game'), findsOneWidget);
  });

  group('win', () {
    Future<AppStores> win(WidgetTester tester) async {
      final stores = await pumpGame(tester, lastCard);
      await tapCard(tester, 'clubs-5');
      expect(find.text('You won!'), findsOneWidget);
      return stores;
    }

    testWidgets('the stock cards go onto the waste as a bonus, then play '
        'again deals a new game', (tester) async {
      final stores = await win(tester);
      for (final id in ['clubs-5', 'spades-11', 'diamonds-9', 'hearts-2']) {
        expect(at(tester, id), at(tester, 'waste'));
        expect(faceUp(tester, id), isTrue);
      }
      final record = stores.stats.records.single;
      expect(record.outcome, GameOutcome.won);
      expect(record.details[TriPeaksStatKeys.stockLeft], 3);
      expect(find.text('Longest run'), findsOneWidget);
      expect(find.text('Cards left in the stock'), findsOneWidget);

      await tester.tap(byKey('play-again'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsNothing);
      expect(textOf('moves-value'), '0');
      expect(textOf('difficulty-value'), 'Medium');
      expect(find.byType(CardView), findsNWidgets(52));
      expect(triPeaksDeals['medium'], contains(savedSeed(stores)));
    });

    testWidgets('the bonus cards leave the stock one by one, and the dialog '
        'waits for the celebration', (tester) async {
      await pumpGame(tester, lastCard);
      final stock = at(tester, 'stock');
      await tester.tapAt(at(tester, 'clubs-5') + const Offset(10, 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(at(tester, 'clubs-5'), at(tester, 'waste'));
      expect(at(tester, 'hearts-2').dx, lessThan(at(tester, 'waste').dx));
      expect(at(tester, 'hearts-2').dy, stock.dy, reason: 'waits its turn');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('You won!'), findsNothing, reason: 'the top card hops');

      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('with reduced motion, cards move and the dialog comes at '
        'once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpGame(tester, lastCard);
      await tester.tapAt(at(tester, 'clubs-5') + const Offset(10, 6));
      await tester.pump();
      expect(at(tester, 'hearts-2'), at(tester, 'waste'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('a win removes the saved game: the next visit deals anew', (
      tester,
    ) async {
      final stores = await win(tester);
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(stores.saves[TriPeaksController.gameId], isNull);
      expect(await storedSave(TriPeaksController.gameId), isNull);
      expect(textOf('summary-tripeaks'), startsWith('1 played · 100% won'));

      await openFromHub(tester);
      expect(textOf('moves-value'), '0');
      expect(find.byType(CardView), findsNWidgets(52));
    });
  });

  testWidgets('leaving saves the game and the hub continues it, undo too', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final stores = await pumpGame(tester, deal, clock: () => now);
    final king = deal.tableau[deal.playable.single]!.id;
    now = now.add(const Duration(seconds: 20));
    final dealt = at(tester, king);
    await tapCard(tester, king);
    final moved = at(tester, king);
    expect(moved, isNot(dealt));

    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);
    expect(textOf('resume-tripeaks'), 'Continue · 1 move · 0:20');

    await openFromHub(tester);
    expect(textOf('moves-value'), '1');
    expect(textOf('time-value'), '0:20');
    expect(at(tester, king), moved);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(at(tester, king), dealt);
    expect(canUndo(tester), isFalse);
  });

  testWidgets('a link to a deal records the saved game as abandoned', (
    tester,
  ) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(stores: stores, initialLocation: '/tripeaks?seed=42'),
    );
    await tester.pumpAndSettle();
    await tapStock(tester);
    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);

    GoRouter.of(tester.element(find.byType(HubScreen)))
        .go('/tripeaks?difficulty=hard&seed=7');
    await tester.pumpAndSettle();

    expect(textOf('moves-value'), '0');
    final seven = TriPeaksState.deal(7);
    expect(at(tester, seven.wasteTop.id), at(tester, 'waste'));
    final record = stores.stats.records.single;
    expect(
      (record.seed, record.outcome, record.moves, record.variant),
      (42, GameOutcome.abandoned, 1, TriPeaksController.variant),
    );
  });

  testWidgets('a link to a level deals a seed of its list', (tester) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(
        stores: stores,
        initialLocation: '/tripeaks?difficulty=hard',
      ),
    );
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), 'Hard');
    await leaveGame(tester);
    expect(triPeaksDeals['hard'], contains(savedSeed(stores)));
  });

  testWidgets('a link to an unlisted seed shows no difficulty', (tester) async {
    final seed = Iterable.generate(
      5000,
      (i) => i + 1,
    ).firstWhere((seed) => triPeaksDifficultyOfSeed(seed) == null);
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(stores: stores, initialLocation: '/tripeaks?seed=$seed'),
    );
    await tester.pumpAndSettle();
    expect(byKey('difficulty-value'), findsNothing);
  });

  testWidgets('the new game sheet says the game counts as abandoned; cancel '
      'keeps the game', (tester) async {
    final stores = await pumpGame(tester, deal);
    await tapStock(tester);

    await openNewGameSheet(tester);
    expect(byKey('new-game-abandons'), findsOneWidget);
    await tester.tap(byKey('new-game-difficulty-hard'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(textOf('moves-value'), '1');
    expect(stores.stats.records, isEmpty);
    expect(stores.settings.tripeaksDifficulty, TriPeaksDifficulty.medium);
  });

  testWidgets('Deal in Hard deals a Hard deal, records the old game and '
      'keeps the choice', (tester) async {
    final stores = await pumpGame(tester, deal);
    await tapStock(tester);

    await openNewGameSheet(tester);
    expect(isChosen(tester, 'new-game-difficulty-medium'), isTrue);
    expect(
      textOf('new-game-hint'),
      'Pick the card to play with care: the order matters.',
    );
    await tester.tap(byKey('new-game-difficulty-hard'));
    await tester.pumpAndSettle();
    expect(
      textOf('new-game-hint'),
      'Few ways to win: plan your runs and when to draw.',
    );
    await tester.tap(byKey('new-game-deal'));
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), 'Hard');
    expect(textOf('moves-value'), '0');
    expect(triPeaksDeals['hard'], contains(savedSeed(stores)));
    expect(stores.stats.records.single.outcome, GameOutcome.abandoned);
    expect(
      (await SettingsStore.load()).tripeaksDifficulty,
      TriPeaksDifficulty.hard,
    );

    await openNewGameSheet(tester);
    expect(isChosen(tester, 'new-game-difficulty-hard'), isTrue);
  });

  testWidgets('a game opened from the hub has the difficulty of the '
      'settings', (tester) async {
    useSurface(tester);
    final stores = await createTestStores({
      SettingsStore.tripeaksDifficultyKey: 'easy',
    });
    await tester.pumpWidget(AllForGamesApp(stores: stores));
    await tester.pumpAndSettle();
    await openFromHub(tester);

    expect(textOf('difficulty-value'), 'Easy');
    await leaveGame(tester);
    expect(triPeaksDeals['easy'], contains(savedSeed(stores)));
  });
}
