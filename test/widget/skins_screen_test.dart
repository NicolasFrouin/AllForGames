import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/skins_screen.dart';
import 'package:all_for_games/skins/tile_styles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

Finder cardBackTile(String id) => find.byKey(ValueKey('card-back-$id'));

Finder tileStyleTile(String id) => find.byKey(ValueKey('tile-style-$id'));

/// The text [text] in [tile].
Finder textIn(Finder tile, String text) =>
    find.descendant(of: tile, matching: find.text(text));

/// Opens the skins page from the hub, in a window tall enough to lay out
/// every skin of a tab.
Future<void> openSkins(WidgetTester tester, AppStores stores) async {
  useSurface(tester, const Size(1280, 3200));
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('skins-button')));
  await tester.pumpAndSettle();
  expect(find.byType(SkinsScreen), findsOneWidget);
}

Future<void> openTab(WidgetTester tester, String kind) async {
  await tester.tap(find.byKey(ValueKey('skins-tab-$kind')));
  await tester.pumpAndSettle();
}

/// Checks that each skin (tile key to the achievement that unlocks it) is
/// under the header of where it comes from: free, or the game of its
/// achievement.
void expectGroupedBySource(
  WidgetTester tester,
  Map<String, String?> unlockedByKey,
) {
  String sourceOf(String? unlockedBy) =>
      unlockedBy == null ? 'free' : achievementById(unlockedBy)!.gameId;
  final sources = [
    'free',
    ...achievementGameIds,
  ].where(unlockedByKey.values.map(sourceOf).contains).toList();
  double top(Finder finder) => tester.getTopLeft(finder).dy;
  final headerTops = [
    for (final source in sources)
      top(find.byKey(ValueKey('skins-group-$source'))),
    double.infinity,
  ];
  expect(headerTops, orderedEquals([...headerTops]..sort()));
  for (final MapEntry(key: key, value: unlockedBy) in unlockedByKey.entries) {
    final group = sources.indexOf(sourceOf(unlockedBy));
    expect(
      top(find.byKey(ValueKey(key))),
      allOf(greaterThan(headerTops[group]), lessThan(headerTops[group + 1])),
      reason: key,
    );
  }
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
    await openTab(tester, 'tileStyle');
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
    await openTab(tester, 'tileStyle');
    final jade = tileStyleTile('jade');
    expect(textIn(jade, 'Clean table'), findsNothing, reason: 'unlocked');
    expect(textIn(tileStyleTile('bamboo'), 'Turtle power'), findsOneWidget);

    await tapTile(tester, jade);

    expect(textIn(jade, 'Selected'), findsOneWidget);
    expect(textIn(tileStyleTile('classic'), 'Selected'), findsNothing);
    expect(await storedTileStyleId(), 'jade');
    await openTab(tester, 'cardBack');
    expect(textIn(cardBackTile('classic'), 'Selected'), findsOneWidget);
    expect(await storedCardBackId(), 'classic');
  });

  testWidgets('the skins of each tab are grouped by where they come from', (
    tester,
  ) async {
    final stores = await seededStores([]);
    await openSkins(tester, stores);
    expectGroupedBySource(tester, {
      for (final skin in cardBacks) 'card-back-${skin.id}': skin.unlockedBy,
    });
    // A Klondike card back, under the Klondike header and above the FreeCell
    // one.
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(cardBackTile('crimson')),
      allOf(
        greaterThan(top(find.byKey(const ValueKey('skins-group-klondike')))),
        lessThan(top(find.byKey(const ValueKey('skins-group-freecell')))),
      ),
    );

    await openTab(tester, 'tileStyle');
    expect(cardBackTile('classic'), findsNothing);
    expectGroupedBySource(tester, {
      for (final style in tileStyles)
        'tile-style-${style.id}': style.unlockedBy,
    });
  });

  const locations = {
    '/skins?kind=tileStyle': 'tile-style-classic',
    '/skins?kind=cardBack': 'card-back-classic',
    '/skins?kind=unknown': 'card-back-classic',
    '/skins': 'card-back-classic',
  };
  for (final MapEntry(key: location, value: shownKey) in locations.entries) {
    testWidgets('$location opens the tab of $shownKey', (tester) async {
      final stores = await seededStores([]);
      useSurface(tester, const Size(1280, 3200));
      await tester.pumpWidget(
        AllForGamesApp(stores: stores, initialLocation: location),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(shownKey)), findsOneWidget);
      final other = shownKey.startsWith('card-back')
          ? tileStyleTile('classic')
          : cardBackTile('classic');
      expect(other, findsNothing);
    });
  }

  testWidgets('a new ?kind= on the open page selects its tab', (tester) async {
    final stores = await seededStores([]);
    await openSkins(tester, stores);
    expect(cardBackTile('classic'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(SkinsScreen)))
        .go('/skins?kind=tileStyle');
    await tester.pumpAndSettle();

    expect(tileStyleTile('classic'), findsOneWidget);
    expect(cardBackTile('classic'), findsNothing);
  });
}
