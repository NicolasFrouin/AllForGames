import 'package:all_for_games/games/mahjong/mahjong_controller.dart';
import 'package:all_for_games/games/mahjong/mahjong_difficulty.dart';
import 'package:all_for_games/games/mahjong/mahjong_solver.dart';
import 'package:all_for_games/games/mahjong/mahjong_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'mahjong_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = MahjongController.gameId;

/// Two stacks: a 1 on a 2, and a 2 on a 1. No free tiles match.
final stuckBoard = board(
  layoutOf([(0, 0, 0), (0, 0, 1), (4, 0, 0), (4, 0, 1)]),
  [dots2, dots1, dots1, dots2],
);

/// 1 2 2 1 in a row: the 1s first, then the 2s.
final rowBoard = board(row(4), [dots1, dots2, dots2, dots1]);

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

  /// Starts a new game, so [game] counts as abandoned, and returns its record.
  GameRecord abandon(MahjongController game) {
    game.newGame();
    return stats.records.last;
  }

  /// Matches the first free pair and starts a new game, so [game] counts as
  /// abandoned; returns its record.
  GameRecord abandonAfterMatch(MahjongController game) {
    final (a, b) = game.state.freePairs.first;
    game.match(a, b);
    return abandon(game);
  }

  /// Plays the hinted pair until the game is won.
  void playHints(MahjongController game) {
    while (game.result == null) {
      final (a, b) = game.hint()!;
      expect(game.match(a, b), isTrue);
    }
  }

  group('tapping', () {
    test('a free tile selects it, a second tap unselects it', () {
      final game = controller(state: rowBoard);

      expect(game.tap(0), TileTap.selected);
      expect(game.selected, 0);
      expect(game.tap(0), TileTap.deselected);
      expect(game.selected, isNull);
    });

    test('a blocked tile does nothing', () {
      final game = controller(state: rowBoard);

      expect(game.tap(1), TileTap.blocked);
      expect(game.selected, isNull);
    });

    test('a free tile that does not match selects it instead', () {
      final game = controller(
        state: board(row(4), [dots1, dots2, dots1, dots2]),
      );
      game.tap(0);

      expect(game.tap(3), TileTap.selected);
      expect(game.selected, 3);
      expect(game.moves, 0);
    });

    test('two free tiles that match removes them, for a move and points', () {
      final game = controller(state: rowBoard);
      var notified = 0;
      game.addListener(() => notified++);

      game.tap(0);
      expect(game.tap(3), TileTap.matched);

      expect(game.state.tileCount, 2);
      expect(game.selected, isNull);
      expect(game.moves, 1);
      expect(game.score, MahjongController.matchPoints);
      expect(game.lastAction, MahjongAction.match);
      expect(notified, 2);
    });
  });

  test('undo puts the pair back, with its score, and counts an undo', () {
    final game = controller(state: rowBoard);
    game.match(0, 3);

    game.undo();

    expect(game.state.slots, rowBoard.slots);
    expect(game.score, 0);
    expect(game.moves, 1, reason: 'moves made, also those taken back');
    expect(game.undos, 1);
    expect(game.canUndo, isFalse);
    expect(abandon(game).undos, 1);
  });

  test('matches a few seconds apart make a combo worth more points', () {
    final game = controller(
      state: board(row(6), [dots1, dots2, dots3, dots3, dots2, dots1]),
    );
    game.match(0, 5);
    wait(3);
    game.match(1, 4);
    expect(game.combo, 2);
    wait(10);
    game.match(2, 3);

    expect(game.combo, 1);
    expect(game.score, 10 + 15 + 10);
    expect(game.result!.details[MahjongStatKeys.bestCombo], 2);
  });

  group('hint', () {
    test('shows free tiles that match, and counts', () {
      final game = controller();

      final (a, b) = game.hint()!;

      expect(game.state.canMatch(a, b), isTrue);
      expect(game.hintPair, (a, b));
      expect(game.hints, 1);
      expect(abandonAfterMatch(game).details[MahjongStatKeys.hints], 1);
    });

    test('followed to the end wins every level', () {
      for (final difficulty in MahjongDifficulty.values) {
        final game = controller(difficulty: difficulty, seed: 5);
        playHints(game);
        expect(game.result!.won, isTrue, reason: difficulty.name);
      }
    });

    test('still wins after other matches than the hinted ones', () {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 9);
      // The first free pair, whatever the hint says, while it stays winnable.
      for (var i = 0; i < 10; i++) {
        final (a, b) = game.state.freePairs.last;
        final next = game.state.match(a, b)!;
        if (solveMahjong(next) == null) break;
        game.match(a, b);
      }

      playHints(game);
      expect(game.result!.won, isTrue);
    });
  });

  group('shuffle', () {
    test('only when no match is left', () {
      final game = controller(state: rowBoard);

      expect(game.isStuck, isFalse);
      expect(game.shuffle(), isFalse);
      expect(game.shuffles, 0);
    });

    test('moves the tiles so that the game can be won, and counts', () {
      final game = controller(state: stuckBoard);
      expect(game.isStuck, isTrue);
      expect(game.canHint, isFalse);

      expect(game.shuffle(), isTrue);

      expect(game.isStuck, isFalse);
      expect(game.shuffles, 1);
      expect(game.lastAction, MahjongAction.shuffle);
      playHints(game);
      expect(game.result!.details[MahjongStatKeys.shuffles], 1);
    });

    test('can be undone', () {
      final game = controller(state: stuckBoard);
      game.shuffle();

      game.undo();

      expect(game.state.slots, stuckBoard.slots);
      expect(game.isStuck, isTrue);
    });
  });

  group('records', () {
    test('a won game, with its details, and no save left', () async {
      final game = controller(
        state: rowBoard,
        difficulty: MahjongDifficulty.easy,
      );
      wait(5);
      game.hint();
      wait(2);
      game.match(0, 3);
      await flush();
      expect(await storedSave(gameId), isNotNull);
      wait(20);
      game.match(1, 2);
      await flush();

      final record = stats.records.single;
      expect(record.won, isTrue);
      expect(record.variant, 'test');
      expect(record.difficulty, 'easy');
      expect(record.moves, 2);
      expect(record.playTime, const Duration(seconds: 27));
      expect(record.details, {
        MahjongStatKeys.hints: 1,
        MahjongStatKeys.shuffles: 0,
        MahjongStatKeys.pairsMatched: 2,
        MahjongStatKeys.tilesLeft: 0,
        MahjongStatKeys.bestCombo: 1,
        MahjongStatKeys.timeToFirstMatchMs: 7000,
        MahjongStatKeys.longestThinkMs: 20000,
      });
      expect(game.result, same(record));
      expect(await storedSave(gameId), isNull);
      expect(game.canUndo, isFalse);
      expect(game.match(1, 2), isFalse);
    });

    test('a new game over a game with a match records it as abandoned', () {
      final game = controller(seed: 3);
      final (a, b) = game.state.freePairs.first;
      game.match(a, b);
      game.undo();
      final (c, d) = game.state.freePairs.first;
      game.match(c, d);

      final record = abandon(game);

      expect(record.outcome, GameOutcome.abandoned);
      expect(record.seed, 3);
      expect(record.variant, 'turtle');
      expect(record.difficulty, 'medium');
      expect(record.moves, 2);
      expect(record.details[MahjongStatKeys.pairsMatched], 1);
      expect(record.details[MahjongStatKeys.tilesLeft], 142);
    });

    test('a new game over a game without a match records nothing', () {
      final game = controller();
      game.hint();

      game.newGame(difficulty: MahjongDifficulty.easy);

      expect(stats.records, isEmpty);
      expect(game.state.tileCount, 72);
      expect(game.difficulty, MahjongDifficulty.easy);
    });
  });

  group('new games', () {
    test('deal the layout of the difficulty, both ways', () {
      final game = controller(difficulty: MahjongDifficulty.easy);
      expect(game.state.layout.id, 'pyramid');

      game.newGame(difficulty: MahjongDifficulty.hard, transposed: true);

      expect(game.state.layout.id, 'turtle');
      expect(game.state.layout.transposed, isTrue);
      expect(game.lastAction, MahjongAction.deal);
    });

    test('the same seed gives the same deal, by default a random one', () {
      final game = controller(seed: 8);
      final faces = game.state.faces;

      game.newGame(seed: 8);
      expect(game.state.faces, faces);

      game.newGame();
      expect(game.seed, isNot(8));
    });
  });

  group('saves', () {
    test('every action saves the game; a restore continues it', () async {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 4);
      wait(3);
      final (a, b) = game.state.freePairs.first;
      game.match(a, b);
      wait(4);
      final (c, d) = game.state.freePairs.first;
      game.match(c, d);
      game.undo();
      game.hint();
      await flush();

      final restored = restore(await storedSave(gameId));

      expect(restored.state.slots, game.state.slots);
      expect(restored.state.faces, game.state.faces);
      expect(restored.difficulty, MahjongDifficulty.hard);
      expect(restored.seed, 4);
      expect(
        (restored.moves, restored.undos, restored.hints, restored.score),
        (game.moves, game.undos, game.hints, game.score),
      );
      expect(restored.playTime, const Duration(seconds: 7));
      expect(restored.hint(), game.hint(), reason: 'the same winning order');

      restored.undo();
      expect(restored.state.tileCount, 144, reason: 'with its undo history');
      playHints(restored);
      expect(restored.result!.won, isTrue);
    });

    test('a transposed game continues transposed', () async {
      final game = MahjongController(
        stats: stats,
        saves: saves,
        transposed: true,
        clock: () => now,
      );
      game.pause();
      await flush();

      expect(restore(await storedSave(gameId)).state.layout.transposed, isTrue);
    });

    test('a save of version 1, with four flowers and four seasons that '
        'matched each other, continues with one flower and one season', () {
      final game = controller(difficulty: MahjongDifficulty.hard, seed: 4);
      // Version 1 had no tray mode, and numbered the four flowers 34 to 37,
      // the seasons 38 to 41.
      final json = game.toJson()
        ..remove('mode')
        ..remove('tray');
      var flowers = 0;
      var seasons = 0;
      final version1 = {
        ...json,
        'version': 1,
        'faces': [
          for (final face in json['faces']! as List<int>)
            face == flower
                ? 34 + flowers++ % 4
                : face == season
                ? 38 + seasons++ % 4
                : face,
        ],
      };

      final restored = MahjongController.restore(
        version1,
        stats: stats,
        saves: saves,
      );

      expect((flowers, seasons), (4, 4));
      expect(restored.state.faces, game.state.faces);
      playHints(restored);
      expect(restored.result!.won, isTrue);
    });

    test('unreadable data throws a FormatException', () async {
      final game = controller(difficulty: MahjongDifficulty.easy);
      final json = game.toJson();

      for (final bad in [
        {...json, 'version': 99},
        {...json, 'layout': 'castle'},
        {
          ...json,
          'slots': [1, 2, 3],
        },
        {...json, 'faces': 'none'},
        {
          ...json,
          'slots': [0, 0, ...(json['slots']! as List<int>).skip(2)],
        },
        <String, Object?>{},
      ]) {
        expect(
          () => MahjongController.restore(bad, stats: stats, saves: saves),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  test('pausing stops the play time and saves', () async {
    final game = controller();
    wait(5);
    game.pause();
    wait(60);
    await flush();

    expect(game.playTime, const Duration(seconds: 5));
    expect((await storedSave(gameId))!.playTime, const Duration(seconds: 5));
    game.resume();
    wait(2);
    expect(game.playTime, const Duration(seconds: 7));
  });
}
