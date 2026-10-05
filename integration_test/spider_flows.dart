import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/spider/spider_controller.dart';
import 'package:all_for_games/games/spider/spider_deals.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_animations.dart';

/// The Spider flows of the e2e tests, on real storage (localStorage on web).
/// `integration_test/app_test.dart` runs them.
void spiderFlows() {
  testFlow('Spider deals as on the VM; a stock deal from the hub, undone', (
    tester,
  ) async {
    // The same board as `seed1HardDeal` in spider_state_test.dart (Dart VM):
    // a seed must give the same deal everywhere.
    expect(
      SpiderState.deal(1, SpiderDifficulty.hard).encode(),
      '9d1Ah03s05s04h03h0Kc08s05d03c14h1Jd1Qc0Tc16h05h05c09d06d06s1Qd0Kh1Qd1Td0'
      '3d0As0Ts16c05s14s0Qs02d1Ac0Qh02d0Kh0Ad02h08d1Ah1Jd0Js0Kc1Js1Kd19c08h17d1'
      '3h1As1,5h14d0Tc0Th03c0QC1,Ks05c17s19s0Th18C0,2c14s19c1Ac18h03S1,'
      '2s08s17c18d07h14C0,Td1Jh12s1Qh14D1,2c09s18c12h16D1,6s05d19h17h06C1,'
      '6h1Ks19h0Jh07D0,Jc14c17s03d1AD1,7c0Kd0Jc0Qs1TS0',
    );

    await _startApp(tester);
    await tester.tap(find.byKey(const ValueKey('game-spider')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'difficulty-value'), '2 suits');
    expect(_text(tester, 'deals-left'), '5');

    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('stock'))));
    await tester.pumpAndSettle();
    expect(_text(tester, 'moves-value'), '1');
    expect(_text(tester, 'deals-left'), '4');
    final data = (await GameSaveStore.load())[SpiderController.gameId]!.data;
    expect(spiderDeals['medium'], contains(data['seed']));

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'deals-left'), '5');
    expect(_text(tester, 'score-value'), '498');
  });

  testFlow('Spider: a move, then the game continues after a restart', (
    tester,
  ) async {
    final (:seed, :from, :to) = _tapMove();
    final moving = SpiderState.deal(
      seed,
      SpiderDifficulty.easy,
    ).columns[from].last.id;
    await _startApp(tester, location: '/spider?difficulty=easy&seed=$seed');

    await tester.tap(find.byKey(ValueKey(moving)));
    await tester.pumpAndSettle();
    expect(_text(tester, 'moves-value'), '1');
    expect(_columnOf(tester, moving), to);
    await _goBack(tester);

    await _restartApp(tester);
    expect(_text(tester, 'resume-spider'), startsWith('Continue · 1 move'));
    await tester.tap(find.byKey(const ValueKey('game-spider')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'moves-value'), '1');
    expect(_text(tester, 'difficulty-value'), '1 suit');
    expect(_columnOf(tester, moving), to);

    // A new game over it records it as abandoned.
    await tester.tap(find.byKey(const ValueKey('new-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-game-abandons')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-game-deal')));
    await tester.pumpAndSettle();
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.seed, record.outcome, record.variant, record.moves),
      (seed, GameOutcome.abandoned, 'suits1', 1),
    );
  });

  testFlow('Spider: the last run of a saved game wins it', (tester) async {
    await SharedPreferencesAsync().clear();
    final stores = await AppStores.load();
    await stores.settings.setLocale(const Locale('en'));
    // A game one move from the win, saved as the game in progress.
    final game = SpiderController(
      stats: stores.stats,
      saves: stores.saves,
      initialState: _nearWon(),
    );
    await stores.saves.save(
      SavedGame(
        gameId: SpiderController.gameId,
        moves: 0,
        playTime: Duration.zero,
        savedAt: DateTime.now(),
        data: game.toJson(),
      ),
    );
    game.dispose();
    await _restartApp(tester);

    await tester.tap(find.byKey(const ValueKey('game-spider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spades-1-7')));
    await tester.pumpAndSettle();

    expect(find.text('You won!'), findsOneWidget);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.won, record.variant, record.moves, record.score),
      (true, 'suits1', 1, 1299),
    );
    expect(record.details[SpiderStatKeys.runsCompleted], 8);
    expect((await GameSaveStore.load())[SpiderController.gameId], isNull);
  });
}

/// A 1-suit board with the 104 cards, one move from the win: seven runs done,
/// the king to the 2 of spades of deck 7 in the first column, its ace alone
/// in the second.
SpiderState _nearWon() => SpiderState(
  columns: [
    [
      for (var rank = 13; rank >= 2; rank--)
        PlayingCard(Suit.spades, rank, faceUp: true, deck: 7),
    ],
    [const PlayingCard(Suit.spades, 1, faceUp: true, deck: 7)],
    for (var i = 2; i < SpiderState.columnCount; i++) [],
  ],
  stock: const [],
  runs: [
    for (var deck = 0; deck < 7; deck++)
      [
        for (var rank = 1; rank <= 13; rank++)
          PlayingCard(Suit.spades, rank, faceUp: true, deck: deck),
      ],
  ],
  difficulty: SpiderDifficulty.easy,
);

/// A proven 1-suit seed where a tap on the top card of column [from] moves
/// it to column [to].
({int seed, int from, int to}) _tapMove() {
  for (final seed in spiderDeals['easy']!) {
    final state = SpiderState.deal(seed, SpiderDifficulty.easy);
    for (var from = 0; from < SpiderState.columnCount; from++) {
      if (state.autoTarget(from, 1) case final to?) {
        return (seed: seed, from: from, to: to);
      }
    }
  }
  throw StateError('No deal with a move');
}

/// The column under the card [cardId], by its left edge.
int _columnOf(WidgetTester tester, String cardId) {
  final x = tester.getTopLeft(find.byKey(ValueKey(cardId))).dx;
  for (var i = 0; i < SpiderState.columnCount; i++) {
    if (tester.getTopLeft(find.byKey(ValueKey('column-$i'))).dx == x) return i;
  }
  return -1;
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
