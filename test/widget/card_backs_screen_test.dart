import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/card_backs_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Finder tile(String id) => find.byKey(ValueKey('card-back-$id'));

/// The text [text] in the tile of the card back [id].
Finder textIn(String id, String text) =>
    find.descendant(of: tile(id), matching: find.text(text));

/// Opens the card backs page from the hub.
Future<void> openCardBacks(WidgetTester tester, AppStores stores) async {
  useSurface(tester);
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('card-backs-button')));
  await tester.pumpAndSettle();
  expect(find.byType(CardBacksScreen), findsOneWidget);
}

Future<void> tapTile(WidgetTester tester, String id) async {
  await tester.tap(tile(id));
  await tester.pumpAndSettle();
}

/// The skin ids of the face-down cards on screen.
Set<String> faceDownSkins(WidgetTester tester) => {
  for (final view in tester.widgetList<CardBackView>(find.byType(CardBackView)))
    view.skin.id,
};

void main() {
  testWidgets('a locked card back cannot be selected', (tester) async {
    final stores = await seededStores([]);
    await openCardBacks(tester, stores);
    expect(textIn('classic', 'Selected'), findsOneWidget);
    expect(textIn('emerald', 'Seasoned player'), findsOneWidget);
    expect(textIn('emerald', '0 / 10'), findsOneWidget);

    await tapTile(tester, 'emerald');

    expect(find.text('Unlock it with: Seasoned player'), findsOneWidget);
    expect(textIn('classic', 'Selected'), findsOneWidget);
    expect(textIn('emerald', 'Selected'), findsNothing);
    expect(stores.settings.cardBackId, 'classic');
    expect(await storedCardBackId(), 'classic');
  });

  testWidgets(
    'a win unlocks crimson: selected, it stays and the board uses it',
    (tester) async {
      final stores = await seededStores([record(undos: 1)]);
      await openCardBacks(tester, stores);
      expect(textIn('crimson', 'First win'), findsNothing, reason: 'unlocked');
      expect(textIn('emerald', '1 / 10'), findsOneWidget);

      await tapTile(tester, 'crimson');

      expect(textIn('crimson', 'Selected'), findsOneWidget);
      expect(textIn('classic', 'Selected'), findsNothing);
      expect(await storedCardBackId(), 'crimson');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-klondike')));
      await tester.pumpAndSettle();
      expect(find.byType(KlondikeScreen), findsOneWidget);
      expect(faceDownSkins(tester), {'crimson'});
    },
  );
}
