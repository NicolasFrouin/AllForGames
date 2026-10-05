import 'package:all_for_games/app.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

void main() {
  // A layout overflow is a test failure, so rendering each page is the check.
  // The hub window is tall so that every game tile is laid out.
  const pages = {
    '/': Size(360, 1400),
    '/klondike?seed=1': Size(360, 640),
    '/stats/klondike': Size(360, 640),
  };
  for (final MapEntry(key: location, value: size) in pages.entries) {
    for (final language in ['en', 'fr']) {
      for (final textScale in [0.85, 1.0, 1.3, 2.0]) {
        testWidgets(
          '$location fits a small phone, $language, text x$textScale',
          (tester) async {
            useSurface(tester, size);
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final stores = await createTestStores({
              ...savedData([
                record(endedMinute: 1),
                record(won: false, endedMinute: 2),
              ]),
              // The hub tile shows its longest text: a game in progress.
              ...savedGameData([
                savedGame(
                  moves: 999,
                  playTime: const Duration(hours: 9, minutes: 59),
                ),
              ]),
              SettingsStore.localeKey: language,
            });
            await tester.pumpWidget(
              AllForGamesApp(stores: stores, initialLocation: location),
            );
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
