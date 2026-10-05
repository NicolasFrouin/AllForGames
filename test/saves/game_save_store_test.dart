import 'package:all_for_games/saves/game_save_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_stores.dart';

SavedGame saved(String gameId, {int moves = 12}) => SavedGame(
  gameId: gameId,
  moves: moves,
  playTime: const Duration(minutes: 3, seconds: 5),
  savedAt: DateTime.utc(2026, 1, 1, 12, 30),
  data: {
    'state': 'TH,Kc',
    'history': [
      [5, 'AS'],
    ],
  },
);

Future<GameSaveStore> createStore([Map<String, Object> data = const {}]) {
  useTestStorage(data);
  return GameSaveStore.load();
}

void main() {
  test('starts empty without saved data', () async {
    final store = await createStore();
    expect(store['klondike'], isNull);
  });

  test('keeps a saved game after a reload', () async {
    final store = await createStore();
    await store.save(saved('klondike'));

    final reloaded = (await storedSave('klondike'))!;
    expect(reloaded.gameId, 'klondike');
    expect(reloaded.moves, 12);
    expect(reloaded.playTime, const Duration(minutes: 3, seconds: 5));
    expect(reloaded.savedAt, DateTime.utc(2026, 1, 1, 12, 30));
    expect(reloaded.data, {
      'state': 'TH,Kc',
      'history': [
        [5, 'AS'],
      ],
    });
  });

  test('one save per game type: a save replaces the last one', () async {
    final store = await createStore();
    await store.save(saved('klondike', moves: 1));
    await store.save(saved('freecell', moves: 2));
    await store.save(saved('klondike', moves: 3));

    expect(store['klondike']!.moves, 3);
    expect((await storedSave('klondike'))!.moves, 3);
    expect(await SharedPreferencesAsync().getKeys(), {
      GameSaveStore.keyOf('klondike'),
      GameSaveStore.keyOf('freecell'),
    });
  });

  test('remove deletes the save of one game type only', () async {
    final store = await createStore();
    await store.save(saved('klondike'));
    await store.save(saved('freecell'));

    await store.remove('klondike');

    expect(store['klondike'], isNull);
    expect(await storedSave('klondike'), isNull);
    expect(await storedSave('freecell'), isNotNull);
  });

  test('an unreadable save is skipped and never deleted', () async {
    final badKey = GameSaveStore.keyOf('klondike');
    final store = await createStore({
      ...savedGameData([saved('freecell')]),
      badKey: '{"moves": "x"}',
      'other.app.key': 'not json',
    });

    expect(store['klondike'], isNull);
    expect(store['freecell'], isNotNull);
    expect(await SharedPreferencesAsync().getString(badKey), '{"moves": "x"}');
  });

  test('listeners are told after the write, not during the call', () async {
    final store = await createStore();
    var notified = 0;
    store.addListener(() => notified++);

    final saving = store.save(saved('klondike'));
    expect(notified, 0, reason: 'a screen saves while it is unmounted');
    expect(store['klondike'], isNotNull);
    await saving;
    expect(notified, 1);

    final removing = store.remove('klondike');
    expect(notified, 1);
    expect(store['klondike'], isNull);
    await removing;
    expect(notified, 2);
  });

  test('blocked storage still gives a working store', () async {
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final store = await GameSaveStore.load();
    expect(store['klondike'], isNull);

    await store.save(saved('klondike'));
    expect(store['klondike']!.moves, 12);
    await store.remove('klondike');
    expect(store['klondike'], isNull);
  });
}
