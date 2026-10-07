import 'dart:ui' show Locale;

import 'package:all_for_games/games/freecell/freecell_difficulty.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
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

  test('the tile style is classic without a saved choice', () async {
    final store = await createStore();
    expect(store.tileStyleId, 'classic');
  });

  test('keeps the chosen tile style after a reload', () async {
    final store = await createStore();

    final saving = store.setTileStyle('ebony');
    expect(store.tileStyleId, 'ebony');
    await saving;
    expect((await SettingsStore.load()).tileStyleId, 'ebony');
    expect(await SharedPreferencesAsync().getAll(), {
      SettingsStore.tileStyleKey: 'ebony',
    });

    await store.setTileStyle('classic');
    expect((await SettingsStore.load()).tileStyleId, 'classic');
  });

  test('a tile style the app does not have is classic', () async {
    final store = await createStore({SettingsStore.tileStyleKey: 'neon'});
    expect(store.tileStyleId, 'classic');

    await store.setTileStyle('neon');
    expect(store.tileStyleId, 'classic');
    expect((await SettingsStore.load()).tileStyleId, 'classic');
  });

  test(
    'the Minesweeper theme is classic until one is chosen, and stays',
    () async {
      final store = await createStore();
      expect(store.minesweeperThemeId, 'classic');

      final saving = store.setMinesweeperTheme('retro');
      expect(store.minesweeperThemeId, 'retro');
      await saving;
      expect((await SettingsStore.load()).minesweeperThemeId, 'retro');
      expect(await SharedPreferencesAsync().getAll(), {
        SettingsStore.minesweeperThemeKey: 'retro',
      });
    },
  );

  test('a Minesweeper theme the app does not have is classic', () async {
    final store = await createStore({
      SettingsStore.minesweeperThemeKey: 'neon',
    });
    expect(store.minesweeperThemeId, 'classic');

    await store.setMinesweeperTheme('neon');
    expect((await SettingsStore.load()).minesweeperThemeId, 'classic');
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

  test(
    'keeps the mode of the last new Mahjong game; unknown is classic',
    () async {
      final store = await createStore();
      expect(store.mahjongMode, MahjongMode.classic);

      await store.setMahjongMode(MahjongMode.tray);

      expect((await SettingsStore.load()).mahjongMode, MahjongMode.tray);
      expect(await SharedPreferencesAsync().getAll(), {
        SettingsStore.mahjongModeKey: 'tray',
      });
      final unknown = await createStore({
        SettingsStore.mahjongModeKey: 'tower',
      });
      expect(unknown.mahjongMode, MahjongMode.classic);
    },
  );

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

  test('keeps the difficulty of the last new Spider game', () async {
    final store = await createStore();
    expect(store.spiderDifficulty, SpiderDifficulty.medium);

    final saving = store.setSpiderDifficulty(SpiderDifficulty.hard);
    expect(store.spiderDifficulty, SpiderDifficulty.hard);
    await saving;

    expect(
      (await SettingsStore.load()).spiderDifficulty,
      SpiderDifficulty.hard,
    );
    expect(await SharedPreferencesAsync().getAll(), {
      SettingsStore.spiderDifficultyKey: 'hard',
    });
  });

  test('an unknown Spider difficulty is Medium', () async {
    final store = await createStore({
      SettingsStore.spiderDifficultyKey: 'extreme',
    });

    expect(store.spiderDifficulty, SpiderDifficulty.medium);
  });

  test('the Minesweeper hold time is 300 ms without a saved choice', () async {
    final store = await createStore();
    expect(store.minesweeperFlagHoldMs, 300);
  });

  test('keeps the Minesweeper hold time after a reload', () async {
    final store = await createStore();

    await store.setMinesweeperFlagHold(450);

    expect(store.minesweeperFlagHoldMs, 450);
    expect((await SettingsStore.load()).minesweeperFlagHoldMs, 450);
  });

  test('a Minesweeper hold time out of the range is limited to it', () async {
    final store = await createStore({SettingsStore.minesweeperFlagHoldKey: 5});
    expect(store.minesweeperFlagHoldMs, SettingsStore.minFlagHoldMs);

    await store.setMinesweeperFlagHold(5000);
    expect(store.minesweeperFlagHoldMs, SettingsStore.maxFlagHoldMs);
  });

  test(
    'the phone does not vibrate for a Minesweeper flag by default',
    () async {
      final store = await createStore();
      expect(store.minesweeperVibrate, isFalse);

      await store.setMinesweeperVibrate(true);

      expect(store.minesweeperVibrate, isTrue);
      expect((await SettingsStore.load()).minesweeperVibrate, isTrue);
    },
  );

  test(
    'the Mahjong tray is at the top by default, and keeps its side',
    () async {
      final store = await createStore({SettingsStore.mahjongTraySideKey: 'up'});
      expect(store.mahjongTraySide, MahjongTraySide.top);

      await store.setMahjongTraySide(MahjongTraySide.left);

      expect(store.mahjongTraySide, MahjongTraySide.left);
      expect(
        (await SettingsStore.load()).mahjongTraySide,
        MahjongTraySide.left,
      );
    },
  );

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

    final savingStyle = store.setTileStyle('jade');
    expect(notified, 3);
    expect(store.tileStyleId, 'jade');
    await savingStyle;
    expect(notified, 4);
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
    await store.setTileStyle('golden');
    expect(store.tileStyleId, 'golden');
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
    await store.setSpiderDifficulty(SpiderDifficulty.easy);
    expect(store.spiderDifficulty, SpiderDifficulty.easy);
    await store.setMinesweeperFlagHold(200);
    expect(store.minesweeperFlagHoldMs, 200);
  });
}
