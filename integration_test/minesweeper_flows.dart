import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_board.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_controller.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_generator.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// The Minesweeper flows of the e2e tests, on real storage (localStorage on
/// web). `integration_test/app_test.dart` runs them.
void minesweeperFlows() {
  testFlow('Minesweeper places mines as on the VM; a Beginner game won', (
    tester,
  ) async {
    // The first mines of `seed1HardMines` in minesweeper_generator_test.dart
    // (Dart VM): a seed and a first tap must give the same board everywhere.
    expect(
      generateMines(
        columns: 30,
        rows: 16,
        mineCount: 99,
        seed: 1,
        firstTap: 8 * 30 + 15,
      ).mines.take(12),
      [6, 9, 11, 17, 21, 28, 31, 39, 40, 43, 58, 61],
    );

    await _startApp(tester, location: '/minesweeper?difficulty=easy&seed=42');
    expect(_text(tester, 'difficulty-value'), 'Beginner');
    await _tapCell(tester, 40);
    // The board the generator gives for this seed and first tap.
    final mines = generateMines(
      columns: 9,
      rows: 9,
      mineCount: 10,
      seed: 42,
      firstTap: 40,
    ).mines;
    expect(_state(tester).mines, mines);

    for (var cell = 0; cell < 81; cell++) {
      if (mines.contains(cell) || _state(tester).isOpen(cell)) continue;
      await tester.tapAt(_cellCenter(tester, cell));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect((record.won, record.difficulty, record.seed), (true, 'easy', 42));
    expect(record.details[MinesweeperStatKeys.boardValue], greaterThan(0));
    expect((await GameSaveStore.load())[MinesweeperController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pumpAndSettle();
    expect(_state(tester).hasMines, isFalse);
    expect(_text(tester, 'mines-left-value'), '10');
  });

  testFlow('Minesweeper: a mine loses the game; try again replays it', (
    tester,
  ) async {
    await _startApp(tester, location: '/minesweeper?difficulty=easy&seed=7');
    await _tapCell(tester, 40);
    final mines = _state(tester).mines;

    await _tapCell(tester, mines.first);

    expect(find.byKey(const ValueKey('loss-banner')), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect((record.outcome, record.moves), (GameOutcome.lost, 2));

    await tester.tap(find.byKey(const ValueKey('try-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loss-banner')), findsNothing);
    expect(_state(tester).mines, mines);
    expect(_state(tester).isOpen(40), isTrue);
  });

  testFlow('Minesweeper: flags, and a game left continues after a restart', (
    tester,
  ) async {
    await _startApp(tester, location: '/minesweeper?difficulty=easy&seed=11');
    await _tapCell(tester, 40);
    final mines = _state(tester).mines;

    await tester.longPressAt(_cellCenter(tester, mines[0]));
    await tester.pumpAndSettle();
    await tester.tapAt(
      _cellCenter(tester, mines[1]),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('flag-mode')));
    await tester.pumpAndSettle();
    await _tapCell(tester, mines[2]);
    expect(_text(tester, 'mines-left-value'), '7');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(AllForGamesApp(stores: await AppStores.load()));
    await tester.pumpAndSettle();
    expect(
      _text(tester, 'resume-minesweeper'),
      startsWith('Continue · 4 moves'),
    );

    // The last game of the hub: it may be below the fold.
    final tile = find.byKey(const ValueKey('game-minesweeper'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(_text(tester, 'mines-left-value'), '7');
    expect(
      [for (final mine in mines.take(3)) _state(tester).isFlagged(mine)],
      [true, true, true],
    );
  });
}

/// Starts the app in English on real storage that holds nothing.
Future<void> _startApp(WidgetTester tester, {required String location}) async {
  await SharedPreferencesAsync().clear();
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

MinesweeperState _state(WidgetTester tester) => tester
    .widget<MinesweeperBoard>(find.byType(MinesweeperBoard))
    .controller
    .state;

/// Where [cell] is on screen.
Offset _cellCenter(WidgetTester tester, int cell) {
  final board = find.byKey(const ValueKey('minesweeper-board'));
  final columns = _state(tester).columns;
  final size = tester.getSize(board).width / columns;
  return tester.getTopLeft(board) +
      Offset((cell % columns + 0.5) * size, (cell ~/ columns + 0.5) * size);
}

Future<void> _tapCell(WidgetTester tester, int cell) async {
  await tester.tapAt(_cellCenter(tester, cell));
  await tester.pumpAndSettle();
}
