import 'package:all_for_games/games/sudoku/sudoku_controller.dart';
import 'package:all_for_games/games/sudoku/sudoku_deal.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/saves/game_save_store.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_stores.dart';
import 'sudoku_test_helpers.dart';

/// Lets the unawaited store writes finish.
Future<void> flush() => Future<void>.delayed(Duration.zero);

const gameId = SudokuController.gameId;

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

  SudokuController controller({
    SudokuLevel level = SudokuLevel.level1,
    int seed = 1,
    SudokuDeal? deal,
  }) => SudokuController(
    stats: stats,
    saves: saves,
    level: level,
    seed: seed,
    deal: deal,
    clock: () => now,
  );

  SudokuController restore() => SudokuController.restore(
    saves[gameId]!.data,
    stats: stats,
    saves: saves,
    clock: () => now,
  );

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  /// The empty cells of the game, in order.
  List<int> emptyCells(SudokuController game) => [
    for (var cell = 0; cell < 81; cell++)
      if (!game.state.isGiven(cell)) cell,
  ];

  /// A digit that does not solve [cell].
  int wrongDigit(SudokuController game, int cell) =>
      game.solution[cell] % 9 + 1;

  test('a digit goes in the selected cell; the time runs from then', () {
    final game = controller();
    final cell = emptyCells(game).first;
    expect(game.enter(5), isFalse, reason: 'no cell selected');
    wait(30);
    game.select(cell);
    expect(game.started, isFalse);
    expect(game.enter(game.solution[cell]), isTrue);
    expect(game.state.values[cell], game.solution[cell]);
    expect(game.started, isTrue);
    expect(game.moves, 1);
    wait(20);
    expect(game.playTime, const Duration(seconds: 20));
    game.select(0);
    expect(game.state.isGiven(0), isTrue);
    expect(game.enter(1), isFalse, reason: 'a given stays');
  });

  test('undo takes an action back, redo plays it again', () {
    final game = controller();
    final [first, second, ...] = emptyCells(game);
    game
      ..select(first)
      ..enter(game.solution[first])
      ..select(second)
      ..enter(1, note: true)
      ..enter(2, note: true);
    expect(game.canRedo, isFalse);
    expect(game.undo(), isTrue);
    expect(game.state.hasNote(second, 2), isFalse);
    expect(game.state.hasNote(second, 1), isTrue);
    expect(game.undo(), isTrue);
    expect(game.undo(), isTrue);
    expect(game.state.values[first], 0);
    expect(game.canUndo, isFalse);
    expect(game.redo(), isTrue);
    expect(game.state.values[first], game.solution[first]);
    expect(game.selected, first, reason: 'redo selects the cell it changes');
    // A new action forgets what was taken back.
    game
      ..select(second)
      ..enter(game.solution[second]);
    expect(game.canRedo, isFalse);
  });

  test('erase takes the digit, then the small numbers', () {
    final game = controller();
    final cell = emptyCells(game).first;
    game
      ..select(cell)
      ..enter(4, note: true)
      ..enter(wrongDigit(game, cell));
    expect(game.canErase, isTrue);
    expect(game.erase(), isTrue);
    expect(game.state.values[cell], 0);
    expect(game.state.notes[cell], 0, reason: 'the digit took them');
    expect(game.canErase, isFalse);
    expect(game.erase(), isFalse);
  });

  test('the record counts small numbers, erases and clashing digits', () async {
    final game = controller(deal: almostSolved(left: 2));
    final [first, last] = emptyCells(game);
    final given = SudokuGrid.peers[first].firstWhere(game.state.isGiven);
    game
      ..select(first)
      ..enter(3, note: true)
      ..enter(3, note: true)
      ..enter(7, note: true)
      // A digit already in the unit of the cell.
      ..enter(game.state.values[given])
      ..erase()
      ..enter(game.solution[first])
      ..undo()
      ..redo()
      ..select(last);
    wait(90);
    game.enter(game.solution[last]);
    expect(game.isWon, isTrue);
    await flush();
    final record = stats.records.single;
    expect(record.outcome, GameOutcome.won);
    expect(record.difficulty, 'level1');
    expect(record.variant, 'classic');
    expect(record.playTime, const Duration(seconds: 90));
    expect(record.moves, 4);
    expect(record.undos, 1);
    // Two cells to fill, 10 points each, level 1.
    expect(record.score, 2 * SudokuController.pointsPerCell);
    expect(record.details, {
      SudokuStatKeys.notesPlaced: 2,
      SudokuStatKeys.erases: 1,
      SudokuStatKeys.conflicts: 1,
    });
    expect(saves[gameId], isNull, reason: 'a won game is not saved');
    expect(game.enter(1), isFalse);
    expect(game.canUndo, isFalse);
  });

  test('the score is 10 points per cell filled, times the level', () async {
    final game = controller(level: SudokuLevel.level7, seed: 3);
    final cells = emptyCells(game);
    for (final cell in cells) {
      game
        ..select(cell)
        ..enter(game.solution[cell]);
    }
    await flush();
    expect(game.isWon, isTrue);
    expect(stats.records.single.score, cells.length * 10 * 7);
    expect(stats.records.single.difficulty, 'level7');
  });

  test('a saved game continues with its digits, notes and history', () async {
    final game = controller(level: SudokuLevel.level4, seed: 9);
    final [first, second, ...] = emptyCells(game);
    game
      ..select(first)
      ..enter(game.solution[first])
      ..select(second)
      ..enter(2, note: true)
      ..enter(wrongDigit(game, second))
      ..undo();
    wait(42);
    game.pause();
    await flush();

    final again = restore();
    expect(again.level, SudokuLevel.level4);
    expect(again.seed, 9);
    expect(again.state.values, game.state.values);
    expect(again.state.notes, game.state.notes);
    expect(again.selected, second);
    expect(again.playTime, const Duration(seconds: 42));
    expect(again.moves, 2);
    expect(again.redo(), isTrue);
    expect(again.state.values[second], wrongDigit(game, second));
    expect(again.undo() && again.undo() && again.undo(), isTrue);
    expect(again.state.values, again.state.givens);
  });

  test('a save with a changed given or another solution is refused', () {
    final game = controller()..save();
    final json = game.toJson();
    final givens = json['givens']! as String;
    final changed = '${givens[0] == '9' ? '8' : '9'}${givens.substring(1)}';
    for (final bad in [
      {...json, 'version': 99},
      {...json, 'values': changed},
      {...json, 'solution': '1${(json['solution']! as String).substring(1)}'},
      {...json, 'notes': List.filled(81, 1)},
      {
        ...json,
        'undo': [
          [81, 0, 0, 1, 0],
        ],
      },
    ]) {
      expect(
        () => SudokuController.restore(bad, stats: stats, saves: saves),
        throwsFormatException,
      );
    }
  });

  test('a new game cancels a started one, or records it abandoned', () async {
    final game = controller();
    game.newGame(abandon: true);
    await flush();
    expect(stats.records, isEmpty, reason: 'not started');

    var cell = emptyCells(game).first;
    game
      ..select(cell)
      ..enter(game.solution[cell])
      ..newGame(level: SudokuLevel.level2);
    await flush();
    expect(stats.records, isEmpty, reason: 'canceled');
    expect(game.level, SudokuLevel.level2);
    expect(game.moves, 0);

    cell = emptyCells(game).first;
    game
      ..select(cell)
      ..enter(game.solution[cell])
      ..newGame(abandon: true);
    await flush();
    final record = stats.records.single;
    expect(record.outcome, GameOutcome.abandoned);
    expect(record.difficulty, 'level2');
    expect(record.score, 1 * 10 * 2);
  });

  test('the arrows move the selection around the edges', () {
    final game = controller()..moveSelection(0, 1);
    expect(game.selected, 41, reason: 'from the center');
    game
      ..select(0)
      ..moveSelection(-1, 0);
    expect(game.selected, 72);
    game.moveSelection(0, -1);
    expect(game.selected, 80);
  });
}
