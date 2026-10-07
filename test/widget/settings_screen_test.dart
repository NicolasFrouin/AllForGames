import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/settings/settings_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_stores.dart';
import 'widget_test_helpers.dart';

/// The hub on stores with [records] and, if not null, the saved [language].
Future<void> pumpHub(
  WidgetTester tester, {
  String? language,
  List<GameRecord> records = const [],
}) async {
  useSurface(tester);
  final stores = await createTestStores({
    ...savedData(records),
    SettingsStore.localeKey: ?language,
  });
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings-button')));
  await tester.pumpAndSettle();
}

/// The selected language on the settings page: `system`, `en` or `fr`.
String selectedLanguage(WidgetTester tester) {
  const prefix = 'language-';
  return tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .where((chip) => chip.selected)
      .map((chip) => (chip.key! as ValueKey<String>).value)
      .singleWhere((key) => key.startsWith(prefix))
      .substring(prefix.length);
}

Future<void> chooseLanguage(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(ValueKey('language-$code')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the hub is in French when the saved language is French', (
    tester,
  ) async {
    await pumpHub(
      tester,
      language: 'fr',
      records: [record(endedMinute: 1), record(won: false, endedMinute: 2)],
    );

    expect(find.text('Jeux'), findsOneWidget);
    expect(find.text('Games'), findsNothing);
    expect(
      textOf('summary-klondike'),
      '2 parties · 50 % gagnées · record 3:00',
    );
    expect(valueIn('overall-time'), '6 min 00 s');
  });

  testWidgets('choosing Français switches the texts and keeps the choice', (
    tester,
  ) async {
    await pumpHub(tester);
    expect(find.text('Games'), findsOneWidget);

    await openSettings(tester);
    expect(selectedLanguage(tester), 'system');
    await chooseLanguage(tester, 'fr');

    expect(find.widgetWithText(AppBar, 'Paramètres'), findsOneWidget);
    expect(await storedLocale(), const Locale('fr'));
    // pageBack looks for the English tooltip.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Jeux'), findsOneWidget);
    expect(textOf('summary-klondike'), 'Pas encore joué · Touchez pour jouer');

    await openSettings(tester);
    expect(selectedLanguage(tester), 'fr');
    await chooseLanguage(tester, 'en');
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(await storedLocale(), const Locale('en'));
  });

  testWidgets('System default removes the saved language', (tester) async {
    await pumpHub(tester, language: 'fr');

    await openSettings(tester);
    expect(selectedLanguage(tester), 'fr');
    await chooseLanguage(tester, 'system');

    // Tests run with an English device.
    expect(selectedLanguage(tester), 'system');
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getString(SettingsStore.localeKey),
      isNull,
    );
  });

  testWidgets('a chip puts the Mahjong tray on its side', (tester) async {
    await pumpHub(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const ValueKey('tray-side-right')));
    await tester.pumpAndSettle();

    expect((await SettingsStore.load()).mahjongTraySide, MahjongTraySide.right);
  });

  testWidgets('the switch turns the Minesweeper vibration on', (tester) async {
    await pumpHub(tester);
    await openSettings(tester);

    await tester.tap(find.byKey(const ValueKey('flag-vibrate')));
    await tester.pumpAndSettle();

    expect((await SettingsStore.load()).minesweeperVibrate, isTrue);
  });

  testWidgets('the slider sets the time to hold a Minesweeper cell for a '
      'flag', (tester) async {
    await pumpHub(tester);
    await openSettings(tester);
    expect(textOf('flag-hold-value'), '0.3 s');

    final slider = find.byKey(const ValueKey('flag-hold'));
    await tester.drag(slider, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(textOf('flag-hold-value'), '0.15 s');
    expect((await SettingsStore.load()).minesweeperFlagHoldMs, 150);

    await tester.drag(slider, const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(textOf('flag-hold-value'), '0.75 s');
    expect((await SettingsStore.load()).minesweeperFlagHoldMs, 750);
  });
}
