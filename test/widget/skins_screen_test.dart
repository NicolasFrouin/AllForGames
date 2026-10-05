import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/skins_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Finder cardBackTile(String id) => find.byKey(ValueKey('card-back-$id'));

Finder tileStyleTile(String id) => find.byKey(ValueKey('tile-style-$id'));

/// The text [text] in [tile].
Finder textIn(Finder tile, String text) =>
    find.descendant(of: tile, matching: find.text(text));

/// Opens the skins page from the hub, in a window tall enough to lay out
/// every skin.
Future<void> openSkins(WidgetTester tester, AppStores stores) async {
  useSurface(tester, const Size(1280, 2400));
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('skins-button')));
  await tester.pumpAndSettle();
  expect(find.byType(SkinsScreen), findsOneWidget);
}

Future<void> tapTile(WidgetTester tester, Finder tile) async {
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// The skin ids of the face-down cards on screen.
Set<String> faceDownSkins(WidgetTester tester) => {
  for (final view in tester.widgetList<CardBackView>(find.byType(CardBackView)))
    view.skin.id,
};

Future<String> storedTileStyleId() async =>
    (await SettingsStore.load()).tileStyleId;

void main() {
  testWidgets('a locked card back cannot be selected', (tester) async {
    final stores = await seededStores([]);
    await openSkins(tester, stores);
    final emerald = cardBackTile('emerald');
    expect(textIn(cardBackTile('classic'), 'Selected'), findsOneWidget);
    expect(textIn(emerald, 'Seasoned player'), findsOneWidget);
    expect(textIn(emerald, '0 / 10'), findsOneWidget);

    await tapTile(tester, emerald);

    expect(find.text('Unlock it with: Seasoned player'), findsOneWidget);
    expect(textIn(cardBackTile('classic'), 'Selected'), findsOneWidget);
    expect(textIn(emerald, 'Selected'), findsNothing);
    expect(stores.settings.cardBackId, 'classic');
    expect(await storedCardBackId(), 'classic');
  });

  testWidgets(
    'a win unlocks crimson: selected, it stays and the board uses it',
    (tester) async {
      final stores = await seededStores([record(undos: 1)]);
      await openSkins(tester, stores);
      final crimson = cardBackTile('crimson');
      expect(textIn(crimson, 'First win'), findsNothing, reason: 'unlocked');
      expect(textIn(cardBackTile('emerald'), '1 / 10'), findsOneWidget);

      await tapTile(tester, crimson);

      expect(textIn(crimson, 'Selected'), findsOneWidget);
      expect(textIn(cardBackTile('classic'), 'Selected'), findsNothing);
      expect(await storedCardBackId(), 'crimson');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-klondike')));
      await tester.pumpAndSettle();
      expect(find.byType(KlondikeScreen), findsOneWidget);
      expect(faceDownSkins(tester), {'crimson'});
    },
  );

  testWidgets('a locked tile style cannot be selected', (tester) async {
    final stores = await seededStores([]);
    await openSkins(tester, stores);
    final jade = tileStyleTile('jade');
    expect(textIn(tileStyleTile('classic'), 'Selected'), findsOneWidget);
    expect(textIn(jade, 'Clean table'), findsOneWidget);
    expect(textIn(jade, '0 / 1'), findsOneWidget);

    await tapTile(tester, jade);

    expect(find.text('Unlock it with: Clean table'), findsOneWidget);
    expect(textIn(tileStyleTile('classic'), 'Selected'), findsOneWidget);
    expect(stores.settings.tileStyleId, 'classic');
    expect(await storedTileStyleId(), 'classic');
  });

  testWidgets('a Mahjong win unlocks jade: selected, it stays', (tester) async {
    final stores = await seededStores([
      record(
        gameId: 'mahjong',
        variant: 'pyramid',
        difficulty: 'easy',
        details: {'hints': 2, 'bestCombo': 3},
      ),
    ]);
    await openSkins(tester, stores);
    final jade = tileStyleTile('jade');
    expect(textIn(jade, 'Clean table'), findsNothing, reason: 'unlocked');
    expect(textIn(tileStyleTile('bamboo'), 'Turtle power'), findsOneWidget);

    await tapTile(tester, jade);

    expect(textIn(jade, 'Selected'), findsOneWidget);
    expect(textIn(tileStyleTile('classic'), 'Selected'), findsNothing);
    expect(textIn(cardBackTile('classic'), 'Selected'), findsOneWidget);
    expect(await storedTileStyleId(), 'jade');
    expect(await storedCardBackId(), 'classic');
  });
}
