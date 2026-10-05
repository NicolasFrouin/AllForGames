import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/games/freecell/freecell_controller.dart';
import 'package:all_for_games/games/freecell/freecell_deal_picker.dart';
import 'package:all_for_games/games/freecell/freecell_deals.dart';
import 'package:all_for_games/games/freecell/freecell_difficulty.dart';
import 'package:all_for_games/games/freecell/freecell_screen.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/freecell/freecell_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// The seed 42 deal: a full board, so a save of it can continue.
final deal = FreeCellState.deal(42);

/// Every cascade goes down: the game can finish itself.
final finishBoard = fullBoard(cascades: ['KS QH', 'KH QS', 'KC QD', 'KD QC']);

/// Opens [state] in the app routes, with the hub below the game. Opening the
/// game again from the hub continues the saved game.
Future<AppStores> pumpGame(
  WidgetTester tester,
  FreeCellState state, {
  DateTime Function()? clock,
  Map<String, Object> data = const {},
}) async {
  useSurface(tester);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/freecell',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'freecell',
            builder: (context, route) => FreeCellScreen(
              stores: stores,
              initialState: route.extra as FreeCellState?,
              clock: clock,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(FreeCellController.gameId)!,
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

bool canUndo(WidgetTester tester) =>
    tester.widget<IconButton>(byKey('undo')).onPressed != null;

Future<void> tapCard(WidgetTester tester, String cardId) async {
  // The cards above it leave only the top strip of the card visible.
  await tester.tapAt(at(tester, cardId) + const Offset(10, 6));
  await tester.pumpAndSettle();
}

/// Drags [cardId] (and the cards on it) onto the pile slot [pileKey].
Future<void> dragCard(
  WidgetTester tester,
  String cardId,
  String pileKey,
) async {
  final gesture = await tester.startGesture(
    at(tester, cardId) + const Offset(10, 6),
  );
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(byKey(pileKey)));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> leaveGame(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(FreeCellScreen), findsNothing);
  expect(find.byType(HubScreen), findsOneWidget);
}

Future<void> openFromHub(WidgetTester tester) async {
  await tester.tap(byKey('game-freecell'));
  await tester.pumpAndSettle();
  expect(find.byType(FreeCellScreen), findsOneWidget);
}

/// Checks that every card of [state] is in its cascade.
void expectCascades(WidgetTester tester, FreeCellState state) {
  for (var i = 0; i < 8; i++) {
    for (final card in state.cascades[i]) {
      expect(at(tester, card.id).dx, at(tester, 'cascade-$i').dx);
    }
  }
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
    stores.saves[FreeCellController.gameId]!.data['seed']! as int;

void main() {
  testWidgets('deals the 52 cards face up into 8 cascades', (tester) async {
    await pumpGame(tester, deal);

    expect(find.byType(CardView), findsNWidgets(52));
    expectCascades(tester, deal);
    for (var i = 0; i < 4; i++) {
      expect(byKey('freecell-$i'), findsOneWidget);
      expect(byKey('foundation-$i'), findsOneWidget);
    }
    expect(textOf('moves-value'), '0');
    expect(canUndo(tester), isFalse);
  });

  testWidgets('a tapped ace goes home, and the safe cards follow it', (
    tester,
  ) async {
    await pumpGame(tester, board(cascades: ['KD 2S', 'AS', '9H']));

    await tapCard(tester, 'spades-1');

    expect(at(tester, 'spades-1'), at(tester, 'foundation-3'));
    expect(at(tester, 'spades-2'), at(tester, 'foundation-3'));
    expect(textOf('moves-value'), '1');
    expect(textOf('score-value'), '20');
    expect(canUndo(tester), isTrue);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(at(tester, 'spades-1'), at(tester, 'cascade-1'));
    expect(at(tester, 'spades-2').dx, at(tester, 'cascade-0').dx);
    expect(textOf('moves-value'), '1');
    expect(textOf('score-value'), '0');
  });

  group('automatic moves', () {
    /// The places of [ids] at each frame, until the cards stop.
    Future<List<Map<String, Offset>>> framesOf(
      WidgetTester tester,
      List<String> ids,
    ) async {
      final frames = <Map<String, Offset>>[];
      for (var i = 0; i < 150 && tester.binding.hasScheduledFrame; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        frames.add({for (final id in ids) id: at(tester, id)});
      }
      await tester.pumpAndSettle();
      return frames;
    }

    testWidgets('start once the move landed', (tester) async {
      await pumpGame(tester, board(cascades: ['AH 5C', '6D']));
      final ace = at(tester, 'hearts-1');

      await tester.tapAt(at(tester, 'clubs-5') + const Offset(10, 6));
      final frames = await framesOf(tester, ['clubs-5', 'hearts-1']);

      expect(at(tester, 'hearts-1'), at(tester, 'foundation-2'));
      final leaves = frames.indexWhere((frame) => frame['hearts-1'] != ace);
      expect(leaves, greaterThan(0));
      expect(frames[leaves]['clubs-5'], at(tester, 'clubs-5'));
    });

    testWidgets('a moved card that goes home first lands where the player '
        'put it', (tester) async {
      // The 2♠ goes to a free cell, which frees the A♠: both go home.
      await pumpGame(tester, board(cascades: ['AS 2S', '9H']));
      final ace = at(tester, 'spades-1');

      await tester.tapAt(at(tester, 'spades-2') + const Offset(10, 6));
      final frames = await framesOf(tester, ['spades-1', 'spades-2']);

      expect(at(tester, 'spades-1'), at(tester, 'foundation-3'));
      expect(at(tester, 'spades-2'), at(tester, 'foundation-3'));
      final leaves = frames.indexWhere((frame) => frame['spades-1'] != ace);
      expect(leaves, greaterThan(0));
      expect(frames[leaves]['spades-2'], at(tester, 'freecell-0'));
    });
  });

  testWidgets('a tapped card goes onto a cascade, else into a free cell', (
    tester,
  ) async {
    await pumpGame(tester, board(cascades: ['KD 9H', '10S', '5C']));

    await tapCard(tester, 'hearts-9');
    expect(at(tester, 'hearts-9').dx, at(tester, 'cascade-1').dx);
    expect(at(tester, 'hearts-9').dy, greaterThan(at(tester, 'spades-10').dy));

    await tapCard(tester, 'clubs-5');
    expect(at(tester, 'clubs-5'), at(tester, 'freecell-0'));
    expect(textOf('moves-value'), '2');
  });

  testWidgets('a tap with no move shakes the cards and changes nothing', (
    tester,
  ) async {
    await pumpGame(
      tester,
      board(
        cells: ['KD', 'KH', 'KC', 'QD'],
        cascades: ['5S 9H 8C', 'JS', 'QS', 'JC', 'JH', 'JD', '10D', '10H'],
      ),
    );
    final nine = at(tester, 'hearts-9');

    await tester.tapAt(nine + const Offset(10, 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(at(tester, 'hearts-9'), isNot(nine), reason: 'shaking');
    await tester.pumpAndSettle();

    expect(at(tester, 'hearts-9'), nine);
    expect(textOf('moves-value'), '0');
    expect(canUndo(tester), isFalse);
  });

  group('dragging', () {
    final dragBoard = board(cascades: ['3D 9H 8C', '10S', '10H', 'KS']);

    testWidgets('a run onto a legal cascade moves it', (tester) async {
      await pumpGame(tester, dragBoard);

      await dragCard(tester, 'hearts-9', 'cascade-1');

      final x = at(tester, 'cascade-1').dx;
      expect(at(tester, 'hearts-9').dx, x);
      expect(at(tester, 'clubs-8').dx, x);
      expect(at(tester, 'clubs-8').dy, greaterThan(at(tester, 'hearts-9').dy));
      expect(textOf('moves-value'), '1');
    });

    testWidgets('a card into a free cell', (tester) async {
      await pumpGame(tester, dragBoard);

      await dragCard(tester, 'clubs-8', 'freecell-2');

      expect(at(tester, 'clubs-8'), at(tester, 'freecell-2'));
      expect(textOf('moves-value'), '1');
    });

    testWidgets('a wrong drop flies back to its cascade', (tester) async {
      await pumpGame(tester, dragBoard);
      final nine = at(tester, 'hearts-9');
      final gesture = await tester.startGesture(nine + const Offset(10, 6));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      // A red 9 cannot go on a red 10.
      await gesture.moveTo(tester.getCenter(byKey('cascade-2')));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 60));

      expect(at(tester, 'hearts-9'), isNot(nine), reason: 'on its way back');
      await tester.pumpAndSettle();
      expect(at(tester, 'hearts-9'), nine);
      expect(textOf('moves-value'), '0');
    });

    testWidgets('a run longer than the free cells allow stays', (tester) async {
      await pumpGame(
        tester,
        board(
          cells: ['KD', 'KH', 'KC', 'QD'],
          cascades: ['3D 9H 8C', '10S', 'JS', 'QS', 'JC', 'JH', 'JD', '10D'],
        ),
      );
      final nine = at(tester, 'hearts-9');

      await dragCard(tester, 'hearts-9', 'cascade-1');

      expect(at(tester, 'hearts-9'), nine);
      expect(textOf('moves-value'), '0');
    });
  });

  group('finish', () {
    Future<AppStores> finish(WidgetTester tester) async {
      final stores = await pumpGame(tester, finishBoard);
      await tester.tap(byKey('auto-complete'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsOneWidget);
      return stores;
    }

    testWidgets('wins the game, then play again deals a new one', (
      tester,
    ) async {
      final stores = await finish(tester);
      for (final (i, suit) in [
        'clubs',
        'diamonds',
        'hearts',
        'spades',
      ].indexed) {
        expect(at(tester, '$suit-13'), at(tester, 'foundation-$i'));
      }
      final record = stores.stats.records.single;
      expect(record.outcome, GameOutcome.won);
      expect(record.moves, 1);
      expect(record.details[FreeCellStatKeys.autoFinished], 1);
      expect(find.text('Most free cells used at once'), findsOneWidget);

      await tester.tap(byKey('play-again'));
      await tester.pumpAndSettle();
      expect(find.text('You won!'), findsNothing);
      expect(textOf('moves-value'), '0');
      expect(textOf('difficulty-value'), 'Medium');
      expect(byKey('auto-complete'), findsNothing);
      expect(freecellDeals['medium'], contains(savedSeed(stores)));
    });

    testWidgets('the dialog waits for the celebration', (tester) async {
      await pumpGame(tester, finishBoard);
      await tester.tap(byKey('auto-complete'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(at(tester, 'spades-13'), isNot(at(tester, 'foundation-3')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(at(tester, 'spades-13'), at(tester, 'foundation-3'));
      expect(find.text('You won!'), findsNothing, reason: 'kings still hop');

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
      await pumpGame(tester, finishBoard);
      await tester.tap(byKey('auto-complete'));
      await tester.pump();
      expect(at(tester, 'spades-13'), at(tester, 'foundation-3'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('You won!'), findsOneWidget);
    });

    testWidgets('a win removes the saved game: the next visit deals anew', (
      tester,
    ) async {
      final stores = await finish(tester);
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(stores.saves[FreeCellController.gameId], isNull);
      expect(await storedSave(FreeCellController.gameId), isNull);
      expect(textOf('summary-freecell'), startsWith('1 played · 100% won'));

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
    final top = deal.cascades[0].last.id;
    now = now.add(const Duration(seconds: 20));
    final dealt = at(tester, top);
    await tapCard(tester, top);
    final moved = at(tester, top);
    expect(moved, isNot(dealt));

    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);
    expect(textOf('resume-freecell'), 'Continue · 1 move · 0:20');

    await openFromHub(tester);
    expect(textOf('moves-value'), '1');
    expect(textOf('time-value'), '0:20');
    expect(at(tester, top), moved);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expectCascades(tester, deal);
    expect(canUndo(tester), isFalse);
  });

  testWidgets('a link to a deal records the saved game as abandoned', (
    tester,
  ) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(stores: stores, initialLocation: '/freecell?seed=42'),
    );
    await tester.pumpAndSettle();
    await tapCard(tester, deal.cascades[3].last.id);
    await leaveGame(tester);
    expect(stores.stats.records, isEmpty);

    GoRouter.of(tester.element(find.byType(HubScreen)))
        .go('/freecell?difficulty=hard&seed=7');
    await tester.pumpAndSettle();

    expect(textOf('moves-value'), '0');
    expectCascades(tester, FreeCellState.deal(7));
    final record = stores.stats.records.single;
    expect(
      (record.seed, record.outcome, record.moves, record.variant),
      (42, GameOutcome.abandoned, 1, FreeCellController.variant),
    );
  });

  testWidgets('a link to a level deals a seed of its list', (tester) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(
        stores: stores,
        initialLocation: '/freecell?difficulty=hard',
      ),
    );
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), 'Hard');
    await leaveGame(tester);
    expect(freecellDeals['hard'], contains(savedSeed(stores)));
  });

  testWidgets('a link to an unlisted seed shows no difficulty', (tester) async {
    final seed = Iterable.generate(
      5000,
      (i) => i + 1,
    ).firstWhere((seed) => freeCellDifficultyOfSeed(seed) == null);
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(stores: stores, initialLocation: '/freecell?seed=$seed'),
    );
    await tester.pumpAndSettle();
    expect(byKey('difficulty-value'), findsNothing);
  });

  testWidgets('the new game sheet says the game counts as abandoned; cancel '
      'keeps the game', (tester) async {
    final stores = await pumpGame(tester, deal);
    await tapCard(tester, deal.cascades[0].last.id);

    await openNewGameSheet(tester);
    expect(byKey('new-game-abandons'), findsOneWidget);
    await tester.tap(byKey('new-game-difficulty-hard'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(textOf('moves-value'), '1');
    expect(stores.stats.records, isEmpty);
    expect(stores.settings.freecellDifficulty, FreeCellDifficulty.medium);
  });

  testWidgets('Deal in Hard deals a Hard deal, records the old game and '
      'keeps the choice', (tester) async {
    final stores = await pumpGame(tester, deal);
    await tapCard(tester, deal.cascades[0].last.id);

    await openNewGameSheet(tester);
    expect(isChosen(tester, 'new-game-difficulty-medium'), isTrue);
    expect(
      textOf('new-game-hint'),
      'Needs some planning: two free cells could do.',
    );
    await tester.tap(byKey('new-game-difficulty-hard'));
    await tester.pumpAndSettle();
    expect(
      textOf('new-game-hint'),
      'Needs careful planning and most of the free cells.',
    );
    await tester.tap(byKey('new-game-deal'));
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), 'Hard');
    expect(textOf('moves-value'), '0');
    expect(freecellDeals['hard'], contains(savedSeed(stores)));
    expect(stores.stats.records.single.outcome, GameOutcome.abandoned);
    expect(
      (await SettingsStore.load()).freecellDifficulty,
      FreeCellDifficulty.hard,
    );

    await openNewGameSheet(tester);
    expect(isChosen(tester, 'new-game-difficulty-hard'), isTrue);
  });

  testWidgets('a game opened from the hub has the difficulty of the '
      'settings', (tester) async {
    useSurface(tester);
    final stores = await createTestStores({
      SettingsStore.freecellDifficultyKey: 'easy',
    });
    await tester.pumpWidget(AllForGamesApp(stores: stores));
    await tester.pumpAndSettle();
    await openFromHub(tester);

    expect(textOf('difficulty-value'), 'Easy');
    await leaveGame(tester);
    expect(freecellDeals['easy'], contains(savedSeed(stores)));
  });
}
