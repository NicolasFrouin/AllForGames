import 'package:all_for_games/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_helpers.dart';

void main() {
  // A layout overflow is a test failure, so rendering each page is the check.
  for (final location in ['/', '/klondike?seed=1', '/stats/klondike']) {
    testWidgets('$location fits a small phone with large text', (tester) async {
      useSurface(tester, const Size(360, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final stores = await seededStores(
        [record(endedMinute: 1), record(won: false, endedMinute: 2)],
        // The hub tile shows its longest text: a game in progress.
        [
          savedGame(
            moves: 999,
            playTime: const Duration(hours: 9, minutes: 59),
          ),
        ],
      );
      await tester.pumpWidget(
        AllForGamesApp(stores: stores, initialLocation: location),
      );
      await tester.pumpAndSettle();
    });
  }
}
