import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/game_catalog.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/hub/hub_screen.dart';
import 'package:all_for_games/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_helpers.dart';

const comingSoon = <String>[];

Future<void> pumpHub(WidgetTester tester, AppStores stores) async {
  useSurface(tester);
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
}

Finder tile(String id) => find.byKey(ValueKey('game-$id'));

Finder resumeLine(String id) => find.byKey(ValueKey('resume-$id'));

void main() {
  testWidgets('shows a tile for every game of the catalog', (tester) async {
    await pumpHub(tester, await seededStores([]));

    for (final game in gameCatalog) {
      expect(tile(game.id), findsOneWidget, reason: game.id);
      final playable = game.isAvailable ? findsOneWidget : findsNothing;
      expect(find.byKey(ValueKey('stats-${game.id}')), playable);
      expect(find.byKey(ValueKey('summary-${game.id}')), playable);
    }
    expect(find.text('Coming soon'), findsNWidgets(comingSoon.length));
    expect(textOf('summary-klondike'), 'Not played yet · Tap to play');
  });

  testWidgets('summary and overall chips reflect the saved games', (
    tester,
  ) async {
    final stores = await seededStores([
      record(playTime: const Duration(minutes: 3, seconds: 5), endedMinute: 1),
      record(
        variant: 'draw3',
        playTime: const Duration(minutes: 4, seconds: 10),
        endedMinute: 2,
      ),
      record(won: false, playTime: const Duration(minutes: 1), endedMinute: 3),
      record(gameId: 'freecell', playTime: const Duration(minutes: 2)),
    ]);
    await pumpHub(tester, stores);

    expect(textOf('summary-klondike'), '3 played · 67% won · best 3:05');
    expect(valueIn('overall-played'), '4');
    expect(valueIn('overall-won'), '3');
    expect(valueIn('overall-time'), '10m 15s');
  });

  testWidgets('tapping Klondike opens a new game', (tester) async {
    await pumpHub(tester, await seededStores([]));

    await tester.tap(tile('klondike'));
    await tester.pumpAndSettle();

    expect(find.byType(KlondikeScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Klondike'), findsOneWidget);
    expect(textOf('moves-value'), '0');
  });

  testWidgets('tapping a coming-soon game stays on the hub', (tester) async {
    await pumpHub(tester, await seededStores([]));

    for (final id in comingSoon) {
      await tester.tap(tile(id));
      await tester.pumpAndSettle();

      expect(find.byType(HubScreen), findsOneWidget, reason: id);
      expect(find.byTooltip('Back'), findsNothing, reason: id);
    }
  });

  testWidgets('the stats button opens the statistics of the game', (
    tester,
  ) async {
    final stores = await seededStores([
      record(endedMinute: 1),
      record(won: false, endedMinute: 2),
    ]);
    await pumpHub(tester, stores);

    await tester.tap(find.byKey(const ValueKey('stats-klondike')));
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Klondike statistics'), findsOneWidget);
    expect(valueIn('stat-played'), '2');
    expect(valueIn('stat-won'), '1');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsNothing);
    expect(tile('klondike'), findsOneWidget);
  });

  testWidgets('a game in progress shows on its tile with its moves and time', (
    tester,
  ) async {
    await pumpHub(
      tester,
      await seededStores([record(endedMinute: 1)], [savedGame()]),
    );

    expect(textOf('resume-klondike'), 'Continue · 12 moves · 3:05');
    expect(textOf('summary-klondike'), startsWith('1 played'));
  });

  testWidgets('a saved game without a move is not shown as in progress', (
    tester,
  ) async {
    await pumpHub(tester, await seededStores([], [savedGame(moves: 0)]));

    expect(resumeLine('klondike'), findsNothing);
  });

  testWidgets('a game left after a move shows as in progress, not as played', (
    tester,
  ) async {
    final stores = await seededStores([]);
    await pumpHub(tester, stores);

    await tester.tap(tile('klondike'));
    await tester.pumpAndSettle();
    // The stock cards cover the stock slot.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('stock'))));
    await tester.pumpAndSettle();
    expect(textOf('moves-value'), '1');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(KlondikeScreen), findsNothing);
    expect(textOf('resume-klondike'), startsWith('Continue · 1 move · 0:0'));
    expect(textOf('summary-klondike'), 'Not played yet · Tap to play');
    expect(valueIn('overall-played'), '0');
    expect(stores.stats.records, isEmpty);

    await tester.tap(tile('klondike'));
    await tester.pumpAndSettle();
    expect(textOf('moves-value'), '1');
  });
}
