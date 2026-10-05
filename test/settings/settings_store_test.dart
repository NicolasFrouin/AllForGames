import 'dart:ui' show Locale;

import 'package:all_for_games/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_stores.dart';

Future<SettingsStore> createStore([Map<String, Object> data = const {}]) {
  useTestStorage(data);
  return SettingsStore.load();
}

void main() {
  test('follows the device language without a saved choice', () async {
    final store = await createStore();
    expect(store.locale, isNull);
  });

  test('keeps the chosen language after a reload', () async {
    final store = await createStore();

    await store.setLocale(const Locale('fr'));
    expect(store.locale, const Locale('fr'));
    expect(await storedLocale(), const Locale('fr'));

    await store.setLocale(const Locale('en'));
    expect(await storedLocale(), const Locale('en'));
  });

  test('the device language removes the saved choice', () async {
    final store = await createStore({SettingsStore.localeKey: 'fr'});
    expect(store.locale, const Locale('fr'));

    await store.setLocale(null);

    expect(store.locale, isNull);
    expect(await SharedPreferencesAsync().getKeys(), isEmpty);
  });

  test('a language the app does not have is ignored', () async {
    final store = await createStore({SettingsStore.localeKey: 'de'});
    expect(store.locale, isNull);
  });

  test('listeners are told after the write, not during the call', () async {
    final store = await createStore();
    var notified = 0;
    store.addListener(() => notified++);

    final saving = store.setLocale(const Locale('fr'));
    expect(notified, 0);
    expect(store.locale, const Locale('fr'));
    await saving;
    expect(notified, 1);
  });

  test('blocked storage still gives a working store', () async {
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final store = await SettingsStore.load();
    expect(store.locale, isNull);

    await store.setLocale(const Locale('fr'));
    expect(store.locale, const Locale('fr'));
    await store.setLocale(null);
    expect(store.locale, isNull);
  });
}
