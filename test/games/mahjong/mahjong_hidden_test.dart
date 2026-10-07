import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_generator.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'mahjong_test_helpers.dart';

/// Four free tiles apart, 1 2 1 2; the first three lie face down.
final spreadBoard = MahjongState(
  layout: layoutOf([(0, 0, 0), (4, 0, 0), (8, 0, 0), (12, 0, 0)]),
  faces: [dots1, dots2, dots1, dots2],
  slots: [0, 1, 2, 3],
  hidden: {0, 1, 2},
);

void main() {
  late StatsStore stats;
  late GameSaveStore saves;

  setUp(() async {
    final stores = await createTestStores();
    stats = stores.stats;
    saves = stores.saves;
  });

  MahjongController controller(
    MahjongState state, {
    MahjongMode mode = MahjongMode.classic,
  }) => MahjongController(
    stats: stats,
    saves: saves,
    mode: mode,
    initialState: state,
  );

  test('a tap turns a hidden tile over; the next tap selects it', () {
    final game = controller(spreadBoard);
    expect(game.isFaceUp(0), isFalse);
    expect(game.isFaceUp(3), isTrue, reason: 'not a hidden tile');

    expect(game.tap(0), TileTap.revealed);
    expect((game.revealed, game.selected, game.isFaceUp(0)), (0, null, true));

    expect(game.tap(0), TileTap.selected);
    expect((game.revealed, game.selected, game.isFaceUp(0)), (null, 0, true));

    expect(game.tap(0), TileTap.deselected);
    expect(game.isFaceUp(0), isTrue, reason: 'it stays turned over');
    expect(game.moves, 0);
  });

  test('one hidden tile is face up at a time, besides the selected one', () {
    final game = controller(spreadBoard)
      ..tap(0)
      ..tap(1);
    expect((game.isFaceUp(0), game.isFaceUp(1)), (false, true));

    game
      ..tap(1)
      ..tap(2);
    expect(game.isFaceUp(1), isTrue, reason: 'selected');
    expect(game.isFaceUp(2), isTrue);

    // 2 does not match 1: it is selected instead, and 1 turns back.
    expect(game.tap(2), TileTap.selected);
    expect((game.isFaceUp(1), game.isFaceUp(2)), (false, true));

    // 0 matches 2 once it is turned over.
    expect(game.tap(0), TileTap.revealed);
    expect(game.tap(0), TileTap.matched);
    expect(game.tilesLeft, 2);
    expect(game.revealed, isNull);
  });

  test('a blocked hidden tile stays face down', () {
    final game = controller(
      MahjongState(
        layout: layoutOf([(0, 0, 0), (2, 0, 0), (4, 0, 0)]),
        faces: [dots1, dots2, dots1],
        slots: [0, 1, 2],
        hidden: {1},
      ),
    );

    expect(game.tap(1), TileTap.blocked);
    expect(game.isFaceUp(1), isFalse);
  });

  test('in tray mode, the second tap puts the tile in the tray', () {
    final game = controller(spreadBoard, mode: MahjongMode.tray);

    expect(game.tap(1), TileTap.revealed);
    expect(game.tray, isEmpty);
    expect(game.tap(1), TileTap.picked);
    expect(game.tray, [1]);
    expect(game.revealed, isNull);
  });

  test('the save keeps the hidden tiles and the one turned over', () async {
    final game = controller(spreadBoard)..tap(1);
    game.save();
    await Future<void>.delayed(Duration.zero);

    final restored = MahjongController.restore(
      saves[MahjongController.gameId]!.data,
      stats: stats,
      saves: saves,
    );
    expect(restored.state.hidden, {0, 1, 2});
    expect(restored.revealed, 1);
    expect(restored.isFaceUp(0), isFalse);
  });

  test('deals hide their share of tiles, with the same faces', () {
    final layout = turtleLayout;
    final plain = generateDeal(layout, 3, trapPercent: 15);
    final hidden = generateDeal(layout, 3, trapPercent: 15, hiddenPercent: 20);
    expect(plain.state.hidden, isEmpty);
    expect(hidden.state.faces, plain.state.faces);
    expect(hidden.state.hidden, hasLength(29));
    expect(
      generateDeal(layout, 3, trapPercent: 15, hiddenPercent: 20).state.hidden,
      hidden.state.hidden,
    );

    final tray = generateTrayDeal(
      layout,
      3,
      MahjongDifficulty.hard.tray,
      hiddenPercent: 20,
    );
    expect(tray.state.hidden, hasLength(29));
    expect(TrayState(tray.state, const []).isSolvedBy(tray.solution), isTrue);
  });

  test('the harder levels deal hidden tiles, Easy none', () {
    for (final (difficulty, count) in [
      (MahjongDifficulty.easy, 0),
      (MahjongDifficulty.hard, 29),
    ]) {
      final game = MahjongController(
        stats: stats,
        saves: saves,
        difficulty: difficulty,
        seed: 4,
      );
      expect(game.state.hidden.length, count, reason: difficulty.name);
    }
  });
}
