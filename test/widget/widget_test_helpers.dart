import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';

/// A saved game. [endedMinute] orders records in time.
GameRecord record({
  String gameId = 'klondike',
  String variant = 'draw1',
  bool won = true,
  Duration playTime = const Duration(minutes: 3),
  int moves = 100,
  int undos = 0,
  int score = 500,
  int endedMinute = 0,
  Map<String, int> details = const {},
}) => GameRecord(
  gameId: gameId,
  variant: variant,
  seed: endedMinute,
  startedAt: DateTime.utc(2026, 1, 1, 10, endedMinute),
  endedAt: DateTime.utc(2026, 1, 1, 12, endedMinute),
  playTime: playTime,
  outcome: won ? GameOutcome.won : GameOutcome.abandoned,
  moves: moves,
  undos: undos,
  score: score,
  details: details,
);

/// A game in progress as the hub shows it. Its [SavedGame.data] is not a
/// game that can continue.
SavedGame savedGame({
  String gameId = 'klondike',
  int moves = 12,
  Duration playTime = const Duration(minutes: 3, seconds: 5),
}) => SavedGame(
  gameId: gameId,
  moves: moves,
  playTime: playTime,
  savedAt: DateTime.utc(2026, 1, 1, 13),
  data: const {},
);

/// Stores whose saved data holds [records] and the games in progress [saves].
Future<AppStores> seededStores(
  List<GameRecord> records, [
  List<SavedGame> saves = const [],
]) => createTestStores({...savedData(records), ...savedGameData(saves)});

/// A desktop-like window, so every widget of the screen is laid out on screen.
void useSurface(WidgetTester tester, [Size size = const Size(1280, 900)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The text of the `ValueKey('value')` child of the widget keyed [key].
String valueIn(String key) {
  final finder = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byKey(const ValueKey('value')),
  );
  return (finder.evaluate().single.widget as Text).data!;
}

/// The text of the [Text] widget keyed [key].
String textOf(String key) =>
    (find.byKey(ValueKey(key)).evaluate().single.widget as Text).data!;
