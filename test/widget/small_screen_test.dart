import 'package:all_for_games/app.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

const textScales = [0.85, 1.0, 1.3, 2.0];

void useTextScale(WidgetTester tester, double textScale) {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  // A layout overflow is a test failure, so rendering each page is the check.
  // The windows of the hub and of the lists are tall so that every tile is
  // laid out.
  const pages = {
    '/': Size(360, 1400),
    '/klondike?seed=1': Size(360, 640),
    '/freecell?seed=1': Size(360, 640),
    '/mahjong?seed=1': Size(360, 640),
    '/mahjong?seed=1&difficulty=easy': Size(360, 640),
    '/spider?seed=1': Size(360, 640),
    '/stats/mahjong': Size(360, 640),
    '/stats/spider': Size(360, 640),
    '/stats/klondike': Size(360, 640),
    '/stats/freecell': Size(360, 640),
    '/achievements': Size(360, 19500),
    '/skins': Size(360, 7500),
  };
  for (final MapEntry(key: location, value: size) in pages.entries) {
    for (final language in ['en', 'fr']) {
      for (final textScale in textScales) {
        testWidgets(
          '$location fits a small phone, $language, text x$textScale',
          (tester) async {
            useSurface(tester, size);
            useTextScale(tester, textScale);

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
              // The win unlocks it: the skins page shows a selected, an
              // unlocked and a locked back.
              SettingsStore.cardBackKey: 'crimson',
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

  for (final language in ['en', 'fr']) {
    for (final textScale in textScales) {
      testWidgets('the new game sheet fits a small phone, $language, '
          'text x$textScale', (tester) async {
        useSurface(tester, const Size(360, 640));
        useTextScale(tester, textScale);
        final stores = await createTestStores({
          SettingsStore.localeKey: language,
        });
        await tester.pumpWidget(
          AllForGamesApp(stores: stores, initialLocation: '/klondike?seed=1'),
        );
        await tester.pumpAndSettle();
        // A move, so the sheet also says that the game counts as abandoned.
        await tester.tap(
          find.byKey(const ValueKey('stock')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(textOf('moves-value'), '1');

        await tester.tap(find.byKey(const ValueKey('new-game')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('new-game-abandons')), findsOneWidget);
        final deal = find.byKey(const ValueKey('new-game-deal'));
        await tester.ensureVisible(deal);
        await tester.pumpAndSettle();
        await tester.tap(deal);
        await tester.pumpAndSettle();
        expect(textOf('moves-value'), '0');
      });
    }
  }
}
