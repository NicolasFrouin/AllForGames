import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/sudoku/sudoku_board.dart';
import 'package:all_for_games/games/sudoku/sudoku_controller.dart';
import 'package:all_for_games/games/sudoku/sudoku_deal.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/games/sudoku/sudoku_screen.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../games/sudoku/sudoku_test_helpers.dart';
import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Opens Sudoku in the app routes, with the hub below it: on [deal], or on
/// a new game of [level] and [seed] when given, or else the saved game (or
/// a new one from the settings).
Future<AppStores> pumpGame(
  WidgetTester tester, {
  SudokuDeal? deal,
  SudokuLevel? level,
  int? seed,
  Map<String, Object> data = const {},
  Size size = const Size(1280, 900),
}) async {
  useSurface(tester, size);
  final stores = await createTestStores(data);
  final router = GoRouter(
    initialLocation: '/sudoku',
    initialExtra: deal,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => HubScreen(stores: stores),
        routes: [
          GoRoute(
            path: 'sudoku',
            builder: (context, route) => SudokuScreen(
              stores: stores,
              deal: route.extra as SudokuDeal?,
              level: level,
              seed: seed,
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            builder: (context, _) => StatsScreen(
              stores: stores,
              game: gameById(SudokuController.gameId)!,
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

SudokuController gameOf(WidgetTester tester) =>
    tester.widget<SudokuBoard>(find.byType(SudokuBoard)).controller;

Future<void> tapCell(WidgetTester tester, int cell) async {
  final board = tester.getRect(byKey('sudoku-board'));
  final size = board.width / 9;
  await tester.tapAt(
    board.topLeft + Offset((cell % 9 + 0.5) * size, (cell ~/ 9 + 0.5) * size),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

/// The empty cells of the game on screen.
List<int> emptyCells(WidgetTester tester) => [
  for (var cell = 0; cell < 81; cell++)
    if (!gameOf(tester).state.isGiven(cell)) cell,
];

void main() {
  testWidgets('a tapped cell takes the digit of a key; undo, redo, erase', (
    tester,
  ) async {
    await pumpGame(tester, level: SudokuLevel.level1, seed: 1);
    final game = gameOf(tester);
    final [cell, ...] = emptyCells(tester);
    final digit = game.solution[cell];
    await tapCell(tester, cell);
    expect(game.selected, cell);
    await tapKey(tester, 'digit-$digit');
    expect(game.state.values[cell], digit);
    expect(byKey('notes'), findsNothing, reason: 'the setting is off');

    await tapKey(tester, 'undo');
    expect(game.state.values[cell], 0);
    await tapKey(tester, 'redo');
    expect(game.state.values[cell], digit);
    await tapKey(tester, 'erase');
    expect(game.state.values[cell], 0);
    expect(textOf('difficulty-value'), 'Level 1 · Easy');
  });

  testWidgets('with the setting, Notes makes the keys write small numbers', (
    tester,
  ) async {
    await pumpGame(
      tester,
      level: SudokuLevel.level1,
      seed: 1,
      data: {SettingsStore.sudokuNotesKey: true},
    );
    final game = gameOf(tester);
    final [cell, ...] = emptyCells(tester);
    await tapCell(tester, cell);
    await tapKey(tester, 'notes');
    await tapKey(tester, 'digit-3');
    await tapKey(tester, 'digit-8');
    expect(game.state.values[cell], 0);
    expect(
      [game.state.hasNote(cell, 3), game.state.hasNote(cell, 8)],
      [true, true],
    );
    await tapKey(tester, 'notes');
    await tapKey(tester, 'digit-${game.solution[cell]}');
    expect(game.state.values[cell], game.solution[cell]);
    expect(game.state.notes[cell], 0);
  });

  testWidgets('the keyboard moves the selection, types and erases digits', (
    tester,
  ) async {
    await pumpGame(tester, level: SudokuLevel.level1, seed: 1);
    final game = gameOf(tester);
    final [cell, ...] = emptyCells(tester);
    await tapCell(tester, cell);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    expect(game.state.values[cell], 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(game.state.values[cell], 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(game.selected, cell + 10);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(game.state.values[cell], 4, reason: 'undo of the erase');
  });

  testWidgets('the last digit wins: the dialog, then Play again keeps the '
      'level', (tester) async {
    final stores = await pumpGame(tester, deal: almostSolved());
    final game = gameOf(tester);
    final [cell] = emptyCells(tester);
    await tapCell(tester, cell);
    await tester.tap(byKey('digit-${game.solution[cell]}'));
    await tester.pump();
    expect(game.isWon, isTrue);
    expect(find.text('You won!'), findsNothing, reason: 'the wave first');
    await tester.pumpAndSettle();
    expect(find.text('You won!'), findsOneWidget);
    final record = stores.stats.records.single;
    expect((record.won, record.difficulty), (true, 'level3'));

    await tapKey(tester, 'play-again');
    expect(gameOf(tester).isWon, isFalse);
    expect(gameOf(tester).level, SudokuLevel.level3);
    expect(emptyCells(tester).length, greaterThan(40));
  });

  testWidgets('the new game sheet deals the chosen level and keeps it, '
      'without a record of the game on screen; Abandon and deal records it', (
    tester,
  ) async {
    final stores = await pumpGame(tester, level: SudokuLevel.level2, seed: 4);
    await tapCell(tester, emptyCells(tester).first);
    await tapKey(tester, 'digit-1');

    await tapKey(tester, 'new-game');
    expect(byKey('new-game-abandons'), findsOneWidget);
    // The sheet starts from the level of the settings.
    expect(textOf('new-game-level'), 'Level 3 · Easy');
    await tapKey(tester, 'new-game-difficulty-level9');
    expect(textOf('new-game-level'), 'Level 9 · Hard');
    expect(find.textContaining('Swordfish'), findsOneWidget);
    await tapKey(tester, 'new-game-deal');
    expect(gameOf(tester).level, SudokuLevel.level9);
    expect(stores.settings.sudokuLevel, SudokuLevel.level9);
    expect(stores.stats.records, isEmpty);

    await tapCell(tester, emptyCells(tester).first);
    await tapKey(tester, 'digit-1');
    await tapKey(tester, 'new-game');
    await tapKey(tester, 'new-game-abandon');
    final record = stores.stats.records.single;
    expect(
      (record.outcome, record.difficulty),
      (GameOutcome.abandoned, 'level9'),
    );
  });

  testWidgets('a game left continues when opened again from the hub', (
    tester,
  ) async {
    final stores = await pumpGame(
      tester,
      data: {SettingsStore.sudokuLevelKey: 'level6'},
    );
    expect(gameOf(tester).level, SudokuLevel.level6);
    final [cell, ...] = emptyCells(tester);
    await tapCell(tester, cell);
    await tapKey(tester, 'digit-7');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SudokuScreen), findsNothing);
    expect(stores.saves[SudokuController.gameId]!.moves, 1);

    await tester.tap(byKey('game-sudoku'));
    await tester.pumpAndSettle();
    expect(gameOf(tester).state.values[cell], 7);
    expect(gameOf(tester).canUndo, isTrue);
  });

  testWidgets('a phone shows the grid and three rows of large keys', (
    tester,
  ) async {
    await pumpGame(
      tester,
      level: SudokuLevel.level1,
      seed: 1,
      size: const Size(390, 844),
    );
    final board = tester.getRect(byKey('sudoku-board'));
    expect(board.width, greaterThan(360));
    final one = tester.getRect(byKey('digit-1'));
    final four = tester.getRect(byKey('digit-4'));
    expect(four.top, greaterThan(one.bottom - 1), reason: 'a row under');
    expect(one.width, greaterThan(100));
    expect(one.height, greaterThan(60));
    expect(tester.takeException(), isNull);

    // A short phone keeps one row of nine.
    await pumpGame(
      tester,
      level: SudokuLevel.level1,
      seed: 1,
      size: const Size(360, 640),
    );
    final small = tester.getRect(byKey('digit-1'));
    expect(tester.getRect(byKey('digit-9')).top, small.top);
    expect(small.height, greaterThan(60));
  });
}
