import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_moving_tile.dart';
import 'package:all_for_games/games/mahjong/mahjong_screen.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
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

final dots4 = TileFace.of(TileSuit.dots, 4).code;

/// 1 2 2 1 in a row: a 1 waits for the other 1, then the 2s.
final rowBoard = board(row(4), [dots1, dots2, dots2, dots1]);

/// Opens a tray game of [state] in the app routes, with the hub below the
/// game, or a deal of [location]'s query without [state].
Future<AppStores> pumpTray(
  WidgetTester tester, {
  MahjongState? state,
  Map<String, Object> data = const {},
  String location = '/mahjong',
}) async {
  useSurface(tester);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: location,
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'mahjong',
            builder: (context, route) {
              final query = route.uri.queryParameters;
              final initialState = route.extra as MahjongState?;
              return MahjongScreen(
                stores: stores,
                mode: initialState != null
                    ? MahjongMode.tray
                    : MahjongMode.values.asNameMap()[query['mode']],
                difficulty: MahjongDifficulty.values
                    .asNameMap()[query['difficulty']],
                seed: int.tryParse(query['seed'] ?? ''),
                initialState: initialState,
              );
            },
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

/// Whether tile [id] rests in place [slot] of the tray.
bool inSlot(WidgetTester tester, int id, int slot) => tester
    .getRect(byKey('tray-slot-$slot'))
    .contains(tester.getCenter(tile(id)));

RenderMovingTile paintedTile(WidgetTester tester, int id) =>
    tester.renderObject(
      find.ancestor(of: tile(id), matching: find.byType(MovingTile)),
    );

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Map<String, Object?> savedData(AppStores stores) =>
    stores.saves[MahjongController.gameId]!.data;

/// Free tiles of four faces, none of a pair, of the Hard deal of [seed] on
/// a wide screen: picked, they fill the tray.
List<int> fourStrangers(int seed) {
  final state = generateTrayDeal(
    MahjongDifficulty.hard.layout(),
    seed,
    MahjongDifficulty.hard.tray,
  ).state;
  final picks = <int>[];
  for (final id in state.tileIds) {
    final face = state.faces[id];
    if (state.isFree(id) && picks.every((pick) => state.faces[pick] != face)) {
      picks.add(id);
    }
  }
  return picks.take(TrayState.capacity).toList();
}

void main() {
  testWidgets('the tray is above the tiles, or on the side of the settings', (
    tester,
  ) async {
    final stores = await pumpTray(tester, state: rowBoard);
    Rect slot(int i) => tester.getRect(byKey('tray-slot-$i'));
    expect(slot(0).bottom, lessThan(tester.getRect(tile(0)).top));

    await stores.settings.setMahjongTraySide(MahjongTraySide.left);
    await tester.pumpAndSettle();
    expect(slot(3).right, lessThan(tester.getRect(tile(0)).left));
    expect(slot(1).left, slot(0).left);
    expect(slot(1).top, greaterThan(slot(0).top));

    await tapTile(tester, 0);
    expect(inSlot(tester, 0, 0), isTrue);
  });

  testWidgets('a tapped tile flies into the first place of the tray', (
    tester,
  ) async {
    await pumpTray(tester, state: rowBoard);
    expect(textOf('mode-value'), 'Tray · Medium');
    for (var i = 0; i < TrayState.capacity; i++) {
      expect(byKey('tray-slot-$i'), findsOneWidget);
    }

    await tester.tap(tile(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(inSlot(tester, 0, 0), isFalse, reason: 'flying');
    await tester.pumpAndSettle();

    expect(inSlot(tester, 0, 0), isTrue);
    expect(textOf('tiles-value'), '4', reason: 'in the tray, not cleared');
    expect(textOf('score-value'), '0');
  });

  testWidgets('a tile of the same face clears both: they pop, and the tray '
      'closes up', (tester) async {
    await pumpTray(tester, state: rowBoard);
    await tapTile(tester, 0);
    await tapTile(tester, 1);
    expect(inSlot(tester, 1, 1), isTrue);

    await tester.tap(tile(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tile(0), findsOneWidget, reason: 'popping');
    expect(paintedTile(tester, 0).glow, greaterThan(0));
    await tester.pumpAndSettle();

    expect(tile(0), findsNothing);
    expect(tile(3), findsNothing);
    expect(inSlot(tester, 1, 0), isTrue, reason: 'slid to the first place');
    expect(textOf('tiles-value'), '2');
    expect(textOf('score-value'), '10');
  });

  testWidgets('undo flies the tile back from the tray', (tester) async {
    await pumpTray(tester, state: rowBoard);
    final place = tester.getTopLeft(tile(0));
    await tapTile(tester, 0);

    await tester.tap(byKey('undo'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(tile(0)), place);
  });

  testWidgets('a hint lights the tile to pick', (tester) async {
    final stores = await pumpTray(tester, state: rowBoard);

    await tester.tap(byKey('hint'));
    await tester.pumpAndSettle();

    final lit = [
      for (final id in [0, 3])
        if (paintedTile(tester, id).glow > 0) id,
    ];
    expect(lit, hasLength(1), reason: 'one of the two ends');
    expect(savedData(stores)['counters'], {MahjongStatKeys.hints: 1});
  });

  testWidgets('a won tray game shows the result', (tester) async {
    final stores = await pumpTray(tester, state: rowBoard);
    for (final id in [0, 3, 1]) {
      await tapTile(tester, id);
    }
    await tester.tap(tile(2));
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = stores.stats.records.single;
    expect((record.won, record.variant), (true, 'tray-test'));
  });

  group('a full tray', () {
    testWidgets('flashes, records the loss, and Try again deals the same '
        'game', (tester) async {
      final stores = await pumpTray(
        tester,
        location: '/mahjong?mode=tray&difficulty=hard&seed=6',
      );
      final faces = generateTrayDeal(
        MahjongDifficulty.hard.layout(),
        6,
        MahjongDifficulty.hard.tray,
      ).state.faces;
      final picks = fourStrangers(6);
      for (final id in picks.take(3)) {
        await tapTile(tester, id);
      }

      await tester.tap(tile(picks.last));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(byKey('tray-full'), findsNothing, reason: 'flashing first');
      await tester.pumpAndSettle();

      expect(byKey('tray-full'), findsOneWidget);
      expect(find.text('The tray is full'), findsOneWidget);
      final record = stores.stats.records.single;
      expect(record.outcome, GameOutcome.lost);
      expect(record.variant, 'tray-turtle');
      expect(stores.saves[MahjongController.gameId], isNull);

      await tester.tap(byKey('try-again'));
      await tester.pumpAndSettle();

      expect(byKey('tray-full'), findsNothing);
      expect(textOf('tiles-value'), '144');
      expect(savedData(stores)['faces'], faces);
      expect(savedData(stores)['tray'], isEmpty);
      expect(stores.stats.records, hasLength(1));
    });

    testWidgets('with reduced motion, the dialog comes at once; New game '
        'deals another game', (tester) async {
      useReducedMotion(tester);
      final stores = await pumpTray(
        tester,
        location: '/mahjong?mode=tray&difficulty=hard&seed=6',
      );
      for (final id in fourStrangers(6)) {
        await tester.tap(tile(id));
        await tester.pump();
      }
      await tester.pump();
      expect(byKey('tray-full'), findsOneWidget);

      await tester.tap(byKey('lost-new-game'));
      await tester.pumpAndSettle();

      expect(savedData(stores)['seed'], isNot(6));
      expect(savedData(stores)['mode'], 'tray');
      expect(textOf('mode-value'), 'Tray · Hard');
    });
  });

  testWidgets('when any tile would fill the tray, a banner offers undo', (
    tester,
  ) async {
    // From the top: 1 2 3, then a 4 and 3 2 1 under it.
    await pumpTray(
      tester,
      state: board(layoutOf([for (var z = 0; z < 7; z++) (0, 0, z)]), [
        dots1,
        dots2,
        dots3,
        dots4,
        dots3,
        dots2,
        dots1,
      ]),
    );
    await tapTile(tester, 6);
    await tapTile(tester, 5);
    expect(byKey('stuck-banner'), findsNothing);

    await tapTile(tester, 4);
    expect(byKey('stuck-banner'), findsOneWidget);
    expect(byKey('shuffle'), findsNothing);
    expect(tester.widget<IconButton>(byKey('hint')).onPressed, isNull);

    await tester.tap(
      find.descendant(of: byKey('stuck-banner'), matching: find.text('Undo')),
    );
    await tester.pumpAndSettle();
    expect(byKey('stuck-banner'), findsNothing);
    expect(inSlot(tester, 4, 2), isFalse);
  });

  group('mode', () {
    testWidgets('the new game sheet deals the chosen mode and keeps it', (
      tester,
    ) async {
      final stores = await pumpTray(tester, location: '/mahjong');
      expect(textOf('difficulty-value'), 'Medium');
      expect(byKey('tray-slot-0'), findsNothing);

      await tester.tap(byKey('new-game'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(byKey('new-game-mode-classic')).selected,
        isTrue,
      );
      await tester.tap(byKey('new-game-mode-tray'));
      await tester.pumpAndSettle();
      expect(textOf('new-game-mode-hint'), contains('tray of 4 places'));
      await tester.tap(byKey('new-game-deal'));
      await tester.pumpAndSettle();

      expect(textOf('mode-value'), 'Tray · Medium');
      expect(byKey('tray-slot-0'), findsOneWidget);
      expect(stores.settings.mahjongMode, MahjongMode.tray);
      expect(savedData(stores)['mode'], 'tray');
    });

    testWidgets('a game opened from the hub has the settings mode, and '
        'continues with its tray', (tester) async {
      final stores = await pumpTray(
        tester,
        data: {SettingsStore.mahjongModeKey: 'tray'},
      );
      expect(textOf('mode-value'), 'Tray · Medium');
      // The hint saves the game.
      await tester.tap(byKey('hint'));
      await tester.pumpAndSettle();
      final controller = MahjongController.restore(
        savedData(stores),
        stats: stores.stats,
        saves: stores.saves,
      );
      final pick = controller.hintPick()!;
      await tapTile(tester, pick);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(byKey('game-mahjong'));
      await tester.pumpAndSettle();

      expect(savedData(stores)['tray'], [pick]);
      expect(inSlot(tester, pick, 0), isTrue);
    });
  });

  testWidgets('the stats page filters the tray games', (tester) async {
    final stores = await pumpTray(
      tester,
      location: '/mahjong?mode=tray&difficulty=hard&seed=6',
    );
    for (final id in fourStrangers(6)) {
      await tapTile(tester, id);
    }
    await tester.tap(byKey('try-again'));
    await tester.pumpAndSettle();
    expect(stores.stats.records, hasLength(1));

    await tester.tap(byKey('open-stats'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('variant-tray-turtle'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tray · Turtle'), findsWidgets);
    expect(valueIn('stat-played'), '1');
    expect(valueIn('stat-${MahjongStatKeys.mostHeld}'), '4');
  });
}
