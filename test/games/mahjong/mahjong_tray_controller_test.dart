import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:all_for_games/games/mahjong/mahjong_tray.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'mahjong_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = MahjongController.gameId;

final dots4 = TileFace.of(TileSuit.dots, 4).code;

/// 1 2 2 1 in a row: a 1 waits for the other 1, then the 2s.
final rowBoard = board(row(4), [dots1, dots2, dots2, dots1]);

/// A stack of eight: from the top 1 2 3 4, then 4 3 2 1. Reaching the
/// first 4 fills the tray.
final losingStack = board(layoutOf([for (var z = 0; z < 8; z++) (0, 0, z)]), [
  dots1,
  dots2,
  dots3,
  dots4,
  dots4,
  dots3,
  dots2,
  dots1,
]);

void main() {
  late StatsStore stats;
  late GameSaveStore saves;
  late DateTime now;

  setUp(() async {
    final stores = await createTestStores();
    stats = stores.stats;
    saves = stores.saves;
    now = DateTime.utc(2026, 1, 1, 12);
  });

  MahjongController controller({
    MahjongState? state,
    MahjongDifficulty difficulty = MahjongDifficulty.medium,
    int seed = 1,
  }) => MahjongController(
    stats: stats,
    saves: saves,
    difficulty: difficulty,
    mode: MahjongMode.tray,
    seed: seed,
    initialState: state,
    clock: () => now,
  );

  MahjongController restore(SavedGame? saved) => MahjongController.restore(
    saved!.data,
    stats: stats,
    saves: saves,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Picks the hinted tile until the game is over.
  void playHints(MahjongController game) {
    while (game.result == null) {
      final pick = game.hintPick()!;
      expect(game.tap(pick), isNot(TileTap.blocked));
    }
  }

  group('tapping', () {
    test('a free tile goes into the tray, its twin clears both', () {
      final game = controller(state: rowBoard);
      var notified = 0;
      game.addListener(() => notified++);

      expect(game.tap(0), TileTap.picked);
      expect(game.tray, [0]);
      expect(game.state.positionOf(0), isNull);
      expect(game.tilesLeft, 4);
      expect(game.score, 0);
      expect(game.lastAction, MahjongAction.pick);

      expect(game.tap(3), TileTap.matched);
      expect(game.tray, isEmpty);
      expect(game.tilesLeft, 2);
      expect(game.moves, 2, reason: 'every pick is a move');
      expect(game.score, MahjongController.matchPoints);
      expect(notified, 2);
    });

    test('a blocked tile and a tile of the tray do nothing', () {
      final game = controller(state: rowBoard);
      game.tap(0);

      expect(game.tap(2), TileTap.blocked);
      expect(game.tap(0), TileTap.ignored);
      expect(game.tray, [0]);
    });

    test('there is no shuffle in tray mode', () {
      final game = controller(state: rowBoard);

      expect(game.shuffle(), isFalse);
      expect(game.hint(), isNull, reason: 'a pick is hinted, not a pair');
    });
  });

  group('a full tray', () {
    test(
      'loses at once: the game is recorded as lost, its save removed',
      () async {
        final game = controller(state: losingStack);
        wait(4);
        for (final id in [7, 6, 5]) {
          game.tap(id);
        }
        expect(game.isStuck, isTrue, reason: 'any tile would fill the tray');
        expect(game.canHint, isFalse);
        await flush();
        expect(await storedSave(gameId), isNotNull);

        game.tap(4);
        await flush();

        expect(game.isLost, isTrue);
        expect(game.tray, hasLength(4));
        final record = stats.records.single;
        expect(game.result, same(record));
        expect(record.outcome, GameOutcome.lost);
        expect(record.variant, 'tray-test');
        expect(record.moves, 4);
        expect(record.details[MahjongStatKeys.mostHeld], 4);
        expect(record.details[MahjongStatKeys.tilesHeld], 4);
        expect(record.details[MahjongStatKeys.tilesLeft], 8);
        expect(record.details.containsKey(MahjongStatKeys.shuffles), isFalse);
        expect(await storedSave(gameId), isNull);
        expect(game.canUndo, isFalse, reason: 'a loss is final');
        expect(game.tap(3), TileTap.ignored);
      },
    );

    test('a new game after it records nothing more; the same seed deals '
        'the same game', () {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 6);
      final faces = game.state.faces;
      // Free tiles of four faces, none in pairs, fill the tray.
      final picks = <int>[];
      for (final id in game.state.tileIds) {
        final face = game.state.faces[id];
        if (game.state.isFree(id) &&
            picks.every((pick) => game.state.faces[pick] != face)) {
          picks.add(id);
        }
        if (picks.length == TrayState.capacity) break;
      }
      for (final id in picks) {
        take(game, id);
      }
      expect(game.isLost, isTrue);

      game.newGame(seed: game.seed);

      expect(stats.records, hasLength(1));
      expect(game.state.faces, faces);
      expect(game.tray, isEmpty);
      expect(game.mode, MahjongMode.tray);
    });
  });

  test('undo takes a tile back from the tray, and a cleared pair back', () {
    final game = controller(state: rowBoard);
    game.tap(0);
    game.tap(3);

    game.undo();
    expect(game.tray, [0]);
    expect(game.state.positionOf(3), 3);
    expect(game.score, 0);

    game.undo();
    expect(game.tray, isEmpty);
    expect(game.state.slots, rowBoard.slots);
    expect((game.moves, game.undos), (2, 2));
  });

  group('hint', () {
    test('shows the tile to pick, and the tile of the tray it clears', () {
      final game = controller(state: rowBoard);

      final first = game.hintPick()!;
      expect(game.hintedTiles, [first]);
      game.tap(first);
      final second = game.hintPick()!;

      expect(game.hintedTiles, [second, first]);
      expect(game.hints, 2);
    });

    test('followed to the end wins every level', () {
      for (final difficulty in MahjongDifficulty.values) {
        final game = controller(difficulty: difficulty, seed: 5);
        playHints(game);
        expect(game.result!.won, isTrue, reason: difficulty.name);
      }
    });

    test('still wins after picks out of the winning order', () {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 9);
      // Tiles that clear a pair, whatever the hint says.
      for (var i = 0; i < 12; i++) {
        final matches = game.trayState.freeMatches;
        final pairs = game.state.freePairs;
        if (matches.isNotEmpty) {
          game.tap(matches.last);
        } else if (pairs.isNotEmpty && game.tray.length < 2) {
          game.tap(pairs.last.$1);
        } else {
          break;
        }
      }

      playHints(game);
      expect(game.result!.won, isTrue);
    });
  });

  group('records', () {
    test('a won game, with the tray details, and no save left', () async {
      final game = controller(
        state: rowBoard,
        difficulty: MahjongDifficulty.easy,
      );
      wait(3);
      game.tap(0);
      wait(2);
      game.tap(3);
      game.tap(1);
      game.tap(2);
      await flush();

      final record = stats.records.single;
      expect(record.won, isTrue);
      expect(record.variant, 'tray-test');
      expect(record.difficulty, 'easy');
      expect(record.moves, 4);
      expect(record.details, {
        MahjongStatKeys.hints: 0,
        MahjongStatKeys.pairsMatched: 2,
        MahjongStatKeys.tilesLeft: 0,
        MahjongStatKeys.bestCombo: 2,
        MahjongStatKeys.timeToFirstMatchMs: 5000,
        MahjongStatKeys.longestThinkMs: 3000,
        MahjongStatKeys.mostHeld: 1,
        MahjongStatKeys.tilesHeld: 2,
      });
      expect(await storedSave(gameId), isNull);
    });

    test('a new game over a game with a pick records it as abandoned', () {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 3);
      game.tap(game.hintPick()!);

      game.newGame(mode: MahjongMode.classic);

      final record = stats.records.single;
      expect(record.outcome, GameOutcome.abandoned);
      expect(record.variant, 'tray-turtle');
      expect(record.details[MahjongStatKeys.tilesLeft], 144);
      expect(game.mode, MahjongMode.classic);
      expect(game.tray, isEmpty);
    });
  });

  group('saves', () {
    test(
      'a restore continues with the tray, its undo history and hints',
      () async {
        final game = controller(difficulty: MahjongDifficulty.hard, seed: 4);
        for (var i = 0; i < 5; i++) {
          game.tap(game.hintPick()!);
        }
        final tray = game.tray;
        await flush();

        final restored = restore(await storedSave(gameId));

        expect(restored.mode, MahjongMode.tray);
        expect(restored.tray, tray);
        expect(restored.state.slots, game.state.slots);
        expect(restored.hintPick(), game.hintPick(), reason: 'the same order');
        restored.undo();
        expect(restored.tray, isNot(tray), reason: 'with its undo history');
        playHints(restored);
        expect(restored.result!.won, isTrue);
      },
    );

    test('a full tray, a tile both on the board and in the tray, or an '
        'unknown mode are unreadable', () {
      final game = controller(difficulty: MahjongDifficulty.easy, seed: 2);
      final picked = game.hintPick()!;
      game.tap(picked);
      final json = game.toJson();
      final onBoard = game.state.tileIds.first;
      expect(MahjongController.restore(json, stats: stats, saves: saves).tray, [
        picked,
      ]);

      for (final bad in [
        {
          ...json,
          'tray': [picked, onBoard],
        },
        {
          ...json,
          'tray': [picked, 70, 71, 69],
        },
        {...json, 'mode': 'tower'},
      ]) {
        expect(
          () => MahjongController.restore(bad, stats: stats, saves: saves),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });
}
