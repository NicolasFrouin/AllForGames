import 'package:all_for_games/achievements/achievements_screen.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/common/format.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Opens the achievements page from the hub, in a window tall enough to lay
/// out every achievement.
Future<void> openAchievements(WidgetTester tester, AppStores stores) async {
  useSurface(tester, const Size(1280, 1600));
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('achievements-button')));
  await tester.pumpAndSettle();
  expect(find.byType(AchievementsScreen), findsOneWidget);
}

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

    expect(textOf('achievements-count'), '4 / 8 unlocked');
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
    expect(textOf('achievements-count'), '2 / 8 unlocked');

    await stores.stats.clear('klondike');
    await tester.pumpAndSettle();

    expect(textOf('achievements-count'), '2 / 8 unlocked');
    expect(textIn('klondike.firstWin', 'progress'), '1 / 1');
    expect(textIn('klondike.wins10', 'progress'), '0 / 10');
  });
}
