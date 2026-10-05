import 'package:all_for_games/app.dart';
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

Future<void> openLanguageMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('language-menu')));
  await tester.pumpAndSettle();
}

/// The checked item of the open language menu: `system`, `en` or `fr`.
String checkedLanguage(WidgetTester tester) => tester
    .widgetList<CheckedPopupMenuItem<String>>(
      find.byType(CheckedPopupMenuItem<String>),
    )
    .singleWhere((item) => item.checked)
    .value!;

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

    await openLanguageMenu(tester);
    expect(checkedLanguage(tester), 'system');
    await chooseLanguage(tester, 'fr');

    expect(find.text('Jeux'), findsOneWidget);
    expect(textOf('summary-klondike'), 'Pas encore joué · Touchez pour jouer');
    expect(await storedLocale(), const Locale('fr'));

    await openLanguageMenu(tester);
    expect(checkedLanguage(tester), 'fr');
    await chooseLanguage(tester, 'en');
    expect(find.text('Games'), findsOneWidget);
    expect(await storedLocale(), const Locale('en'));
  });

  testWidgets('System default removes the saved language', (tester) async {
    await pumpHub(tester, language: 'fr');

    await openLanguageMenu(tester);
    expect(checkedLanguage(tester), 'fr');
    await chooseLanguage(tester, 'system');

    // Tests run with an English device.
    expect(find.text('Games'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getString(SettingsStore.localeKey),
      isNull,
    );
  });
}
