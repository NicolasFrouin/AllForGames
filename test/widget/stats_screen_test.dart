import 'package:all_for_games/app.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_helpers.dart';

const emptyText = 'No games yet. Play one to see your statistics.';

/// Klondike games in time order, then one FreeCell game.
final savedGames = [
  record(
    won: false,
    playTime: const Duration(minutes: 1, seconds: 30),
    moves: 20,
    score: 100,
    endedMinute: 1,
    details: {'stockDraws': 10},
  ),
  record(
    playTime: const Duration(minutes: 2),
    moves: 90,
    undos: 2,
    score: 500,
    endedMinute: 2,
    details: {'stockDraws': 20, 'timeToFirstMoveMs': 4000},
  ),
  record(
    variant: 'draw3',
    playTime: const Duration(minutes: 3),
    moves: 120,
    undos: 1,
    score: 300,
    endedMinute: 3,
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

Future<void> pumpStats(WidgetTester tester, StatsStore store) async {
  // Tall enough to lay out every section of the list.
  useSurface(tester, const Size(1280, 1400));
  await tester.pumpWidget(
    AllForGamesApp(stats: store, initialLocation: '/stats/klondike'),
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

Future<void> tapReset(WidgetTester tester, Finder button) async {
  await tester.tap(find.byKey(const ValueKey('reset-stats')));
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state without a Klondike game', (tester) async {
    await pumpStats(tester, await seededStore([savedGames.last]));

    expect(find.text(emptyText), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-Played')), findsNothing);
    expect(find.text('Recent games'), findsNothing);
  });

  testWidgets('shows the numbers of every saved Klondike game', (tester) async {
    await pumpStats(tester, await seededStore(savedGames));

    expect(find.text(emptyText), findsNothing);
    expectStats({
      'Played': '4',
      'Won': '2',
      'Win rate': '50%',
      'Current streak': '0',
      'Best streak': '2',
      'Time played': '7m 00s',
      'Best time': '2:00',
      'Average win time': '2:30',
      'Fewest moves': '90',
      'Best score': '500',
      'Total moves': '235',
      'Total undos': '3',
      'Stock draws': '16.5',
      'Time to first move': '1s',
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

  testWidgets('variant chips filter the numbers', (tester) async {
    await pumpStats(tester, await seededStore(savedGames));

    await selectVariant(tester, 'draw1');
    expectStats({
      'Played': '3',
      'Won': '1',
      'Win rate': '33%',
      'Current streak': '0',
      'Best streak': '1',
      'Time played': '4m 00s',
      'Best time': '2:00',
      'Fewest moves': '90',
      'Total moves': '115',
      'Stock draws': '11.7',
    });
    expect(find.text('Won · 3:00'), findsNothing);

    await selectVariant(tester, 'draw3');
    expectStats({
      'Played': '1',
      'Won': '1',
      'Win rate': '100%',
      'Current streak': '1',
      'Best time': '3:00',
      'Fewest moves': '120',
      'Best score': '300',
      'Total undos': '1',
      'Stock draws': '31',
      'Time to first move': '2s',
    });
    expect(find.text('Won · 3:00'), findsOneWidget);
    expect(find.text('Won · 2:00'), findsNothing);
    expect(find.textContaining('Abandoned'), findsNothing);

    await selectVariant(tester, 'all');
    expectStats({'Played': '4', 'Won': '2'});
  });

  testWidgets('cancelling the reset keeps the games', (tester) async {
    final store = await seededStore(savedGames);
    await pumpStats(tester, store);

    await tapReset(tester, find.text('Cancel'));

    expectStats({'Played': '4'});
    expect(store.records, hasLength(savedGames.length));
  });

  testWidgets('reset deletes the Klondike games only', (tester) async {
    final store = await seededStore(savedGames);
    await pumpStats(tester, store);

    await tapReset(tester, find.byKey(const ValueKey('confirm-reset')));

    expect(find.text(emptyText), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-Played')), findsNothing);
    expect(store.records.map((r) => r.gameId), ['freecell']);
    final reloaded = await StatsStore.load();
    expect(reloaded.records.map((r) => r.gameId), ['freecell']);
  });
}
