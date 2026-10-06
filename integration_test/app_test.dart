import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/klondike_deals.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'freecell_flows.dart';
import 'fast_animations.dart';
import 'mahjong_flows.dart';
import 'minesweeper_flows.dart';
import 'spider_flows.dart';
import 'tripeaks_flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  mahjongFlows();
  minesweeperFlows();
  spiderFlows();
  freecellFlows();
  tripeaksFlows();

  testFlow('a game left continues; a new game records it as abandoned', (
    tester,
  ) async {
    await startApp(tester);
    expect(textOf(tester, 'summary-klondike'), startsWith('Not played'));

    await openKlondike(tester);
    await tapStock(tester);
    expect(textOf(tester, 'moves-value'), '1');
    await goBack(tester);

    expect(textOf(tester, 'resume-klondike'), startsWith('Continue · 1 move'));
    expect(textOf(tester, 'summary-klondike'), startsWith('Not played'));
    expect(valueOf(tester, 'overall-played'), '0');

    await openKlondike(tester);
    expect(textOf(tester, 'moves-value'), '1');
    expect(canUndo(tester), isTrue);

    await confirmNewGame(tester);
    expect(textOf(tester, 'moves-value'), '0');
    await goBack(tester);

    expect(find.byKey(const ValueKey('resume-klondike')), findsNothing);
    expect(textOf(tester, 'summary-klondike'), startsWith('1 played'));
    expect(valueOf(tester, 'overall-played'), '1');

    await tester.tap(find.byKey(const ValueKey('stats-klondike')));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 'stat-played'), '1');
    expect(valueOf(tester, 'stat-won'), '0');
  });

  testFlow('deals as on the VM, and a new game deals a winnable seed', (
    tester,
  ) async {
    // The same string as `seed1Deal` in klondike_state_test.dart (Dart VM):
    // the seed lists hold on the web only if the deals are the same.
    expect(
      KlondikeState.deal(1).encode(),
      '3c2c4s5d8c9c9d6c4hKh6hAh2hTc3d5cJd9sThTs4d2sTdAs,,,,,,'
      'KC,4cAC,KsJcKD,3h3s7c7S,7d6s6dQsAD,5h8sQd8hQhQC,7h9h2d5s8dJsJH',
    );

    await startApp(tester);
    await openKlondike(tester);
    await goBack(tester);

    final data = (await GameSaveStore.load())[KlondikeController.gameId]!.data;
    final seed = data['seed'] as int;
    final winnable = klondikeDeals[1]!.values.expand((seeds) => seeds);
    expect(winnable, contains(seed));
    expect(data['state'], KlondikeState.deal(seed).encode());
  });

  testFlow('the new game sheet deals an Easy game and keeps the choice', (
    tester,
  ) async {
    await startApp(tester);
    await openKlondike(tester);
    expect(textOf(tester, 'difficulty-value'), 'Medium');

    await confirmNewGame(tester, difficulty: 'easy');
    expect(textOf(tester, 'difficulty-value'), 'Easy');
    await goBack(tester);

    final saved = (await GameSaveStore.load())[KlondikeController.gameId]!;
    expect(klondikeDeals[1]!['easy'], contains(saved.data['seed']));
    expect(saved.data['difficulty'], 'easy');
    expect(
      (await SettingsStore.load()).klondikeDifficulty,
      KlondikeDifficulty.easy,
    );
  });

  testFlow('drags a card onto another tableau pile', (tester) async {
    final (:seed, :from, :to) = findTableauMove();
    final card = KlondikeState.deal(seed).tableau[from].last;
    await startApp(tester, location: '/klondike?seed=$seed');

    final cardFinder = find.byKey(ValueKey(card.id));
    final targetSlot = find.byKey(ValueKey('tableau-$to'));
    // The top strip is the part of a card that stays visible in a pile.
    final gesture = await tester.startGesture(
      tester.getTopLeft(cardFinder) + const Offset(10, 6),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(targetSlot) + const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(textOf(tester, 'moves-value'), '1');
    expect(tester.getTopLeft(cardFinder).dx, tester.getTopLeft(targetSlot).dx);
  });

  testFlow('a game in progress is kept in browser storage', (tester) async {
    await startApp(tester, location: '/klondike?seed=42');
    await tapStock(tester);
    await goBack(tester);

    final saved = (await GameSaveStore.load())[KlondikeController.gameId];
    expect(saved!.moves, 1);
    expect((await StatsStore.load()).records, isEmpty);

    await restartApp(tester);
    expect(textOf(tester, 'resume-klondike'), startsWith('Continue · 1 move'));

    await openKlondike(tester);
    expect(textOf(tester, 'moves-value'), '1');

    await confirmNewGame(tester);
    final record = (await StatsStore.load()).records.single;
    expect(
      (record.seed, record.moves, record.outcome),
      (42, 1, GameOutcome.abandoned),
    );
  });

  testFlow('the chosen language stays after a restart', (tester) async {
    await startApp(tester);
    expect(find.text('Games'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();
    expect(find.text('Jeux'), findsOneWidget);

    await restartApp(tester);
    expect(find.text('Jeux'), findsOneWidget);
    expect(textOf(tester, 'summary-klondike'), startsWith('Pas encore joué'));
  });

  testFlow('a card back unlocked by a win stays selected after a restart', (
    tester,
  ) async {
    await startApp(tester, records: [wonGame()]);

    await tester.tap(find.byKey(const ValueKey('skins-button')));
    await tester.pumpAndSettle();
    final crimson = find.byKey(const ValueKey('card-back-crimson'));
    await tester.tap(crimson);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: crimson, matching: find.text('Selected')),
      findsOneWidget,
    );

    await restartApp(tester);
    await openKlondike(tester);
    final backs = tester.widgetList<CardBackView>(find.byType(CardBackView));
    expect(backs, isNotEmpty);
    expect({for (final back in backs) back.skin.id}, {'crimson'});
  });

  testFlow('the overview of every game opens the page of a game', (
    tester,
  ) async {
    await startApp(tester, records: [wonGame()]);

    await tester.tap(find.byKey(const ValueKey('overview-stats-button')));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 'overview-stat-won'), '1');

    await tester.tap(find.byKey(const ValueKey('overview-game-klondike')));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 'stat-won'), '1');

    await goBack(tester);
    expect(valueOf(tester, 'overview-stat-played'), '1');
  });
}

