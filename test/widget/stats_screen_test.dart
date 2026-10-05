import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

const emptyText = 'No games yet. Play one to see your statistics.';

/// Klondike games in time order (the last one from a link, without a
/// difficulty), then one FreeCell game.
final savedGames = [
  record(
    won: false,
    playTime: const Duration(minutes: 1, seconds: 30),
    moves: 20,
    score: 100,
    endedMinute: 1,
    difficulty: 'easy',
    details: {'stockDraws': 10},
  ),
  record(
    playTime: const Duration(minutes: 2),
    moves: 90,
    undos: 2,
    score: 500,
    endedMinute: 2,
    difficulty: 'hard',
    details: {'stockDraws': 20, 'timeToFirstMoveMs': 4000},
  ),
  record(
    variant: 'draw3',
    playTime: const Duration(minutes: 3),
    moves: 120,
    undos: 1,
    score: 300,
    endedMinute: 3,
    difficulty: 'hard',
    details: {'stockDraws': 31, 'timeToFirstMoveMs': 2000},
  ),
  record(
    won: false,
    playTime: const Duration(seconds: 30),
    moves: 5,
    score: 0,
    endedMinute: 4,
    details: {'stockDraws': 5},
  ),
  record(gameId: 'freecell', endedMinute: 5),
];

Future<void> pumpStats(WidgetTester tester, AppStores stores) async {
  // Tall enough to lay out every section of the list.
  useSurface(tester, const Size(1280, 1400));
  await tester.pumpWidget(
    AllForGamesApp(stores: stores, initialLocation: '/stats/klondike'),
  );
  await tester.pumpAndSettle();
}

void expectStats(Map<String, String> expected) {
  for (final MapEntry(:key, :value) in expected.entries) {
    expect(valueIn('stat-$key'), value, reason: key);
  }
}

Future<void> selectVariant(WidgetTester tester, String variant) async {
  await tester.tap(find.byKey(ValueKey('variant-$variant')));
  await tester.pumpAndSettle();
}

Future<void> selectDifficulty(WidgetTester tester, String difficulty) async {
  await tester.tap(find.byKey(ValueKey('difficulty-$difficulty')));
  await tester.pumpAndSettle();
}

Future<void> tapReset(WidgetTester tester, Finder button) async {
  await tester.tap(find.byKey(const ValueKey('reset-stats')));
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state without a Klondike game', (tester) async {
    await pumpStats(tester, await seededStores([savedGames.last]));

    expect(find.text(emptyText), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-played')), findsNothing);
    expect(find.text('Recent games'), findsNothing);
  });

  testWidgets('shows the numbers of every saved Klondike game', (tester) async {
    await pumpStats(tester, await seededStores(savedGames));

    expect(find.text(emptyText), findsNothing);
    expectStats({
      'played': '4',
      'won': '2',
      'winRate': '50%',
      'currentStreak': '0',
      'bestStreak': '2',
      'timePlayed': '7m 00s',
      'bestTime': '2:00',
      'averageWinTime': '2:30',
      'fewestMoves': '90',
      'bestScore': '500',
      'totalMoves': '235',
      'totalUndos': '3',
      'stockDraws': '16.5',
      'timeToFirstMoveMs': '1s',
    });

    // Most recent first.
    final titles = [
      'Abandoned · 0:30',
      'Won · 3:00',
      'Won · 2:00',
      'Abandoned · 1:30',
    ];
    final tops = [
      for (final title in titles) tester.getTopLeft(find.text(title)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('in French, the tiles keep their keys with French numbers', (
    tester,
  ) async {
    await pumpStats(
      tester,
      await createTestStores({
        ...savedData(savedGames),
        SettingsStore.localeKey: 'fr',
      }),
    );

    expect(find.widgetWithText(AppBar, 'Statistiques – Klondike'), findsOne);
    expectStats({
      'played': '4',
      'winRate': '50\u00a0%',
      'timePlayed': '7\u00a0min\u00a000\u00a0s',
      'stockDraws': '16,5',
      'timeToFirstMoveMs': '1\u00a0s',
    });
    expect(find.text('Gagnée · 3:00'), findsOneWidget);
  });

  testWidgets('variant chips filter the numbers', (tester) async {
    await pumpStats(tester, await seededStores(savedGames));

    await selectVariant(tester, 'draw1');
    expectStats({
      'played': '3',
      'won': '1',
      'winRate': '33%',
      'currentStreak': '0',
      'bestStreak': '1',
      'timePlayed': '4m 00s',
      'bestTime': '2:00',
      'fewestMoves': '90',
      'totalMoves': '115',
      'stockDraws': '11.7',
    });
    expect(find.text('Won · 3:00'), findsNothing);

    await selectVariant(tester, 'draw3');
    expectStats({
      'played': '1',
      'won': '1',
      'winRate': '100%',
      'currentStreak': '1',
      'bestTime': '3:00',
      'fewestMoves': '120',
      'bestScore': '300',
      'totalUndos': '1',
      'stockDraws': '31',
      'timeToFirstMoveMs': '2s',
    });
    expect(find.text('Won · 3:00'), findsOneWidget);
    expect(find.text('Won · 2:00'), findsNothing);
    expect(find.textContaining('Abandoned'), findsNothing);

    await selectVariant(tester, 'all');
    expectStats({'played': '4', 'won': '2'});
  });

  testWidgets('difficulty chips filter the numbers, with the variant chips', (
    tester,
  ) async {
    await pumpStats(tester, await seededStores(savedGames));
    expect(find.textContaining('Draw 3 · Hard · 120 moves'), findsOneWidget);
    expect(find.textContaining('Draw 1 · 5 moves'), findsOneWidget);

    await selectDifficulty(tester, 'hard');
    expectStats({'played': '2', 'won': '2', 'bestTime': '2:00'});
    expect(find.textContaining('Abandoned'), findsNothing);

    await selectVariant(tester, 'draw1');
    expectStats({'played': '1', 'won': '1', 'fewestMoves': '90'});

    await selectDifficulty(tester, 'easy');
    expectStats({'played': '1', 'won': '0', 'totalMoves': '20'});

    await selectDifficulty(tester, 'medium');
    expect(find.text(emptyText), findsOneWidget);
    expect(find.byKey(const ValueKey('difficulty-all')), findsOneWidget);

    await selectDifficulty(tester, 'all');
    await selectVariant(tester, 'all');
    expectStats({'played': '4', 'won': '2'});
  });

  testWidgets('cancelling the reset keeps the games', (tester) async {
    final stores = await seededStores(savedGames);
    await pumpStats(tester, stores);

    await tapReset(tester, find.text('Cancel'));

    expectStats({'played': '4'});
    expect(stores.stats.records, hasLength(savedGames.length));
  });

  testWidgets('reset deletes the Klondike games only', (tester) async {
    final stores = await seededStores(savedGames);
    await pumpStats(tester, stores);

    await tapReset(tester, find.byKey(const ValueKey('confirm-reset')));

    expect(find.text(emptyText), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-played')), findsNothing);
    expect(stores.stats.records.map((r) => r.gameId), ['freecell']);
    final reloaded = await StatsStore.load();
    expect(reloaded.records.map((r) => r.gameId), ['freecell']);
  });
}
