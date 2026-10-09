import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_board.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_controller.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_screen.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/minesweeper/minesweeper_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Opens Minesweeper in the app routes, with the hub below it: on [state],
/// or on a new game of [difficulty] and [seed] when given, or else the saved
/// game (or a new one from the settings).
Future<AppStores> pumpGame(
  WidgetTester tester, {
  MinesweeperState? state,
  MinesweeperDifficulty? difficulty,
  int? seed,
  Map<String, Object> data = const {},
  Size size = const Size(1280, 900),
}) async {
  useSurface(tester, size);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/minesweeper',
    initialExtra: state,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'minesweeper',
            builder: (context, route) => MinesweeperScreen(
              stores: stores,
              initialState: route.extra as MinesweeperState?,
              difficulty: difficulty,
              seed: seed,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(MinesweeperController.gameId)!,
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

MinesweeperController gameOf(WidgetTester tester) =>
    tester.widget<MinesweeperBoard>(find.byType(MinesweeperBoard)).controller;

/// Where [cell] is on screen (a zoomed board too).
Offset cellCenter(WidgetTester tester, int cell) {
  final board = tester.getRect(byKey('minesweeper-board'));
  final columns = gameOf(tester).state.columns;
  final size = board.width / columns;
  return board.topLeft +
      Offset((cell % columns + 0.5) * size, (cell ~/ columns + 0.5) * size);
}

Future<void> tapCell(WidgetTester tester, int cell) async {
  await tester.tapAt(cellCenter(tester, cell));
  await tester.pumpAndSettle();
}

Future<void> longPressCell(WidgetTester tester, int cell) async {
  await tester.longPressAt(cellCenter(tester, cell));
  await tester.pumpAndSettle();
}

/// Holds a finger on [cell] for [ms], then takes it away without a tap:
/// whether the hold flagged the cell.
Future<bool> holdFlags(WidgetTester tester, int cell, int ms) async {
  final finger = await tester.startGesture(cellCenter(tester, cell));
  await tester.pump(Duration(milliseconds: ms));
  final flagged = gameOf(tester).state.isFlagged(cell);
  await finger.cancel();
  await tester.pumpAndSettle();
  return flagged;
}

Future<void> rightClickCell(WidgetTester tester, int cell) async {
  await tester.tapAt(cellCenter(tester, cell), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

bool isEnabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The two cells of [cornerBoard] that the first tap leaves hidden.
const walled = [0, 1];

void main() {
  testWidgets('the first tap opens an area around it', (tester) async {
    await pumpGame(tester, difficulty: MinesweeperDifficulty.easy, seed: 42);
    expect(textOf('mines-left-value'), '10');
    expect(textOf('difficulty-value'), 'Beginner');
    expect(isEnabled(tester, 'hint'), isFalse);

    await tapCell(tester, 40);

    final state = gameOf(tester).state;
    expect(state.isOpen(40), isTrue);
    expect(state.countAt(40), 0);
    expect(state.openCount, greaterThan(9));
    expect(isEnabled(tester, 'hint'), isTrue);
  });

  testWidgets('long press, right click and the flag mode flag cells', (
    tester,
  ) async {
    await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    final game = gameOf(tester);

    await longPressCell(tester, 0);
    expect(game.state.isFlagged(0), isTrue);
    expect(textOf('mines-left-value'), '3');

    await rightClickCell(tester, 0);
    expect(game.state.isFlagged(0), isFalse);
    expect(textOf('mines-left-value'), '4');

    await tapKey(tester, 'flag-mode');
    await tapCell(tester, 1);
    expect(game.state.isFlagged(1), isTrue);
    // A flag keeps its cell closed.
    await tapKey(tester, 'flag-mode');
    await tapCell(tester, 1);
    expect(game.state.isOpen(1), isFalse);

    await rightClickCell(tester, 1);
    await tapCell(tester, 1);
    expect(game.state.isOpen(1), isTrue);
  });

  testWidgets('a hold of 0.3 s flags a cell, faster than a usual long press', (
    tester,
  ) async {
    await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);

    expect(await holdFlags(tester, 0, 250), isFalse);
    expect(await holdFlags(tester, 0, 350), isTrue);
  });

  testWidgets('the hold time comes from the settings', (tester) async {
    await pumpGame(
      tester,
      state: cornerBoard,
      data: {SettingsStore.minesweeperFlagHoldKey: 600},
    );
    await tapCell(tester, cornerTap);

    expect(await holdFlags(tester, 0, 550), isFalse);
    expect(await holdFlags(tester, 0, 650), isTrue);
  });

  testWidgets('a hold vibrates only once the settings turn it on', (
    tester,
  ) async {
    final vibrations = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('HapticFeedback')) vibrations.add(call.method);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final stores = await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);

    expect(await holdFlags(tester, 0, 400), isTrue);
    expect(vibrations, isEmpty);

    await stores.settings.setMinesweeperVibrate(true);
    await tester.pumpAndSettle();
    expect(await holdFlags(tester, 1, 400), isTrue);
    expect(vibrations, hasLength(1));
  });

  testWidgets('two fingers zoom the board in; a tap opens the cell under it', (
    tester,
  ) async {
    await pumpGame(
      tester,
      difficulty: MinesweeperDifficulty.medium,
      seed: 8,
      size: const Size(412, 915),
    );
    final board = byKey('minesweeper-board');
    final before = tester.getRect(board);

    final left = await tester.startGesture(before.center.translate(-30, 0));
    final right = await tester.startGesture(before.center.translate(30, 0));
    for (var step = 0; step < 6; step++) {
      await left.moveBy(const Offset(-15, 0));
      await right.moveBy(const Offset(15, 0));
      await tester.pump();
    }
    await left.up();
    await right.up();
    await tester.pumpAndSettle();

    expect(tester.getRect(board).width, greaterThan(before.width * 2));
    expect(textOf('mines-left-value'), '40');
    const cell = 8 * 16 + 8;
    await tapCell(tester, cell);
    expect(gameOf(tester).firstTap, cell);
  });

  testWidgets('a tap on a number whose flags match opens its neighbors', (
    tester,
  ) async {
    await pumpGame(tester, state: cornerBoard);
    final two = at(cornerBoard, 0, 2);
    await tapCell(tester, two);
    await longPressCell(tester, at(cornerBoard, 0, 1));
    await longPressCell(tester, at(cornerBoard, 1, 1));

    await tapCell(tester, two);

    expect(gameOf(tester).state.isOpen(cornerTap), isTrue);
  });

  testWidgets('opening a mine loses; try again plays the same board', (
    tester,
  ) async {
    final stores = await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    expect(byKey('loss-banner'), findsNothing);

    await tapCell(tester, at(cornerBoard, 1, 1));

    expect(byKey('loss-banner'), findsOneWidget);
    expect(find.text('Boom! You opened a mine.'), findsOneWidget);
    expect(stores.stats.records.single.outcome, GameOutcome.lost);
    expect(isEnabled(tester, 'hint'), isFalse);
    expect(isEnabled(tester, 'flag-mode'), isFalse);

    await tapKey(tester, 'try-again');

    final game = gameOf(tester);
    expect(byKey('loss-banner'), findsNothing);
    expect(game.state.mines, cornerBoard.mines);
    expect(game.state.isOpen(cornerTap), isTrue);
    expect(game.state.isLost, isFalse);
    for (final cell in walled) {
      await tapCell(tester, cell);
    }
    expect(find.text('You won!'), findsOneWidget);
  });

  testWidgets('after a loss, other options opens the new game sheet', (
    tester,
  ) async {
    final stores = await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    await tapCell(tester, at(cornerBoard, 1, 1));

    await tapKey(tester, 'other-options');
    await tapKey(tester, 'new-game-difficulty-hard');
    await tapKey(tester, 'new-game-deal');

    expect(byKey('loss-banner'), findsNothing);
    expect(textOf('difficulty-value'), 'Expert');
    expect(stores.settings.minesweeperDifficulty, MinesweeperDifficulty.hard);
    expect(stores.stats.records, hasLength(1), reason: 'the loss only');
  });

  testWidgets('after a loss, New game deals a board of the same level', (
    tester,
  ) async {
    await pumpGame(tester, difficulty: MinesweeperDifficulty.easy, seed: 3);
    await tapCell(tester, 40);
    final game = gameOf(tester);
    await tapCell(tester, game.state.mines.first);

    await tapKey(tester, 'lost-new-game');

    expect(byKey('loss-banner'), findsNothing);
    expect(game.state.hasMines, isFalse);
    expect(game.difficulty, MinesweeperDifficulty.easy);
  });

  testWidgets('clearing the board wins: the dialog shows the 3BV, Play again '
      'keeps the level', (tester) async {
    final stores = await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    for (final cell in walled) {
      await tapCell(tester, cell);
    }

    expect(find.text('You won!'), findsOneWidget);
    expect(find.text('3BV (clicks needed)'), findsOneWidget);
    expect(find.text('3BV/s'), findsOneWidget);
    expect(stores.stats.records.single.won, isTrue);

    await tapKey(tester, 'play-again');
    final game = gameOf(tester);
    expect(game.state.hasMines, isFalse);
    expect(game.difficulty, MinesweeperDifficulty.medium);
  });

  testWidgets('the new game sheet deals the chosen level and keeps it', (
    tester,
  ) async {
    final stores = await pumpGame(
      tester,
      difficulty: MinesweeperDifficulty.easy,
      seed: 5,
    );
    await tapCell(tester, 40);

    await tapKey(tester, 'new-game');
    expect(byKey('new-game-abandons'), findsOneWidget);
    // The sheet starts from the level of the settings.
    expect(find.text('16 × 16 cells, 40 mines.'), findsOneWidget);
    await tapKey(tester, 'new-game-difficulty-hard');
    expect(find.text('30 × 16 cells, 99 mines.'), findsOneWidget);
    await tapKey(tester, 'new-game-deal');

    expect(textOf('difficulty-value'), 'Expert');
    expect(textOf('mines-left-value'), '99');
    expect(stores.stats.records.single.outcome, GameOutcome.abandoned);
    expect(stores.settings.minesweeperDifficulty, MinesweeperDifficulty.hard);
  });

  testWidgets('a game left continues when opened again from the hub', (
    tester,
  ) async {
    final stores = await pumpGame(
      tester,
      data: {SettingsStore.minesweeperDifficultyKey: 'easy'},
    );
    expect(textOf('difficulty-value'), 'Beginner');
    await tapCell(tester, 40);
    await longPressCell(tester, gameOf(tester).state.mines.first);
    final covers = gameOf(tester).state.encodeCovers();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MinesweeperScreen), findsNothing);
    expect(stores.saves[MinesweeperController.gameId]!.moves, 2);

    await tester.tap(byKey('game-minesweeper'));
    await tester.pumpAndSettle();
    expect(gameOf(tester).state.encodeCovers(), covers);
    expect(textOf('mines-left-value'), '9');
  });

  testWidgets('a hint lights a cell that logic proves safe', (tester) async {
    await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);

    await tapKey(tester, 'hint');

    final game = gameOf(tester);
    expect(walled, contains(game.hintCell));
    expect(game.hints, 1);
    await tapCell(tester, game.hintCell!);
    expect(game.hintCell, isNull);
  });

  testWidgets('a tall screen turns Expert: 16 columns, 30 rows', (
    tester,
  ) async {
    await pumpGame(
      tester,
      difficulty: MinesweeperDifficulty.hard,
      size: const Size(412, 915),
    );
    final state = gameOf(tester).state;
    expect((state.columns, state.rows), (16, 30));
    expect(
      tester.getSize(byKey('minesweeper-board')).width / 16,
      greaterThan(MinesweeperBoardGeometry.minCell),
    );
  });

  testWidgets('a small phone pans Expert; taps open the cell under them', (
    tester,
  ) async {
    await pumpGame(
      tester,
      difficulty: MinesweeperDifficulty.hard,
      seed: 8,
      size: const Size(360, 640),
    );
    expect(
      tester.getSize(byKey('minesweeper-board')).width / 16,
      MinesweeperBoardGeometry.minCell,
    );

    await tapCell(tester, 3 * 16 + 5);

    expect(gameOf(tester).firstTap, 3 * 16 + 5);
  });

  testWidgets('with reduced motion, the loss banner and the win dialog come '
      'at once', (tester) async {
    useReducedMotion(tester);
    await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    await tapCell(tester, at(cornerBoard, 2, 0));
    expect(byKey('loss-banner'), findsOneWidget);

    await tapKey(tester, 'try-again');
    for (final cell in walled) {
      await tapCell(tester, cell);
    }
    expect(find.text('You won!'), findsOneWidget);
  });

  testWidgets('the board draws the theme of the settings', (tester) async {
    final stores = await pumpGame(
      tester,
      state: cornerBoard,
      data: {SettingsStore.minesweeperThemeKey: 'retro'},
    );
    String themeId() =>
        tester.widget<MinesweeperBoard>(find.byType(MinesweeperBoard)).theme.id;
    expect(themeId(), 'retro');

    await stores.settings.setMinesweeperTheme('night');
    await tester.pumpAndSettle();
    expect(themeId(), 'night');
  });

  testWidgets('the statistics show the Minesweeper details', (tester) async {
    await pumpGame(tester, state: cornerBoard);
    await tapCell(tester, cornerTap);
    for (final cell in walled) {
      await tapCell(tester, cell);
    }
    await tester.tap(find.text('Back to games'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('stats-minesweeper'));
    await tester.pumpAndSettle();

    expect(valueIn('stat-won'), '1');
    expect(valueIn('stat-boardValue'), '3');
    expect(valueIn('stat-efficiency'), '100');
    expect(find.text('Efficiency (%)'), findsOneWidget);
  });
}
