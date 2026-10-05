import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Mahjong flows of the e2e tests, on real storage (localStorage on
/// web). `integration_test/app_test.dart` runs them.
void mahjongFlows() {
  testWidgets('Mahjong deals as on the VM; a match from the hub, undone', (
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
        4, 33, 27, 1, 32, 36, 18, 15, 0, 25, 6, 12, //
        11, 18, 29, 20, 10, 19, 9, 4, 25, 30, 5, 37,
      ],
    );

    await _startApp(tester);
    await tester.tap(find.byKey(const ValueKey('game-mahjong')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '144');
    expect(_text(tester, 'difficulty-value'), 'Medium');

    final (a, b) = await _hint(tester);
    await _tapTile(tester, a);
    await _tapTile(tester, b);
    expect(_text(tester, 'tiles-value'), '142');

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tiles-value'), '144');
  });

  testWidgets('Mahjong: a game left continues after a restart', (tester) async {
    await _startApp(tester, location: '/mahjong?seed=42&difficulty=hard');
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

  testWidgets('Mahjong: an Easy board played to the end is a win', (
    tester,
  ) async {
    await _startApp(tester, location: '/mahjong?seed=5&difficulty=easy');
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

Future<void> _tapTile(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(ValueKey('tile-$id')));
  await tester.pumpAndSettle();
}
