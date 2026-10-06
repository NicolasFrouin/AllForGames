import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/achievements/achievements_screen.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/common/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Finder tile(String id) => find.byKey(ValueKey('achievement-$id'));

/// The text keyed [key] in the tile of the achievement [id], if any.
String? textIn(String id, String key) {
  final finder = find.descendant(
    of: tile(id),
    matching: find.byKey(ValueKey(key)),
  );
  return finder.evaluate().isEmpty
      ? null
      : (finder.evaluate().single.widget as Text).data;
}

Finder tab(String gameId) => find.byKey(ValueKey('achievement-tab-$gameId'));

/// Opens the achievements page from the hub, in a window tall enough to lay
/// out every achievement of a tab.
Future<void> openAchievements(WidgetTester tester, AppStores stores) async {
  useSurface(tester, const Size(1280, 2400));
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('achievements-button')));
  await tester.pumpAndSettle();
  expect(find.byType(AchievementsScreen), findsOneWidget);
}

Future<void> openTab(WidgetTester tester, String gameId) async {
  await tester.tap(tab(gameId));
  await tester.pumpAndSettle();
}

/// The ids of the achievements on screen.
Set<String> shownIds() => {
  for (final achievement in achievements)
    if (tile(achievement.id).evaluate().isNotEmpty) achievement.id,
};

void main() {
  testWidgets('shows the progress, unlock dates and rewards', (tester) async {
    final firstWinAt = DateTime.utc(2026, 3, 4, 5, 6);
    final stores = await createTestStores({
      // Three fast wins in a row, without undo.
      ...savedData([
        record(endedMinute: 1),
        record(endedMinute: 2),
        record(endedMinute: 3),
      ]),
      ...savedUnlockData({'klondike.firstWin': firstWinAt}),
    });
    await openAchievements(tester, stores);

    expect(textOf('achievements-count'), '4 / ${achievements.length}');
    expect(textIn('klondike.wins10', 'progress'), '3 / 10');
    expect(textIn('klondike.wins10', 'unlocked-on'), isNull);
    expect(textIn('klondike.streak3', 'progress'), '3 / 3');
    expect(textIn('klondike.firstWin', 'progress'), '1 / 1');
    expect(
      textIn('klondike.firstWin', 'unlocked-on'),
      'Unlocked on ${formatDateTime(firstWinAt, 'en')}',
    );
    expect(
      textIn('klondike.streak3', 'unlocked-on'),
      startsWith('Unlocked on'),
    );
    expect(
      find.descendant(
        of: tile('klondike.firstWin'),
        matching: find.text('Reward: Crimson card back'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unlocked achievement stays full when the stats are reset', (
    tester,
  ) async {
    final stores = await seededStores([record(undos: 1)]);
    await openAchievements(tester, stores);
    expect(textOf('achievements-count'), '2 / ${achievements.length}');

    await stores.stats.clear('klondike');
    await tester.pumpAndSettle();

    expect(textOf('achievements-count'), '2 / ${achievements.length}');
    expect(textIn('klondike.firstWin', 'progress'), '1 / 1');
    expect(textIn('klondike.wins10', 'progress'), '0 / 10');
  });

  testWidgets('one tab per game, with its count and only its achievements', (
    tester,
  ) async {
    final stores = await seededStores([
      // A fast Klondike win without undo: 3 of 8.
      record(endedMinute: 1),
      // A Mahjong win on the Turtle, with hints: 2 of 10.
      record(
        gameId: 'mahjong',
        variant: 'turtle',
        difficulty: 'medium',
        undos: 3,
        playTime: const Duration(minutes: 12),
        endedMinute: 2,
        details: {'hints': 2, 'bestCombo': 4},
      ),
    ]);
    await openAchievements(tester, stores);

    expect(textOf('achievements-count'), '5 / ${achievements.length}');
    // The tabs follow achievementGameIds.
    final lefts = [
      for (final gameId in achievementGameIds)
        tester.getTopLeft(tab(gameId)).dx,
    ];
    expect(lefts, orderedEquals([...lefts]..sort()));
    const tabs = {
      'klondike': ('Klondike', '3/8', '3 / 8 unlocked'),
      'freecell': ('FreeCell', '0/6', '0 / 6 unlocked'),
      'spider': ('Spider', '0/6', '0 / 6 unlocked'),
      'tripeaks': ('TriPeaks', '0/6', '0 / 6 unlocked'),
      'mahjong': ('Mahjong', '2/10', '2 / 10 unlocked'),
      'minesweeper': ('Minesweeper', '0/6', '0 / 6 unlocked'),
      'all': ('All games', '0/3', '0 / 3 unlocked'),
    };
    for (final MapEntry(key: gameId, value: (title, tabCount, count))
        in tabs.entries) {
      await openTab(tester, gameId);
      for (final text in [title, tabCount]) {
        expect(
          find.descendant(of: tab(gameId), matching: find.text(text)),
          findsOneWidget,
          reason: gameId,
        );
      }
      expect(textOf('achievements-count-$gameId'), count, reason: gameId);
      expect(shownIds(), {
        for (final achievement in achievements)
          if (achievement.gameId == gameId) achievement.id,
      }, reason: gameId);
    }
    expect(textIn('all.everyGame', 'progress'), '2 / 6');

    await openTab(tester, 'mahjong');
    expect(
      find.descendant(
        of: tile('mahjong.turtleWin'),
        matching: find.text('Reward: Bamboo tiles'),
      ),
      findsOneWidget,
    );
  });

  const locations = {
    '/achievements?game=mahjong': 'mahjong',
    '/achievements?game=all': 'all',
    '/achievements?game=unknown': 'klondike',
    '/achievements': 'klondike',
  };
  for (final MapEntry(key: location, value: gameId) in locations.entries) {
    testWidgets('$location opens the $gameId tab', (tester) async {
      final stores = await seededStores([]);
      useSurface(tester, const Size(1280, 2400));
      await tester.pumpWidget(
        AllForGamesApp(stores: stores, initialLocation: location),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('achievements-count-$gameId')),
        findsOneWidget,
      );
      expect(shownIds(), {
        for (final achievement in achievements)
          if (achievement.gameId == gameId) achievement.id,
      });
    });
  }

  testWidgets('a new ?game= on the open page selects its tab', (tester) async {
    final stores = await seededStores([]);
    await openAchievements(tester, stores);
    expect(
      find.byKey(const ValueKey('achievements-count-klondike')),
      findsOneWidget,
    );

    GoRouter.of(tester.element(find.byType(AchievementsScreen)))
        .go('/achievements?game=spider');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('achievements-count-spider')),
      findsOneWidget,
    );
    expect(tile('spider.firstWin'), findsOneWidget);
    expect(tile('klondike.firstWin'), findsNothing);
  });
}
