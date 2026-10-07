import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_tile_view.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// The Mahjong flows of the e2e tests, on real storage (localStorage on
/// web). `integration_test/app_test.dart` runs them.
void mahjongFlows() {
  testFlow('Mahjong deals as on the VM; a match from the hub, undone', (
    tester,
  ) async {
    // The same faces as `seed1MediumFaces` in mahjong_generator_test.dart
    // (Dart VM): a seed must give the same deal everywhere.
    expect(
      generateDeal(
        MahjongDifficulty.medium.layout(),
        1,
        trapPercent: MahjongDifficulty.medium.trapPercent,
      ).state.faces.take(24),
      [
        4, 33, 27, 1, 32, 34, 18, 15, 0, 25, 6, 12, //
        11, 18, 29, 20, 10, 19, 9, 4, 25, 30, 5, 34,
      ],
    );

    await _startApp(tester);
    await tester.tap(find.byKey(const ValueKey('game-mahjong')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'difficulty-value'), 'Medium');

    final (a, b) = await _hint(tester);
    // A generated shape: its tiles are those of the save.
    final saved = await _savedGame();
    expect(saved['layout'], 'random');
    final tiles = (saved['positions']! as List<Object?>).length ~/ 3;
    expect(_text(tester, 'tiles-value'), '$tiles');
    await _tapTile(tester, a);
    await _tapTile(tester, b);
    expect(_text(tester, 'tiles-value'), '${tiles - 2}');

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '$tiles');
  });

  testFlow('Mahjong: a game left continues after a restart', (tester) async {
    await _startApp(
      tester,
      location: '/mahjong?seed=42&difficulty=hard&shape=classic',
    );
    final (a, b) = await _hint(tester);
    await _tapTile(tester, a);
    await _tapTile(tester, b);
    await _goBack(tester);

    await _restartApp(tester);
    expect(_text(tester, 'resume-mahjong'), startsWith('Continue · 1 move'));
    await tester.tap(find.byKey(const ValueKey('game-mahjong')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '142');
    expect(_text(tester, 'difficulty-value'), 'Hard');

    // A new game over it records it as abandoned.
    await tester.tap(find.byKey(const ValueKey('new-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-game-abandons')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-game-deal')));
    await tester.pumpAndSettle();
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.seed, record.outcome, record.variant, record.difficulty),
      (42, GameOutcome.abandoned, 'turtle', 'hard'),
    );
    expect(record.details[MahjongStatKeys.tilesLeft], 142);
  });

  testFlow('Mahjong: an Easy board played to the end is a win', (tester) async {
    await _startApp(
      tester,
      location: '/mahjong?seed=5&difficulty=easy&shape=classic',
    );
    await _hint(tester);
    // The order that clears the deal, as the hint knows it.
    final ids = ((await _savedGame())['solution']! as List<Object?>)
        .cast<int>();
    for (final id in ids) {
      await tester.tap(find.byKey(ValueKey('tile-$id')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.won, record.variant, record.difficulty, record.moves),
      (true, 'pyramid', 'easy', 36),
    );
    expect(record.details[MahjongStatKeys.hints], 1);
    expect((await GameSaveStore.load())[MahjongController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '72');
  });

  testFlow('Mahjong tray mode: the order a deal was built with wins it', (
    tester,
  ) async {
    // The same faces as `seed1MediumTrayFaces` in mahjong_tray_test.dart
    // (Dart VM).
    expect(
      generateTrayDeal(
        MahjongDifficulty.medium.layout(),
        1,
        MahjongDifficulty.medium.tray,
      ).state.faces.take(24),
      [
        6, 4, 0, 0, 20, 11, 28, 31, 12, 31, 12, 8, //
        30, 29, 6, 20, 1, 35, 13, 14, 28, 23, 2, 17,
      ],
    );

    await _startApp(
      tester,
      location: '/mahjong?mode=tray&seed=5&difficulty=easy&shape=classic',
    );
    expect(_text(tester, 'mode-value'), 'Tray · Easy');
    await tester.tap(find.byKey(const ValueKey('hint')));
    await tester.pumpAndSettle();
    // The order of picks that wins the deal, as the hint knows it.
    final ids = ((await _savedGame())['solution']! as List<Object?>)
        .cast<int>();
    for (final id in ids) {
      await tester.tap(find.byKey(ValueKey('tile-$id')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.won, record.variant, record.difficulty, record.moves),
      (true, 'tray-pyramid', 'easy', 72),
    );
    expect(record.details[MahjongStatKeys.mostHeld], 1);
  });

  testFlow('Mahjong tray mode: a full tray loses; Try again deals it again', (
    tester,
  ) async {
    await _startApp(
      tester,
      location: '/mahjong?mode=tray&seed=6&difficulty=hard&shape=classic',
    );
    await tester.tap(find.byKey(const ValueKey('hint')));
    await tester.pumpAndSettle();
    final saved = await _savedGame();
    final state = MahjongController.restore(
      saved,
      stats: await StatsStore.load(),
      saves: await GameSaveStore.load(),
    ).state;
    // Four free tiles of four faces: no pair in the tray.
    final picks = <int>[];
    for (final id in state.tileIds) {
      final face = state.faces[id];
      if (state.isFree(id) &&
          picks.every((pick) => state.faces[pick] != face)) {
        picks.add(id);
      }
    }
    for (final id in picks.take(4)) {
      await _tapTile(tester, id);
    }

    expect(find.text('The tray is full'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.outcome, record.variant, record.difficulty, record.moves),
      (GameOutcome.lost, 'tray-turtle', 'hard', 4),
    );
    expect((await GameSaveStore.load())[MahjongController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('try-again')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '144');
    await tester.tap(find.byKey(const ValueKey('hint')));
    await tester.pumpAndSettle();
    expect((await _savedGame())['faces'], saved['faces']);
  });
}

/// Starts the app in English on real storage that holds nothing.
Future<void> _startApp(WidgetTester tester, {String location = '/'}) async {
  await SharedPreferencesAsync().clear();
  final stores = await AppStores.load();
  // The checks read English texts, whatever the browser language.
  await stores.settings.setLocale(const Locale('en'));
  await tester.pumpWidget(
    AllForGamesApp(stores: stores, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

/// Closes the app, then starts it again on the same storage.
Future<void> _restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(AllForGamesApp(stores: await AppStores.load()));
  await tester.pumpAndSettle();
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<Map<String, Object?>> _savedGame() async =>
    (await GameSaveStore.load())[MahjongController.gameId]!.data;

/// Asks for a hint, and returns the pair it shows: the first pair of the
/// order that clears the board, which the hint saves with the game.
Future<(int, int)> _hint(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('hint')));
  await tester.pumpAndSettle();
  final solution = (await _savedGame())['solution']! as List<Object?>;
  return (solution[0]! as int, solution[1]! as int);
}

/// Takes tile [id] like a player: a face-down tile is turned over first.
Future<void> _tapTile(WidgetTester tester, int id) async {
  final tile = find.byKey(ValueKey('tile-$id'));
  final view = tester.widget<MahjongTileView>(
    find.descendant(of: tile, matching: find.byType(MahjongTileView)),
  );
  if (view.faceDown) {
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
