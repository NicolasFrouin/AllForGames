import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_discs.dart';
import 'package:all_for_games/games/mahjong/mahjong_layout.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'mahjong_test_helpers.dart';

/// Four tiles in a row, and two on them: a disc lies under each of those.
/// 0 1 2 3 on the table (1 1 2 2), 4 on 1 and 5 on 2 (3 and 3).
final discBoard = MahjongState(
  layout: layoutOf([
    (0, 0, 0),
    (2, 0, 0),
    (4, 0, 0),
    (6, 0, 0),
    (2, 0, 1),
    (4, 0, 1),
  ]),
  faces: [dots1, dots1, dots2, dots2, dots3, dots3],
  slots: [0, 1, 2, 3, 4, 5],
  discs: const [TilePosition(2, 0, 1), TilePosition(4, 0, 1)],
);

void main() {
  late StatsStore stats;
  late GameSaveStore saves;

  setUp(() async {
    final stores = await createTestStores();
    stats = stores.stats;
    saves = stores.saves;
  });

  MahjongController discs(MahjongState state) => MahjongController(
    stats: stats,
    saves: saves,
    mode: MahjongMode.discs,
    initialState: state,
  );

  test('a disc is free once no tile of its layer or above lies on it', () {
    // The disc under 4 also lies under 5, beside it; not under 1, below.
    expect(discCover(discBoard.layout, discBoard.discs[0]), [4, 5]);
    expect(discBoard.isDiscFree(0), isFalse);

    final withoutFour = discBoard.withSlots([0, 1, 2, 3, -1, 5]);
    expect(withoutFour.isDiscFree(0), isFalse, reason: '5 lies on its edge');
    final bare = discBoard.withSlots([0, 1, 2, 3, -1, -1]);
    expect((bare.isDiscFree(0), bare.isDiscFree(1)), (true, true));
    expect(bare.discsFree, isTrue);
  });

  test('freeing every disc wins, with tiles left; each disc scores', () async {
    final game = discs(discBoard);

    expect(game.tap(4), TileTap.picked);
    expect(game.state.freeDiscs, 0);
    expect(game.tap(5), TileTap.matched);

    expect(game.result?.won, isTrue);
    expect(game.tilesLeft, 4);
    expect(game.score, 2 * MahjongController.discPoints + 10);
    await Future<void>.delayed(Duration.zero);
    final record = stats.records.single;
    expect(record.variant, 'discs-test');
    expect(record.details[MahjongStatKeys.discsFreed], 2);
    expect(record.details[MahjongStatKeys.tilesLeft], 4);
  });

  test('an undo covers the disc again, and takes its points back', () {
    final game = discs(
      discBoard.withDiscs(const [TilePosition(2, 0, 1)]).withSlots([
        0,
        1,
        2,
        3,
        4,
        -1,
      ]),
    );
    expect(game.state.freeDiscs, 0);

    game.tap(4);
    expect(game.result?.won, isTrue, reason: 'its only disc is free');

    final second = discs(discBoard)..tap(4);
    expect(second.score, 0);
    second.tap(0);
    expect(second.state.freeDiscs, 0);
    second.undo();
    expect(second.tray, [4]);
  });

  test('a full tray still loses', () {
    final layout = layoutOf([
      (0, 0, 0),
      (4, 0, 0),
      (8, 0, 0),
      (12, 0, 0),
      (16, 0, 0),
      (16, 0, 1),
    ]);
    final game = discs(
      MahjongState(
        layout: layout,
        faces: [dots1, dots2, dots3, bamboo1, flower, season],
        slots: [0, 1, 2, 3, 4, 5],
        discs: const [TilePosition(16, 0, 1)],
      ),
    );
    for (final id in [0, 1, 2, 3]) {
      game.tap(id);
    }

    expect(game.isLost, isTrue);
    expect(stats.records.single.outcome, GameOutcome.lost);
  });

  test('a deal of the discs mode places the level\'s discs, all covered', () {
    for (final difficulty in MahjongDifficulty.values) {
      for (var seed = 1; seed <= 20; seed++) {
        final game = MahjongController(
          stats: stats,
          saves: saves,
          mode: MahjongMode.discs,
          shape: MahjongShape.generated,
          difficulty: difficulty,
          seed: seed,
        );
        final state = game.state;
        final reason = '${difficulty.name} seed $seed';
        expect(state.discs, hasLength(difficulty.discs), reason: reason);
        expect(state.freeDiscs, 0, reason: reason);
        final places = state.layout.positions.toSet();
        for (final disc in state.discs) {
          expect(places, contains(disc), reason: '$reason: under a tile');
          expect(
            places,
            contains(TilePosition(disc.x, disc.y, disc.z - 1)),
            reason: '$reason: on a tile',
          );
        }
        expect(
          placeDiscs(state.layout, seed, difficulty.discs),
          state.discs,
          reason: 'the same seed places the same discs',
        );
      }
    }
  });

  test('the save keeps the discs', () async {
    final game = discs(discBoard)..tap(4);
    game.save();
    await Future<void>.delayed(Duration.zero);

    final restored = MahjongController.restore(
      saves[MahjongController.gameId]!.data,
      stats: stats,
      saves: saves,
    );
    expect(restored.mode, MahjongMode.discs);
    expect(restored.state.discs, discBoard.discs);
    expect(restored.tray, [4]);
  });

  test('records name the mode and the layout', () {
    expect(mahjongVariant(MahjongMode.discs, 'random'), 'discs-random');
    expect(mahjongModeAndLayout('discs-turtle'), (MahjongMode.discs, 'turtle'));
    expect(mahjongModeAndLayout('tray-random'), (MahjongMode.tray, 'random'));
    expect(mahjongModeAndLayout('pyramid'), (MahjongMode.classic, 'pyramid'));
  });
}
