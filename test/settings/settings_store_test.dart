import 'dart:ui' show Locale;

import 'package:all_for_games/games/freecell/freecell_difficulty.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
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

  test('the card back is classic without a saved choice', () async {
    final store = await createStore();
    expect(store.cardBackId, 'classic');
  });

  test('keeps the chosen card back after a reload', () async {
    final store = await createStore();

    await store.setCardBack('crimson');
    expect(store.cardBackId, 'crimson');
    expect(await storedCardBackId(), 'crimson');

    await store.setCardBack('classic');
    expect(await storedCardBackId(), 'classic');
  });

  test('a card back the app does not have is classic', () async {
    final store = await createStore({SettingsStore.cardBackKey: 'neon'});
    expect(store.cardBackId, 'classic');

    await store.setCardBack('neon');
    expect(store.cardBackId, 'classic');
    expect(await storedCardBackId(), 'classic');
  });

  test(
    'a new Klondike game is Draw 1, Medium without a saved choice',
    () async {
      final store = await createStore();
      expect(store.klondikeDrawCount, 1);
      expect(store.klondikeDifficulty, KlondikeDifficulty.medium);
    },
  );

  test('keeps the options of the last new Klondike game', () async {
    final store = await createStore();

    await store.setKlondikeNewGame(
      drawCount: 3,
      difficulty: KlondikeDifficulty.hard,
    );
    expect(store.klondikeDrawCount, 3);
    expect(store.klondikeDifficulty, KlondikeDifficulty.hard);

    final reloaded = await SettingsStore.load();
    expect(reloaded.klondikeDrawCount, 3);
    expect(reloaded.klondikeDifficulty, KlondikeDifficulty.hard);
    expect(await SharedPreferencesAsync().getAll(), {
      SettingsStore.klondikeDrawCountKey: 3,
      SettingsStore.klondikeDifficultyKey: 'hard',
    });
  });

  test('unknown Klondike options are the defaults', () async {
    final store = await createStore({
      SettingsStore.klondikeDrawCountKey: 2,
      SettingsStore.klondikeDifficultyKey: 'extreme',
    });
    expect(store.klondikeDrawCount, 1);
    expect(store.klondikeDifficulty, KlondikeDifficulty.medium);

    await store.setKlondikeNewGame(
      drawCount: 5,
      difficulty: KlondikeDifficulty.easy,
    );
    expect(store.klondikeDrawCount, 1);
    expect((await SettingsStore.load()).klondikeDrawCount, 1);
  });

  test('keeps the difficulty of the last new Mahjong game', () async {
    final store = await createStore();
    expect(store.mahjongDifficulty, MahjongDifficulty.medium);

    final saving = store.setMahjongDifficulty(MahjongDifficulty.hard);
    expect(store.mahjongDifficulty, MahjongDifficulty.hard);
    await saving;

    expect(
      (await SettingsStore.load()).mahjongDifficulty,
      MahjongDifficulty.hard,
    );
    expect(await SharedPreferencesAsync().getAll(), {
      SettingsStore.mahjongDifficultyKey: 'hard',
    });
  });

  test('an unknown Mahjong difficulty is Medium', () async {
    final store = await createStore({
      SettingsStore.mahjongDifficultyKey: 'extreme',
    });

    expect(store.mahjongDifficulty, MahjongDifficulty.medium);
  });

  test('keeps the difficulty of the last new FreeCell game', () async {
    final store = await createStore();
    expect(store.freecellDifficulty, FreeCellDifficulty.medium);

    final saving = store.setFreecellDifficulty(FreeCellDifficulty.hard);
    expect(store.freecellDifficulty, FreeCellDifficulty.hard);
    await saving;

    expect(
      (await SettingsStore.load()).freecellDifficulty,
      FreeCellDifficulty.hard,
    );
    expect(await SharedPreferencesAsync().getAll(), {
      SettingsStore.freecellDifficultyKey: 'hard',
    });
  });

  test('an unknown FreeCell difficulty is Medium', () async {
    final store = await createStore({
      SettingsStore.freecellDifficultyKey: 'extreme',
    });

    expect(store.freecellDifficulty, FreeCellDifficulty.medium);
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

    final savingBack = store.setCardBack('crimson');
    expect(notified, 1);
    expect(store.cardBackId, 'crimson');
    await savingBack;
    expect(notified, 2);

    final savingOptions = store.setKlondikeNewGame(
      drawCount: 3,
      difficulty: KlondikeDifficulty.easy,
    );
    expect(notified, 2);
    expect(store.klondikeDrawCount, 3);
    await savingOptions;
    expect(notified, 3);
  });

  test('blocked storage still gives a working store', () async {
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final store = await SettingsStore.load();
    expect(store.locale, isNull);

    await store.setLocale(const Locale('fr'));
    expect(store.locale, const Locale('fr'));
    await store.setLocale(null);
    expect(store.locale, isNull);
    await store.setCardBack('crimson');
    expect(store.cardBackId, 'crimson');
    expect(store.klondikeDifficulty, KlondikeDifficulty.medium);
    await store.setKlondikeNewGame(
      drawCount: 3,
      difficulty: KlondikeDifficulty.hard,
    );
    expect(store.klondikeDrawCount, 3);
    expect(store.klondikeDifficulty, KlondikeDifficulty.hard);
    await store.setMahjongDifficulty(MahjongDifficulty.easy);
    expect(store.mahjongDifficulty, MahjongDifficulty.easy);
    await store.setFreecellDifficulty(FreeCellDifficulty.easy);
    expect(store.freecellDifficulty, FreeCellDifficulty.easy);
  });
}
