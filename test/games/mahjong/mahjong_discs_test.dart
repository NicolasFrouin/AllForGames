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
  ]).withDiscs(const [TilePosition(2, 0, 1), TilePosition(4, 0, 1)]),
  faces: [dots1, dots1, dots2, dots2, dots3, dots3],
  slots: [0, 1, 2, 3, 4, 5],
);

/// Two stacks far apart, each with a disc under its top tile, and a tile
/// beside the first stack: no tile lies on it, but the disc does.
/// 0 (dots1) under 1 (dots1); 2 (dots2) beside them; 3 (dots3) under 4
/// (dots2).
final besideBoard = MahjongState(
  layout: layoutOf([(0, 0, 0), (0, 0, 1), (2, 0, 0), (16, 0, 0), (16, 0, 1)])
      .withDiscs(const [TilePosition(0, 0, 1), TilePosition(16, 0, 1)]),
  faces: [dots1, dots1, dots2, dots3, dots2],
  slots: [0, 1, 2, 3, 4],
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
    expect(discCover(discBoard.layout.positions, discBoard.discs[0]), [4, 5]);
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

  test('a tile under the round of a disc cannot be taken until the disc '
      'is free', () {
    final game = discs(besideBoard);
    expect(besideBoard.isFree(2), isFalse, reason: 'no tile lies on it');
    expect(game.tap(2), TileTap.blocked);
    expect(game.tray, isEmpty);

    expect(game.tap(1), TileTap.picked);
    expect(game.state.freeDiscs, 1);
    expect(game.state.isFree(2), isTrue);
    expect(game.tap(2), TileTap.picked);
  });

  test('an undo covers the disc again, and takes its points back', () {
    final game = discs(besideBoard)..tap(1);
    expect(game.score, MahjongController.discPoints);
    expect(game.result, isNull, reason: 'one disc is left');

    game.undo();

    expect(game.state.freeDiscs, 0);
    expect(game.state.isFree(2), isFalse);
    expect(game.tray, isEmpty);
    expect(game.score, 0);
  });

  test('a full tray still loses', () {
    final layout = layoutOf([
      (0, 0, 0),
      (4, 0, 0),
      (8, 0, 0),
      (12, 0, 0),
      (20, 0, 0),
      (20, 0, 1),
    ]).withDiscs(const [TilePosition(20, 0, 1)]);
    final game = discs(
      MahjongState(
        layout: layout,
        faces: [dots1, dots2, dots3, bamboo1, flower, season],
        slots: [0, 1, 2, 3, 4, 5],
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

  test('the hints of a discs deal win it: the deal is built with the discs '
      'blocking the tiles under them', () {
    for (final difficulty in MahjongDifficulty.values) {
      for (var seed = 1; seed <= 6; seed++) {
        final game = MahjongController(
          stats: stats,
          saves: saves,
          mode: MahjongMode.discs,
          shape: MahjongShape.generated,
          difficulty: difficulty,
          seed: seed,
        );
        final reason = '${difficulty.name} seed $seed';
        for (var step = 0; game.result == null && step < 200; step++) {
          final pick = game.hintPick();
          expect(pick, isNotNull, reason: reason);
          expect(take(game, pick!), isNot(TileTap.blocked), reason: reason);
        }
        expect(game.result?.won, isTrue, reason: reason);
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
