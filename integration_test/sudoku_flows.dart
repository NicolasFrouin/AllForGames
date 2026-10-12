import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/sudoku/sudoku_board.dart';
import 'package:all_for_games/games/sudoku/sudoku_controller.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// `SudokuDeal.deal(SudokuLevel.level1, 1)` on the Dart VM (see
/// test/games/sudoku/sudoku_test_helpers.dart).
const _seed1Level1Givens =
    '903200000205917403018060000590040276840756100630100004'
    '026000008704000900089420567';
const _seed1Level1Solution =
    '973284615265917483418365792591843276842756139637192854'
    '126579348754638921389421567';

/// The Sudoku flows of the e2e tests, on real storage (localStorage on web).
/// `integration_test/app_test.dart` runs them.
void sudokuFlows() {
  testFlow('Sudoku deals as on the VM; a level 1 grid won with the keypad', (
    tester,
  ) async {
    await _startApp(tester, location: '/sudoku?level=1&seed=1');
    expect(_text(tester, 'difficulty-value'), 'Level 1 · Easy');
    expect(SudokuGrid.encode(_game(tester).state.givens), _seed1Level1Givens);
    final solution = SudokuGrid.decode(_seed1Level1Solution);
    final empty = [
      for (var cell = 0; cell < 81; cell++)
        if (!_game(tester).state.isGiven(cell)) cell,
    ];

    // A wrong digit, taken back.
    await _tapCell(tester, empty.first);
    await _tapKey(tester, 'digit-${solution[empty.first] % 9 + 1}');
    await _tapKey(tester, 'undo');
    expect(_game(tester).state.values[empty.first], 0);

    for (final cell in empty) {
      await tester.tapAt(_cellCenter(tester, cell));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('digit-${solution[cell]}')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.won, record.difficulty, record.seed, record.undos),
      (true, 'level1', 1, 1),
    );
    expect(record.score, empty.length * SudokuController.pointsPerCell);
    expect((await GameSaveStore.load())[SudokuController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pumpAndSettle();
    expect(_game(tester).isWon, isFalse);
    expect(_text(tester, 'difficulty-value'), 'Level 1 · Easy');
  });

  testFlow('Sudoku: small numbers from the settings; a game left continues', (
    tester,
  ) async {
    await _startApp(tester, location: '/settings');
    final notes = find.byKey(const ValueKey('sudoku-notes'));
    await tester.ensureVisible(notes);
    await tester.pumpAndSettle();
    await tester.tap(notes);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(notes).value, isTrue);

    await _startApp(
      tester,
      location: '/sudoku?level=8&seed=5',
      clearStorage: false,
    );
    final cell = [
      for (var cell = 0; cell < 81; cell++)
        if (!_game(tester).state.isGiven(cell)) cell,
    ].first;
    await _tapCell(tester, cell);
    await _tapKey(tester, 'notes');
    await _tapKey(tester, 'digit-2');
    await _tapKey(tester, 'digit-6');
    expect(_game(tester).state.notes[cell], 1 << 2 | 1 << 6);

    // The app opened again continues the game from its save.
    await _startApp(tester, location: '/sudoku', clearStorage: false);
    expect(_game(tester).state.notes[cell], 1 << 2 | 1 << 6);
    expect(_text(tester, 'difficulty-value'), 'Level 8 · Hard');
    final saved = (await GameSaveStore.load())[SudokuController.gameId]!;
    expect(saved.data['seed'], 5);

    await _tapKey(tester, 'new-game');
    await _tapKey(tester, 'new-game-abandon');
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.outcome, record.difficulty, record.details['notesPlaced']),
      (GameOutcome.abandoned, 'level8', 2),
    );
  });
}

Future<void> _startApp(
  WidgetTester tester, {
  required String location,
  bool clearStorage = true,
}) async {
  // Closes the app on screen first: its game saves itself.
  await tester.pumpWidget(const SizedBox.shrink());
  if (clearStorage) await SharedPreferencesAsync().clear();
  final stores = await AppStores.load();
  // The checks read English texts, whatever the browser language.
  await stores.settings.setLocale(const Locale('en'));
  await tester.pumpWidget(
    AllForGamesApp(stores: stores, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

SudokuController _game(WidgetTester tester) =>
    tester.widget<SudokuBoard>(find.byType(SudokuBoard)).controller;

/// Where [cell] is on screen.
Offset _cellCenter(WidgetTester tester, int cell) {
  final board = tester.getRect(find.byKey(const ValueKey('sudoku-board')));
  final size = board.width / 9;
  return board.topLeft +
      Offset((cell % 9 + 0.5) * size, (cell ~/ 9 + 0.5) * size);
}

Future<void> _tapCell(WidgetTester tester, int cell) async {
  await tester.tapAt(_cellCenter(tester, cell));
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}
