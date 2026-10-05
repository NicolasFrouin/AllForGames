import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_moving_tile.dart';
import 'package:all_for_games/games/mahjong/mahjong_screen.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tile_view.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/mahjong/mahjong_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// 1 2 2 1 in a row: the 1s first, then the 2s.
final rowBoard = board(row(4), [dots1, dots2, dots2, dots1]);

/// Two stacks: a 1 on a 2, and a 2 on a 1. No free tiles match.
final stuckBoard = board(
  layoutOf([(0, 0, 0), (0, 0, 1), (4, 0, 0), (4, 0, 1)]),
  [dots2, dots1, dots1, dots2],
);

/// Opens [state] in the app routes, with the hub below the game, or a new
/// deal from the settings without [state]. Opening the game again from the
/// hub continues the saved game.
Future<AppStores> pumpGame(
  WidgetTester tester, {
  MahjongState? state,
  Map<String, Object> data = const {},
  Size size = const Size(1280, 900),
}) async {
  useSurface(tester, size);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/mahjong',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'mahjong',
            builder: (context, route) => MahjongScreen(
              stores: stores,
              initialState: route.extra as MahjongState?,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(MahjongController.gameId)!,
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

Finder tile(int id) => byKey('tile-$id');

Future<void> tapTile(WidgetTester tester, int id) async {
  await tester.tap(tile(id));
  await tester.pumpAndSettle();
}

MahjongTileView viewOf(WidgetTester tester, int id) => tester.widget(
  find.descendant(of: tile(id), matching: find.byType(MahjongTileView)),
);

/// How the board paints a tile now: its hint glow and its opacity.
RenderMovingTile paintedTile(WidgetTester tester, int id) =>
    tester.renderObject(
      find.ancestor(of: tile(id), matching: find.byType(MovingTile)),
    );

bool isEnabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> leaveGame(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(MahjongScreen), findsNothing);
}

Future<void> openFromHub(WidgetTester tester) async {
  await tester.tap(byKey('game-mahjong'));
  await tester.pumpAndSettle();
  expect(find.byType(MahjongScreen), findsOneWidget);
}

/// The saved game's data.
Map<String, Object?> savedData(AppStores stores) =>
    stores.saves[MahjongController.gameId]!.data;

void main() {
  testWidgets('tapping two free tiles that match removes them', (tester) async {
    await pumpGame(tester, state: rowBoard);
    expect(textOf('tiles-value'), '4');
    expect(textOf('pairs-value'), '1');
    expect(isEnabled(tester, 'undo'), isFalse);

    await tapTile(tester, 0);
    expect(viewOf(tester, 0).selected, isTrue);
    await tapTile(tester, 3);

    expect(tile(0), findsNothing);
    expect(tile(3), findsNothing);
    expect(textOf('tiles-value'), '2');
    expect(textOf('score-value'), '10');
    expect(isEnabled(tester, 'undo'), isTrue);
  });

  testWidgets('with reduced motion, a matched pair goes at once', (
    tester,
  ) async {
    useReducedMotion(tester);
    await pumpGame(tester, state: rowBoard);

    await tester.tap(tile(0));
    await tester.pump();
    await tester.tap(tile(3));
    await tester.pump();

    expect(tile(0), findsNothing);
    expect(tile(3), findsNothing);
  });

  testWidgets('a blocked tile shakes and stays unselected', (tester) async {
    await pumpGame(tester, state: rowBoard);
    final place = tester.getTopLeft(tile(1));

    await tester.tap(tile(1));
    // The motion starts on the next frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getTopLeft(tile(1)), isNot(place), reason: 'shaking');

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tile(1)), place);
    expect(viewOf(tester, 1).selected, isFalse);
    expect(viewOf(tester, 1).dimmed, isTrue);
  });

  testWidgets('a tile under a pair that vanishes takes taps at once', (
    tester,
  ) async {
    // A 1 on a 2, then a 1 and a 2 on the table.
    await pumpGame(
      tester,
      state: board(layoutOf([(0, 0, 0), (0, 0, 1), (4, 0, 0), (8, 0, 0)]), [
        dots2,
        dots1,
        dots1,
        dots2,
      ]),
    );
    await tapTile(tester, 1);
    await tester.tap(tile(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tile(1), findsOneWidget, reason: 'still vanishing');

    await tester.tap(tile(0));
    await tester.pump();

    expect(viewOf(tester, 0).selected, isTrue);
  });

  testWidgets('undo puts the pair back', (tester) async {
    await pumpGame(tester, state: rowBoard);
    final place = tester.getTopLeft(tile(0));
    await tapTile(tester, 0);
    await tapTile(tester, 3);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(tile(0)), place);
    expect(tile(3), findsOneWidget);
    expect(textOf('tiles-value'), '4');
    expect(textOf('score-value'), '0');
    expect(isEnabled(tester, 'undo'), isFalse);
  });

  testWidgets('a hint lights a pair that matches, then the glow settles', (
    tester,
  ) async {
    final stores = await pumpGame(tester, state: rowBoard);

    await tester.tap(byKey('hint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(paintedTile(tester, 0).glow, greaterThan(0.4), reason: 'pulsing');

    await tester.pumpAndSettle();
    for (final id in [0, 3]) {
      expect(paintedTile(tester, id).glow, closeTo(0.4, 0.01), reason: '$id');
    }
    expect(paintedTile(tester, 1).glow, 0);
    expect(savedData(stores)['counters'], {MahjongStatKeys.hints: 1});

    await tapTile(tester, 0);
    await tapTile(tester, 3);
    expect(paintedTile(tester, 1).glow, 0, reason: 'the hint is used');
  });

  testWidgets('stuck, a banner offers a shuffle that makes matches', (
    tester,
  ) async {
    final stores = await pumpGame(tester, state: stuckBoard);
    expect(byKey('stuck-banner'), findsOneWidget);
    expect(isEnabled(tester, 'hint'), isFalse);
    expect(textOf('pairs-value'), '0');

    await tester.tap(byKey('shuffle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final flying = [for (var id = 0; id < 4; id++) tester.getTopLeft(tile(id))];
    await tester.pumpAndSettle();
    final landed = [for (var id = 0; id < 4; id++) tester.getTopLeft(tile(id))];
    expect(flying, isNot(landed), reason: 'tiles fly to their new places');

    expect(byKey('stuck-banner'), findsNothing);
    expect(textOf('pairs-value'), '1');
    expect(isEnabled(tester, 'hint'), isTrue);
    expect(savedData(stores)['counters'], {MahjongStatKeys.shuffles: 1});
  });

  group('winning', () {
    Future<void> win(WidgetTester tester) async {
      await tapTile(tester, 0);
      await tapTile(tester, 3);
      await tapTile(tester, 1);
      await tester.tap(tile(2));
    }

    testWidgets('shows the result after a short celebration', (tester) async {
      final stores = await pumpGame(tester, state: rowBoard);

      await win(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(byKey('play-again'), findsNothing, reason: 'celebrating');
      await tester.pumpAndSettle();

      expect(find.text('You won!'), findsOneWidget);
      expect(stores.stats.records.single.won, isTrue);
      expect(stores.saves[MahjongController.gameId], isNull);
    });

    testWidgets('with reduced motion, the dialog comes at once', (
      tester,
    ) async {
      useReducedMotion(tester);
      await pumpGame(tester, state: rowBoard);

      await win(tester);
      await tester.pump();
      await tester.pump();

      expect(byKey('play-again'), findsOneWidget);
    });

    testWidgets('play again deals a new game of the same difficulty', (
      tester,
    ) async {
      await pumpGame(tester, state: rowBoard);
      await win(tester);
      await tester.pumpAndSettle();

      await tester.tap(byKey('play-again'));
      await tester.pumpAndSettle();

      expect(textOf('tiles-value'), '144');
      expect(textOf('difficulty-value'), 'Medium');
    });

    testWidgets('back to games shows the win on the hub', (tester) async {
      await pumpGame(tester, state: rowBoard);
      await win(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(find.byType(HubScreen), findsOneWidget);
      expect(textOf('summary-mahjong'), startsWith('1 played · 100% won'));
    });
  });

  testWidgets('a new deal drops in, layer by layer, then rests', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(byKey('new-game'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('new-game-deal'));
    await tester.pump(const Duration(milliseconds: 100));

    // The top tile of the Turtle waits for the layers below it, unseen.
    bool waiting() => tester
        .renderObjectList<RenderMovingTile>(find.byType(MovingTile))
        .any((tile) => tile.opacity == 0);
    expect(waiting(), isTrue);
    await tester.pumpAndSettle();
    expect(waiting(), isFalse);
  });

  testWidgets('leaving saves the game, and the hub continues it', (
    tester,
  ) async {
    final stores = await pumpGame(tester);
    expect(textOf('difficulty-value'), 'Medium');
    await tester.tap(byKey('hint'));
    await tester.pumpAndSettle();
    final hinted = stores.saves[MahjongController.gameId]!;
    final faces = hinted.data['faces'];
    final (a, b) = MahjongController.restore(
      hinted.data,
      stats: stores.stats,
      saves: stores.saves,
    ).hint()!;
    await tapTile(tester, a);
    await tapTile(tester, b);

    await leaveGame(tester);
    expect(textOf('resume-mahjong'), startsWith('Continue · 1 move'));
    await openFromHub(tester);

    expect(textOf('tiles-value'), '142');
    expect(isEnabled(tester, 'undo'), isTrue);
    expect(savedData(stores)['faces'], faces);
    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();
    expect(textOf('tiles-value'), '144');
  });

  group('new game sheet', () {
    testWidgets('says that a game with a match counts as abandoned', (
      tester,
    ) async {
      final stores = await pumpGame(tester, state: rowBoard);
      await tester.tap(byKey('new-game'));
      await tester.pumpAndSettle();
      expect(byKey('new-game-abandons'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tapTile(tester, 0);
      await tapTile(tester, 3);
      await tester.tap(byKey('new-game'));
      await tester.pumpAndSettle();
      expect(byKey('new-game-abandons'), findsOneWidget);
      await tester.tap(byKey('new-game-deal'));
      await tester.pumpAndSettle();

      final record = stores.stats.records.single;
      expect(record.outcome, GameOutcome.abandoned);
      expect(record.details[MahjongStatKeys.tilesLeft], 2);
    });

    testWidgets('deals the chosen difficulty and keeps it in the settings', (
      tester,
    ) async {
      final stores = await pumpGame(tester);
      await tester.tap(byKey('new-game'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(byKey('new-game-difficulty-medium')).selected,
        isTrue,
      );

      await tester.tap(byKey('new-game-difficulty-easy'));
      await tester.pumpAndSettle();
      expect(textOf('new-game-hint'), contains('72 tiles'));
      await tester.tap(byKey('new-game-deal'));
      await tester.pumpAndSettle();

      expect(textOf('difficulty-value'), 'Easy');
      expect(textOf('tiles-value'), '72');
      expect(stores.settings.mahjongDifficulty, MahjongDifficulty.easy);
      expect(stores.stats.records, isEmpty, reason: 'no match, no record');
    });

    testWidgets('a game opened from the hub has the settings difficulty', (
      tester,
    ) async {
      await pumpGame(
        tester,
        data: {SettingsStore.mahjongDifficultyKey: 'hard'},
      );

      expect(textOf('difficulty-value'), 'Hard');
      expect(textOf('tiles-value'), '144');
    });
  });

  group('orientation', () {
    testWidgets('a tall screen deals the layout with rows and columns '
        'swapped, and the game keeps it', (tester) async {
      final stores = await pumpGame(tester, size: const Size(360, 640));
      await leaveGame(tester);
      expect(savedData(stores)['transposed'], isTrue);

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      await openFromHub(tester);
      await leaveGame(tester);
      expect(savedData(stores)['transposed'], isTrue);
    });

    testWidgets('a wide screen deals it as it is', (tester) async {
      final stores = await pumpGame(tester);
      await leaveGame(tester);

      expect(savedData(stores)['transposed'], isFalse);
    });
  });

  testWidgets('the hub opens Mahjong, with a deal from a link too', (
    tester,
  ) async {
    useSurface(tester);
    final stores = await createTestStores();
    await tester.pumpWidget(
      AllForGamesApp(
        stores: stores,
        initialLocation: '/mahjong?seed=42&difficulty=easy',
      ),
    );
    await tester.pumpAndSettle();

    expect(textOf('difficulty-value'), 'Easy');
    expect(find.widgetWithText(AppBar, 'Mahjong'), findsOneWidget);
    await leaveGame(tester);
    expect(savedData(stores)['seed'], 42);

    await openFromHub(tester);
    expect(textOf('tiles-value'), '72');
  });
}
