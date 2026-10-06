import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_controller.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_deals.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_solver.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// The TriPeaks flows of the e2e tests, on real storage (localStorage on
/// web). `integration_test/app_test.dart` runs them.
void tripeaksFlows() {
  testFlow('TriPeaks deals as on the VM; a move from the hub, undone', (
    tester,
  ) async {
    // The same deal as `seed1Deal` in tripeaks_state_test.dart (Dart VM): a
    // seed must give the same deal everywhere.
    expect(
      TriPeaksState.deal(1).encode(),
      'Kc4cAcKsJcKd3h3s7c7s7d6s6dQsAd5h8sQd8HQHQC7H9H2D5S8DJSJH,'
      '2c4s5d8c9c9d6c4hKh6hAh2hTc3d5cJd9sThTs4d2sTdAs,3C',
    );

    await _startApp(tester);
    await _openTriPeaks(tester);
    expect(_text(tester, 'difficulty-value'), 'Medium');
    expect(_text(tester, 'moves-value'), '0');
    // Leaving saves the deal.
    await _goBack(tester);
    final saved = (await GameSaveStore.load())[TriPeaksController.gameId]!;
    final seed = saved.data['seed']! as int;
    expect(triPeaksDeals['medium'], contains(seed));
    final state = TriPeaksState.deal(seed);
    expect(saved.data['state'], state.encode());

    // The same deal continues: a card that fits goes onto the waste, else
    // the stock turns one over.
    await _openTriPeaks(tester);
    final moved = state.playable.isEmpty
        ? state.stock.last.id
        : state.tableau[state.playable.first]!.id;
    final dealt = _topLeft(tester, moved);
    if (state.playable.isEmpty) {
      await _tapStock(tester);
    } else {
      await _tapCard(tester, moved);
    }
    expect(_text(tester, 'moves-value'), '1');
    expect(_topLeft(tester, moved), _topLeft(tester, 'waste'));

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(_topLeft(tester, moved), dealt);
    expect(_text(tester, 'moves-value'), '1');
  });

  testFlow('TriPeaks: a game left continues after a restart', (tester) async {
    await _startApp(tester, location: '/tripeaks?seed=42');
    await _tapStock(tester);
    await _goBack(tester);

    await _restartApp(tester);
    expect(_text(tester, 'resume-tripeaks'), startsWith('Continue · 1 move'));
    await _openTriPeaks(tester);
    expect(_text(tester, 'moves-value'), '1');
    expect(_text(tester, 'stock-value'), '22');

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
      (TriPeaksController.gameId, 42, GameOutcome.abandoned, 1),
    );
  });

  testFlow('TriPeaks: the last moves of a winning line win the game', (
    tester,
  ) async {
    final seed = triPeaksDeals['easy']!.first;
    final deal = TriPeaksState.deal(seed);
    final line = const TriPeaksSolver().playGreedy(deal)!;
    final last = line.sublist(line.length - 3);
    final state = replayMoves(deal, line.sublist(0, line.length - 3))!;
    await _startApp(tester, save: _saveOf(seed, state));
    await _openTriPeaks(tester);

    var current = state;
    for (final move in last) {
      if (move.position case final position?) {
        await _tapCard(tester, current.tableau[position]!.id);
        current = current.play(position)!;
      } else {
        await _tapStock(tester);
        current = current.draw()!;
      }
    }

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect((record.won, record.moves, record.difficulty), (true, 43, 'easy'));
    expect(record.details[TriPeaksStatKeys.stockLeft], current.stock.length);
    expect((await GameSaveStore.load())[TriPeaksController.gameId], isNull);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'moves-value'), '0');
    expect(_text(tester, 'difficulty-value'), 'Easy');
  });
}

/// A game of the deal of [seed] at [state], after 40 moves.
SavedGame _saveOf(int seed, TriPeaksState state) => SavedGame(
  gameId: TriPeaksController.gameId,
  moves: 40,
  playTime: const Duration(minutes: 4),
  savedAt: DateTime.utc(2026, 1, 1, 10),
  data: {
    'version': 1,
    'seed': seed,
    'difficulty': 'easy',
    'state': state.encode(),
    'history': <Object?>[],
    'startedAt': DateTime.utc(2026, 1, 1, 9, 56).toIso8601String(),
    'playTimeMs': 240000,
    'score': 800,
    'moves': 40,
    'undos': 0,
    'run': 0,
    'counters': <String, Object?>{},
    'timeToFirstMoveMs': 3000,
    'lastActionMs': 230000,
    'longestThinkMs': 60000,
  },
);

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

Future<void> _openTriPeaks(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('game-tripeaks'));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Offset _topLeft(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key)));

/// Taps the visible left part of a card.
Future<void> _tapCard(WidgetTester tester, String cardId) async {
  await tester.tapAt(_topLeft(tester, cardId) + const Offset(10, 6));
  await tester.pumpAndSettle();
}

Future<void> _tapStock(WidgetTester tester) async {
  // The top stock card covers the slot and draws on tap too.
  await tester.tap(find.byKey(const ValueKey('stock')), warnIfMissed: false);
  await tester.pumpAndSettle();
}
