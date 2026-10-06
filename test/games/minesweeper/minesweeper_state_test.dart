import 'package:all_for_games/games/minesweeper/minesweeper_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'minesweeper_test_helpers.dart';

void main() {
  group('open', () {
    test('a cell with no mine around opens the area around it', () {
      final state = cornerBoard.open(cornerTap)!;

      expect(state.isOpen(cornerTap), isTrue);
      // Every safe cell but the two walled in by mines.
      expect(safeHidden(state), [0, 1]);
      expect(state.openCount, 25 - 4 - 2);
      expect(state.isOver, isFalse);
    });

    test('a number opens only itself', () {
      final state = cornerBoard.open(at(cornerBoard, 0, 2))!;

      expect(state.countAt(at(state, 0, 2)), 2);
      expect(state.openCount, 1);
    });

    test('a flag stops the area from opening its cell', () {
      final flagged = cornerBoard.toggleFlag(at(cornerBoard, 4, 0))!;
      final state = flagged.open(cornerTap)!;

      expect(state.isFlagged(at(state, 4, 0)), isTrue);
      expect(safeHidden(state), [0, 1, at(state, 4, 0)]);
    });

    test('a mine loses the game', () {
      final state = cornerBoard.open(at(cornerBoard, 2, 0))!;

      expect(state.isLost, isTrue);
      expect(state.exploded, at(state, 2, 0));
      expect(state.open(cornerTap), isNull);
      expect(state.toggleFlag(cornerTap), isNull);
    });

    test('does nothing on an open or flagged cell, or before the mines', () {
      final open = cornerBoard.open(cornerTap)!;
      expect(open.open(cornerTap), isNull);
      expect(cornerBoard.toggleFlag(0)!.open(0), isNull);
      expect(MinesweeperState.empty(9, 9, 10).open(0), isNull);
    });

    test('opening every safe cell wins', () {
      final state = cornerBoard.open(cornerTap)!.open(0)!;
      expect(state.isWon, isFalse);

      final won = state.open(1)!;
      expect(won.isWon, isTrue);
      expect(won.isOver, isTrue);
      expect(won.flagMines().flagCount, 4);
    });
  });

  test('a flag goes on a hidden cell and comes off', () {
    final flagged = cornerBoard.toggleFlag(0)!;
    expect(flagged.isFlagged(0), isTrue);
    expect(flagged.flagCount, 1);

    expect(flagged.toggleFlag(0)!.isFlagged(0), isFalse);
    expect(cornerBoard.open(cornerTap)!.toggleFlag(cornerTap), isNull);
  });

  group('chord', () {
    // The 2 at (0, 2) touches the mines (0, 1) and (1, 1).
    final two = at(cornerBoard, 0, 2);
    final opened = cornerBoard.open(two)!;

    test('opens the other neighbors once the flags match the number', () {
      expect(opened.chordCells(two), isEmpty);
      final oneFlag = opened.toggleFlag(at(opened, 0, 1))!;
      expect(oneFlag.chord(two), isNull);

      final flags = oneFlag.toggleFlag(at(opened, 1, 1))!;
      expect(flags.chordCells(two), [
        at(opened, 1, 2),
        at(opened, 0, 3),
        at(opened, 1, 3),
      ]);
      final state = flags.chord(two)!;
      // (0, 3) has no mine around: it opens the area around it.
      expect(state.isOpen(at(state, 1, 2)), isTrue);
      expect(state.isOpen(cornerTap), isTrue);
      expect(state.isLost, isFalse);
    });

    test('with a wrong flag, opens a mine', () {
      final wrong = opened
          .toggleFlag(at(opened, 0, 1))!
          .toggleFlag(at(opened, 1, 3))!;
      final state = wrong.chord(two)!;

      expect(state.isLost, isTrue);
      expect(state.exploded, at(state, 1, 1));
    });
  });

  test('3BV counts the clicks that clear the board', () {
    // One area, and the two walled cells: 3 clicks.
    expect(cornerBoard.boardValue, 3);
    expect(cornerBoard.boardValueSolved, 0);

    final state = cornerBoard.open(cornerTap)!;
    expect(state.boardValueSolved, 1);
    expect(state.open(0)!.boardValueSolved, 2);

    // Isolated numbers count one each.
    expect(boardOf(['.*.']).boardValue, 2);
    expect(boardOf(['*.*']).boardValue, 1);
  });

  test('covers survive a save', () {
    final state = cornerBoard.open(cornerTap)!.toggleFlag(0)!;
    final text = state.encodeCovers();
    expect(text, 'f--oo---oo${'o' * 15}');

    final copy = MinesweeperState.withMines(5, 5, state.mines, covers: text);
    expect(copy.encodeCovers(), text);
    expect(copy.isFlagged(0), isTrue);
    expect(copy.openCount, state.openCount);
    expect(
      () => MinesweeperState.withMines(5, 5, state.mines, covers: 'x' * 25),
      throwsFormatException,
    );
  });
}