/// A Klondike game won before the app starts. It unlocks only the first win
/// achievement (and its crimson card back).
GameRecord wonGame() => GameRecord(
  gameId: KlondikeController.gameId,
  variant: 'draw1',
  seed: 42,
  startedAt: DateTime.utc(2026, 1, 1, 10),
  endedAt: DateTime.utc(2026, 1, 1, 10, 30),
  playTime: const Duration(minutes: 10),
  outcome: GameOutcome.won,
  moves: 120,
  undos: 2,
  score: 600,
);

/// Starts the app in English on real storage (localStorage on web) that
/// holds only [records].
Future<void> startApp(
  WidgetTester tester, {
  String location = '/',
  List<GameRecord> records = const [],
}) async {
  await SharedPreferencesAsync().clear();
  final stats = await StatsStore.load();
  for (final record in records) {
    await stats.add(record);
  }
  final stores = await AppStores.load();
  // The checks read English texts, whatever the browser language.
  await stores.settings.setLocale(const Locale('en'));
  await tester.pumpWidget(
    AllForGamesApp(stores: stores, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

/// Closes the app, then starts it again on the same storage.
Future<void> restartApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(AllForGamesApp(stores: await AppStores.load()));
  await tester.pumpAndSettle();
}

Future<void> openKlondike(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-klondike')));
  await tester.pumpAndSettle();
}

Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

bool canUndo(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const ValueKey('undo'))).onPressed !=
    null;

/// Deals a new game from the new game sheet, in Draw 1 and in [difficulty]
/// when given. Over a game with moves, Deal also confirms the abandon.
Future<void> confirmNewGame(WidgetTester tester, {String? difficulty}) async {
  await tester.tap(find.byKey(const ValueKey('new-game')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-game-draw-1')));
  if (difficulty != null) {
    await tester.tap(find.byKey(ValueKey('new-game-difficulty-$difficulty')));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-game-deal')));
  await tester.pumpAndSettle();
}

Future<void> tapStock(WidgetTester tester) async {
  // The top stock card covers the slot and draws on tap too.
  await tester.tap(find.byKey(const ValueKey('stock')), warnIfMissed: false);
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Text of the `value` child of the widget keyed [key].
String valueOf(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byKey(const ValueKey('value')),
      ),
    )
    .data!;

/// The first deal where a tableau top card can go onto another tableau pile.
({int seed, int from, int to}) findTableauMove() {
  for (var seed = 1; seed <= 1000; seed++) {
    final state = KlondikeState.deal(seed);
    for (var from = 0; from < 7; from++) {
      for (var to = 0; to < 7; to++) {
        if (state.canMove(PileRef.tableau(from), 1, PileRef.tableau(to))) {
          return (seed: seed, from: from, to: to);
        }
      }
    }
  }
  throw StateError('No tableau to tableau move in seeds 1 to 1000');
}
