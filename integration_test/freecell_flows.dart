import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/freecell/freecell_controller.dart';
import 'package:all_for_games/games/freecell/freecell_deals.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// The FreeCell flows of the e2e tests, on real storage (localStorage on
/// web). `integration_test/app_test.dart` runs them.
void freecellFlows() {
  testFlow('FreeCell deals as on the VM; a move from the hub, undone', (
    tester,
  ) async {
    // The same deal as `seed1Deal` in freecell_state_test.dart (Dart VM): a
    // seed must give the same deal everywhere.
    expect(
      FreeCellState.deal(1).encode(),
      ',,,,,,,,KC7C8S5S8C2H4D,4C7SQD8D9CTC2S,AC7D8HJS9D3DTD,KS6SQHJH6C5CAS,'
      'JC6DQC3C4HJD,KDQS7H2CKH9S,3HAD9H4S6HTH,3S5H2D5DAHTS',
    );

    await _startApp(tester);
    await _openFreeCell(tester);
    expect(_text(tester, 'difficulty-value'), 'Medium');
    expect(_text(tester, 'moves-value'), '0');
    // Leaving saves the deal.
    await _goBack(tester);
    final saved = (await GameSaveStore.load())[FreeCellController.gameId]!;
    final seed = saved.data['seed']! as int;
    expect(freecellDeals['medium'], contains(seed));
    final state = FreeCellState.deal(seed);
    expect(saved.data['state'], state.encode());

    // The same deal continues; a single card can always go to a free cell.
    await _openFreeCell(tester);
    final top = state.cascades[0].last.id;
    final dealt = tester.getTopLeft(find.byKey(ValueKey(top)));
    await _tapCard(tester, top);
    expect(_text(tester, 'moves-value'), '1');
    expect(tester.getTopLeft(find.byKey(ValueKey(top))), isNot(dealt));

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(ValueKey(top))), dealt);
    expect(_text(tester, 'moves-value'), '1');
  });

  testFlow('FreeCell: a game left continues after a restart', (tester) async {
    await _startApp(tester, location: '/freecell?seed=42');
    final top = FreeCellState.deal(42).cascades[3].last.id;
    await _tapCard(tester, top);
    final moved = tester.getTopLeft(find.byKey(ValueKey(top)));
    await _goBack(tester);

    await _restartApp(tester);
    expect(_text(tester, 'resume-freecell'), startsWith('Continue · 1 move'));
    await _openFreeCell(tester);
    expect(_text(tester, 'moves-value'), '1');
    expect(tester.getTopLeft(find.byKey(ValueKey(top))), moved);

    // A new game over it records it as abandoned.
    await tester.tap(find.byKey(const ValueKey('new-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-game-abandons')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-game-difficulty-hard')));
    await tester.tap(find.byKey(const ValueKey('new-game-deal')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'difficulty-value'), 'Hard');
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.gameId, record.seed, record.outcome, record.moves),
      (FreeCellController.gameId, 42, GameOutcome.abandoned, 1),
    );
  });

  testFlow('FreeCell: a near-won saved game finishes itself', (tester) async {
    await _startApp(tester, save: _nearWon());
    expect(_text(tester, 'resume-freecell'), startsWith('Continue · 9 moves'));
    await _openFreeCell(tester);

    await tester.tap(find.byKey(const ValueKey('auto-complete')));
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect((record.won, record.moves, record.difficulty), (true, 10, 'easy'));
    expect(record.details[FreeCellStatKeys.autoFinished], 1);
    expect((await GameSaveStore.load())[FreeCellController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'moves-value'), '0');
    expect(_text(tester, 'difficulty-value'), 'Easy');
  });
}

/// A game of an Easy deal where only the queens and kings are left, each
/// queen on a king of the other colour: the game can finish itself.
SavedGame _nearWon() {
  String upToJack(String suit) =>
      [for (final rank in 'A23456789TJ'.split('')) '$rank$suit'].join();
  final state = FreeCellState.decode(
    ',,,,${upToJack('C')},${upToJack('D')},${upToJack('H')},${upToJack('S')},'
    'KCQD,KDQC,KHQS,KSQH,,,,',
  );
  return SavedGame(
    gameId: FreeCellController.gameId,
    moves: 9,
    playTime: const Duration(minutes: 4),
    savedAt: DateTime.utc(2026, 1, 1, 10),
    data: {
      'version': 1,
      'seed': freecellDeals['easy']!.first,
      'difficulty': 'easy',
      'state': state.encode(),
      'history': <Object?>[],
      'startedAt': DateTime.utc(2026, 1, 1, 9, 56).toIso8601String(),
      'playTimeMs': 240000,
      'score': 440,
      'moves': 9,
      'undos': 0,
      'counters': <String, Object?>{},
      'timeToFirstMoveMs': 3000,
      'lastActionMs': 230000,
      'longestThinkMs': 60000,
    },
  );
}

/// Starts the app in English on real storage that holds only [save].
Future<void> _startApp(
  WidgetTester tester, {
  String location = '/',
  SavedGame? save,
}) async {
  await SharedPreferencesAsync().clear();
  if (save != null) await (await GameSaveStore.load()).save(save);
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

Future<void> _openFreeCell(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-freecell')));
  await tester.pumpAndSettle();
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Taps the visible top strip of a card.
Future<void> _tapCard(WidgetTester tester, String cardId) async {
  await tester.tapAt(
    tester.getTopLeft(find.byKey(ValueKey(cardId))) + const Offset(10, 6),
  );
  await tester.pumpAndSettle();
}
