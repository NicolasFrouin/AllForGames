import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_difficulty.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_generator.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_solver.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'minesweeper_test_helpers.dart';

/// A board as the player sees it: `*` a hidden mine, `#` a hidden safe
/// cell, `o` an open cell.
MinesweeperState seen(List<String> rows) {
  final text = rows.join();
  return MinesweeperState.withMines(rows.first.length, rows.length, [
    for (var cell = 0; cell < text.length; cell++)
      if (text[cell] == '*') cell,
  ], covers: text.replaceAll(RegExp('[*#]'), '-'));
}

/// What the solver knows matches the board: no mine is called safe, no
/// safe cell a mine.
void expectSound(MinesweeperSolver solver, MinesweeperState state) {
  for (var cell = 0; cell < state.length; cell++) {
    if (solver.isKnownSafe(cell)) {
      expect(state.isMine(cell), isFalse, reason: 'cell $cell is a mine');
    } else if (!solver.isUnknown(cell)) {
      expect(state.isMine(cell), isTrue, reason: 'cell $cell is safe');
    }
  }
}

/// A random board (not made to be solved) opened on a cell with no mine
/// around, or null when the seed gives none.
MinesweeperState? randomOpening(MinesweeperDifficulty difficulty, int seed) {
  final (columns, rows) = difficulty.size();
  final cells = shuffledCards(seed, List.generate(columns * rows, (i) => i));
  final state = MinesweeperState.withMines(
    columns,
    rows,
    cells.take(difficulty.mines),
  );
  for (var cell = 0; cell < state.length; cell++) {
    if (!state.isMine(cell) && state.countAt(cell) == 0) {
      return state.open(cell);
    }
  }
  return null;
}

void main() {
  test('a hidden cell that no number reaches is safe once a number holds '
      'every mine left', () {
    // One mine: the 1 holds it, so the cells beyond it are safe.
    final state = seen(['*####', '#o###', '#####']);

    final safe = MinesweeperSolver.of(state).findSafe();
    expect(safe, at(state, 3, 0));
  });

  test('two numbers prove what neither proves alone (1-2-1)', () {
    // The 1 2 1 under the top row: the middle cell is safe. The 3s below
    // see only mines; the cells further down are too many to try every
    // way to place the mines.
    final state = seen([
      '*#*',
      'ooo',
      'ooo',
      '***',
      '###',
      '#*#',
      '*##',
      '###',
      '#*#',
      '###',
      '##*',
      '*##',
    ]);

    expect(MinesweeperSolver.of(state).findSafe(), at(state, 1, 0));
  });

  test('a 50/50 proves nothing', () {
    final state = seen(['*#', 'oo']);

    final solver = MinesweeperSolver.of(state);
    expect(solver.findSafe(), isNull);
    expect(solver.solve(), isFalse);
  });

  test('flags do not count: a wrongly flagged cell can be the hint', () {
    final state = cornerBoard.open(cornerTap)!.toggleFlag(0)!.toggleFlag(1)!;

    expect(MinesweeperSolver.of(state).findSafe(), anyOf(0, 1));
  });

  test('only proves what is true, on random boards', () {
    var boards = 0;
    for (final difficulty in MinesweeperDifficulty.values) {
      for (var seed = 1; seed <= 150; seed++) {
        final state = randomOpening(difficulty, seed);
        if (state == null) continue;
        final solver = MinesweeperSolver.of(state)..solve();
        expectSound(solver, state);
        boards++;
      }
    }
    expect(boards, greaterThan(300));
  });

  test('following the hints clears every generated board', () {
    for (final difficulty in MinesweeperDifficulty.values) {
      final (columns, rows) = difficulty.size();
      for (var seed = 1; seed <= 15; seed++) {
        final tap = DealRandom(seed).nextInt(columns * rows);
        final deal = generateMines(
          columns: columns,
          rows: rows,
          mineCount: difficulty.mines,
          seed: seed,
          firstTap: tap,
        );
        var state = MinesweeperState.withMines(
          columns,
          rows,
          deal.mines,
        ).open(tap)!;
        while (!state.isWon) {
          final hint = MinesweeperSolver.of(state).findSafe();
          expect(hint, isNotNull, reason: '$difficulty, seed $seed');
          state = state.open(hint!)!;
          expect(state.isLost, isFalse);
        }
      }
    }
  });
}
