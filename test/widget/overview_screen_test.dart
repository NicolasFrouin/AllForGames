import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/achievements/achievements_screen.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/overview_screen.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// Games of three games of the catalog and of one game it does not have, in
/// time order: lost, then three wins, then a game not won.
final savedGames = [
  record(
    won: false,
    playTime: const Duration(minutes: 1, seconds: 30),
    moves: 20,
    undos: 1,
    endedMinute: 1,
  ),
  record(
    playTime: const Duration(minutes: 2),
    moves: 90,
    undos: 2,
    endedMinute: 2,
    difficulty: 'hard',
  ),
  record(
    gameId: 'freecell',
    variant: 'classic',
    playTime: const Duration(minutes: 1),
    moves: 60,
    endedMinute: 3,
  ),
  record(
    gameId: 'spider',
    variant: 'suits1',
    playTime: const Duration(minutes: 10),
    moves: 150,
    endedMinute: 4,
  ),
  record(
    gameId: 'future-game',
    variant: 'x',
    won: false,
    playTime: const Duration(seconds: 30),
    moves: 5,
    endedMinute: 5,
  ),
];

Future<void> pumpOverview(
  WidgetTester tester,
  AppStores stores, {
  Size size = const Size(1280, 2400),
  String location = '/stats',
}) async {
  // Tall enough to lay out every card.
  useSurface(tester, size);
  await tester.pumpWidget(
    AllForGamesApp(stores: stores, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

void expectValues(Map<String, String> expected) {
  for (final MapEntry(:key, :value) in expected.entries) {
    expect(valueIn('overview-stat-$key'), value, reason: key);
  }
}

Finder textIn(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without games, shows the empty state and the achievements', (
    tester,
  ) async {
    // Unlocks stay when the statistics are cleared.
    final date = DateTime.utc(2026, 1, 1);
    await pumpOverview(
      tester,
      await createTestStores(
        savedUnlockData({'klondike.firstWin': date, 'freecell.firstWin': date}),
      ),
    );

    expect(
      find.text('No games yet. Play one to see your statistics.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('overview-stat-played')), findsNothing);
    expect(
      valueIn('overview-stat-achievements'),
      '2 / ${achievements.length} unlocked',
    );
  });

  testWidgets('sums the games of every game', (tester) async {
    await pumpOverview(tester, await seededStores(savedGames));

    expectValues({
      'played': '5',
      'won': '3',
      'winRate': '60%',
      'totalMoves': '325',
      'winStreak': '0',
      'bestWinStreak': '3',
      'timePlayed': '15m 00s',
      'averageGameTime': '3:00',
      'daysPlayed': '1',
      'totalUndos': '3',
      'dayStreak': '0',
      'bestDayStreak': '1',
      'fastestWin': 'FreeCell · 1:00',
      'longestGame': 'Spider · 10:00',
      'mostMovesWin': 'Spider · 150 moves',
      'mostPlayed': 'Klondike · 2 games',
      'mostTime': 'Spider · 10m 00s',
    });
  });

  testWidgets('lists every game, then the games missing from the catalog', (
    tester,
  ) async {
    await pumpOverview(tester, await seededStores(savedGames));

    expect(
      textIn('overview-game-klondike', '2 played · 1 won (50%)'),
      findsOne,
    );
    expect(
      textIn('overview-game-klondike', 'Best 2:00 · 3m 30s played'),
      findsOne,
    );
    expect(textIn('overview-game-klondike', 'Last played 1/1/2026'), findsOne);
    expect(textIn('overview-game-mahjong', 'Not played yet'), findsOne);
    expect(textIn('overview-game-future-game', 'future-game'), findsOne);
    final tops = [
      for (final id in ['klondike', 'freecell', 'spider', 'future-game'])
        tester.getTopLeft(find.byKey(ValueKey('overview-game-$id'))).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));

    // A game missing from the catalog has no page to open.
    await tapKey(tester, 'overview-game-future-game');
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(StatsScreen), findsNothing);
  });

  testWidgets('recent games: the most recent first, with their game', (
    tester,
  ) async {
    await pumpOverview(tester, await seededStores(savedGames));

    expect(textIn('overview-recent-0', 'future-game'), findsOne);
    expect(textIn('overview-recent-1', 'Spider · 1 suit'), findsOne);
    expect(textIn('overview-recent-3', 'Klondike · Draw 1 · Hard'), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-recent-4')),
        matching: find.textContaining('Abandoned · 1:30 · 20 moves'),
      ),
      findsOne,
    );
    expect(find.byKey(const ValueKey('overview-recent-5')), findsNothing);

    await tapKey(tester, 'overview-recent-1');
    expect(find.widgetWithText(AppBar, 'Spider statistics'), findsOne);
  });

  testWidgets('a lost game shows as lost, and not won', (tester) async {
    await pumpOverview(
      tester,
      await seededStores([
        GameRecord(
          gameId: 'klondike',
          variant: 'draw1',
          seed: 1,
          startedAt: DateTime.utc(2026, 1, 1, 10),
          endedAt: DateTime.utc(2026, 1, 1, 10, 5),
          playTime: const Duration(minutes: 5),
          outcome: GameOutcome.lost,
          moves: 40,
          undos: 0,
          score: 0,
        ),
      ]),
    );

    expectValues({'played': '1', 'won': '0', 'winRate': '0%'});
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-recent-0')),
        matching: find.text('Lost · 5:00 · 40 moves'),
      ),
      findsOne,
    );
  });

  testWidgets('a game opens its statistics; Back returns to the overview', (
    tester,
  ) async {
    await pumpOverview(tester, await seededStores(savedGames));

    await tapKey(tester, 'overview-game-klondike');
    expect(find.widgetWithText(AppBar, 'Klondike statistics'), findsOne);
    expect(valueIn('stat-played'), '2');

    await goBack(tester);
    expect(find.byType(OverviewScreen), findsOneWidget);

    await tapKey(tester, 'overview-achievements');
    expect(find.byType(AchievementsScreen), findsOneWidget);

    await goBack(tester);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  testWidgets('the hub opens the overview from its button and its chips', (
    tester,
  ) async {
    await pumpOverview(tester, await seededStores(savedGames), location: '/');

    await tapKey(tester, 'overview-stats-button');
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(valueIn('overview-stat-played'), '5');

    await goBack(tester);
    expect(find.byType(HubScreen), findsOneWidget);

    await tapKey(tester, 'overall-time');
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  testWidgets('the activity chart tells screen readers the last 30 days', (
    tester,
  ) async {
    final now = DateTime.now();
    GameRecord today(int minutesAgo, {required bool won}) => GameRecord(
      gameId: 'klondike',
      variant: 'draw1',
      seed: minutesAgo,
      startedAt: now.subtract(Duration(minutes: minutesAgo + 3)),
      endedAt: now.subtract(Duration(minutes: minutesAgo)),
      playTime: const Duration(minutes: 3),
      outcome: won ? GameOutcome.won : GameOutcome.abandoned,
      moves: 50,
      undos: 0,
      score: 0,
    );
    await pumpOverview(
      tester,
      await seededStores([
        // Older than 30 days: out of the chart.
        record(endedMinute: 1),
        today(1, won: true),
        today(2, won: false),
      ]),
    );

    expect(textOf('overview-activity-summary'), '2 games, 1 won');
    expectValues({'dayStreak': '1', 'daysPlayed': '2'});
    final label = tester
        .getSemantics(find.byKey(const ValueKey('overview-activity')))
        .label;
    expect(label, startsWith('Last 30 days. 2 games, 1 won. '));
    expect(label, contains(': 1 won, 1 not won'));
  });

  testWidgets('in French, the values keep their keys with French formats', (
    tester,
  ) async {
    await pumpOverview(
      tester,
      await createTestStores({
        ...savedData(savedGames),
        SettingsStore.localeKey: 'fr',
      }),
    );

    expect(find.widgetWithText(AppBar, 'Toutes les statistiques'), findsOne);
    expectValues({
      'played': '5',
      'winRate': '60\u00a0%',
      'timePlayed': '15\u00a0min\u00a000\u00a0s',
      'mostPlayed': 'Klondike · 2 parties',
    });
    expect(
      textIn('overview-game-klondike', '2 jouées · 1 gagnée (50\u00a0%)'),
      findsOne,
    );
  });

  testWidgets('a phone has one column, a desktop two under the totals', (
    tester,
  ) async {
    Offset topLeftOf(String key) =>
        tester.getTopLeft(find.byKey(ValueKey(key)));

    await pumpOverview(
      tester,
      await seededStores(savedGames),
      size: const Size(360, 6000),
    );
    expect(
      topLeftOf('overview-stat-achievements').dy,
      lessThan(topLeftOf('overview-game-klondike').dy),
    );
    expect(
      topLeftOf('overview-stat-achievements').dx,
      topLeftOf('overview-game-klondike').dx,
    );

    await pumpOverview(tester, await seededStores(savedGames));
    expect(
      topLeftOf('overview-stat-achievements').dx,
      greaterThan(topLeftOf('overview-game-klondike').dx + 300),
    );
  });
}
