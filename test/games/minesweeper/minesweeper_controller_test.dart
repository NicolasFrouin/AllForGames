import 'package:all_for_games/games/minesweeper/minesweeper_controller.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_solver.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'minesweeper_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = MinesweeperController.gameId;

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

  MinesweeperController controller({
    MinesweeperState? state,
    MinesweeperDifficulty difficulty = MinesweeperDifficulty.easy,
    bool turned = false,
    int seed = 1,
  }) => MinesweeperController(
    stats: stats,
    saves: saves,
    difficulty: difficulty,
    turned: turned,
    seed: seed,
    initialState: state,
    clock: () => now,
  );

  MinesweeperController restore(SavedGame? saved) =>
      MinesweeperController.restore(
        saved!.data,
        stats: stats,
        saves: saves,
        clock: () => now,
      );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Opens the safe cells logic proves, one hint at a time, until the game
  /// is won.
  void playHints(MinesweeperController game) {
    while (game.result == null) {
      expect(game.open(game.hint()!), isTrue);
    }
  }

  group('the first tap', () {
    test('places the mines around it: it opens an area', () {
      final game = controller(seed: 42);
      expect(game.state.hasMines, isFalse);
      expect(game.minesLeft, 10);
      expect(game.canHint, isFalse);

      expect(game.open(40), isTrue);
      expect(game.state.mines, hasLength(10));
      expect(game.state.countAt(40), 0);
      expect(game.firstTap, 40);
      expect(game.clicks, 1);
      expect(game.canHint, isTrue);
    });

    test('starts the timer; flags wait for it', () {
      final game = controller();
      wait(30);
      expect(game.toggleFlag(0), isFalse);
      expect(game.started, isFalse);
      expect(game.playTime, Duration.zero);

      game.open(40);
      wait(5);
      expect(game.started, isTrue);
      expect(game.playTime, const Duration(seconds: 5));
    });

    test('in turned mode, places mines on the turned board', () {
      final game = controller(
        difficulty: MinesweeperDifficulty.hard,
        turned: true,
      )..open(100);
      expect((game.state.columns, game.state.rows), (16, 30));
      expect(game.state.mines, hasLength(99));
    });
  });

  test('flags count down the mines left; each flag placed counts', () {
    final game = controller(state: cornerBoard)..open(cornerTap);
    expect(game.toggleFlag(0), isTrue);
    expect(game.minesLeft, 3);
    expect(game.lastAction, MinesweeperAction.flag);
    expect(game.toggleFlag(0), isTrue);
    expect(game.lastAction, MinesweeperAction.unflag);
    expect(game.toggleFlag(at(cornerBoard, 2, 0)), isTrue);
    expect(game.minesLeft, 3);
    // Not on an open cell.
    expect(game.toggleFlag(cornerTap), isFalse);
    expect(game.clicks, 4);
  });

  test('a tap on an open number chords', () {
    final two = at(cornerBoard, 0, 2);
    final game = controller(state: cornerBoard)
      ..open(two)
      ..toggleFlag(at(cornerBoard, 0, 1));
    expect(game.open(two), isFalse);

    game.toggleFlag(at(cornerBoard, 1, 1));
    expect(game.open(two), isTrue);
    expect(game.state.isOpen(cornerTap), isTrue);
    expect(game.lastAction, MinesweeperAction.open);
    expect(game.lastCell, two);
  });

  test('a win is recorded with its details, and its save removed', () async {
    final game = controller(state: cornerBoard)..open(cornerTap);
    await flush();
    expect(saves[gameId], isNotNull);
    wait(20);
    game
      ..toggleFlag(at(cornerBoard, 2, 0))
      ..open(0)
      ..hint();
    expect(game.hintCell, 1);
    game.open(1);
    await flush();

    expect(game.lastAction, MinesweeperAction.win);
    // A won board shows every mine flagged.
    expect(game.state.flagCount, 4);
    expect(game.minesLeft, 0);
    final record = stats.records.single;
    expect(record, same(game.result));
    expect(
      (record.outcome, record.moves, record.playTime, record.difficulty),
      (GameOutcome.won, 4, const Duration(seconds: 20), 'easy'),
    );
    expect(record.variant, MinesweeperController.variant);
    expect(record.score, 3 * MinesweeperController.pointsPerBoardValue);
    expect(record.details, {
      MinesweeperStatKeys.boardValue: 3,
      MinesweeperStatKeys.efficiency: 75,
      MinesweeperStatKeys.chords: 0,
      MinesweeperStatKeys.flagsPlaced: 1,
      MinesweeperStatKeys.hints: 1,
      MinesweeperStatKeys.cellsRevealed: 21,
    });
    expect(saves[gameId], isNull);
    // A finished game takes no more actions.
    expect(game.open(5), isFalse);
    expect(game.hint(), isNull);
  });

  test('opening a mine loses at once: recorded as lost', () async {
    final game = controller(state: cornerBoard)..open(cornerTap);
    wait(12);
    expect(game.open(at(cornerBoard, 1, 1)), isTrue);
    await flush();

    expect(game.state.isLost, isTrue);
    expect(game.lastAction, MinesweeperAction.lose);
    expect(game.isOver, isTrue);
    final record = stats.records.single;
    expect(
      (record.outcome, record.won, record.moves, record.playTime),
      (GameOutcome.lost, false, 2, const Duration(seconds: 12)),
    );
    expect(record.details[MinesweeperStatKeys.cellsRevealed], 19);
    expect(record.score, 1 * MinesweeperController.pointsPerBoardValue);
    expect(saves[gameId], isNull);
  });

  test('try again plays the same board, its first tap open, without '
      'recording it until the player plays', () async {
    final game = controller(seed: 9)..open(40);
    final mines = game.state.mines;
    final mine = mines.first;
    game.open(mine);
    await flush();
    expect(stats.records.single.outcome, GameOutcome.lost);
    now = now.add(const Duration(minutes: 1));

    game.retry();
    expect(game.state.mines, mines);
    expect(game.state.isOpen(40), isTrue);
    expect(game.state.isLost, isFalse);
    expect((game.seed, game.firstTap, game.clicks), (9, 40, 1));
    expect(game.started, isFalse);
    expect(game.lastAction, MinesweeperAction.deal);

    game.newGame();
    await flush();
    expect(stats.records, hasLength(1));
  });

  test('a new game over a started one records it as abandoned', () async {
    final game = controller(seed: 3)..newGame(seed: 4);
    await flush();
    expect(stats.records, isEmpty, reason: 'not started');

    game.open(10);
    wait(8);
    game.newGame(difficulty: MinesweeperDifficulty.medium);
    await flush();

    final record = stats.records.single;
    expect(
      (record.outcome, record.seed, record.moves, record.difficulty),
      (GameOutcome.abandoned, 4, 1, 'easy'),
    );
    expect(game.difficulty, MinesweeperDifficulty.medium);
    expect(game.state.hasMines, isFalse);
    expect(game.started, isFalse);
  });

  test('hints show cells that logic proves safe, and count', () {
    final game = controller(difficulty: MinesweeperDifficulty.medium, seed: 5)
      ..open(120);
    playHints(game);
    expect(game.result!.won, isTrue);
    expect(game.hints, greaterThan(10));
    expect(game.result!.details[MinesweeperStatKeys.hints], game.hints);
  });

  group('save', () {
    test('a game continues where it was', () async {
      final game = controller(seed: 21)..open(40);
      final flag = MinesweeperSolver.of(game.state).findSafe()!;
      game
        ..toggleFlag(flag)
        ..hint();
      wait(15);
      game.pause();
      await flush();

      final copy = restore(saves[gameId]);
      expect(copy.state.encodeCovers(), game.state.encodeCovers());
      expect(copy.state.mines, game.state.mines);
      expect(
        (copy.seed, copy.difficulty, copy.firstTap, copy.clicks, copy.hints),
        (21, MinesweeperDifficulty.easy, 40, 2, 1),
      );
      expect(copy.hintCell, game.hintCell);
      expect(copy.started, isTrue);
      expect(copy.playTime, const Duration(seconds: 15));
      expect(copy.toJson(), game.toJson());
    });

    test('a game before its first tap keeps its seed and orientation', () {
      MinesweeperController expert() => controller(
        difficulty: MinesweeperDifficulty.hard,
        turned: true,
        seed: 77,
      );
      expert().save();

      final copy = restore(saves[gameId]);
      expect(copy.state.hasMines, isFalse);
      expect((copy.seed, copy.turned, copy.state.columns), (77, true, 16));
      expect(copy.started, isFalse);
      copy.open(5);
      expect(copy.state.mines, (expert()..open(5)).state.mines);
    });

    test('unreadable data throws a FormatException', () {
      final good = (controller()..open(40)).toJson();
      for (final bad in <Map<String, Object?>>[
        {...good, 'version': 99},
        {...good, 'covers': 'oo'},
        {
          ...good,
          'mines': [1, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        },
        {
          ...good,
          'mines': [999],
        },
        {...good, 'firstTap': -1},
        {...good, 'clicks': 'many'},
        {...good, 'mines': null},
      ]) {
        expect(
          () => MinesweeperController.restore(bad, stats: stats, saves: saves),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });
}
