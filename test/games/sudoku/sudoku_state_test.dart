import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sudoku_test_helpers.dart';

void main() {
  final givens = SudokuGrid.decode(seed1Level1Givens);
  final empty = givens.indexOf(0);
  final given = givens.indexWhere((value) => value != 0);

  test('a digit goes in an empty cell, not on a given or on itself', () {
    final state = SudokuState(givens);
    final next = state.place(empty, 4)!;
    expect(next.values[empty], 4);
    expect(next.place(empty, 4), isNull);
    expect(next.place(empty, 6)!.values[empty], 6);
    expect(state.place(given, 1), isNull);
    expect(state.values, givens, reason: 'the state does not change');
  });

  test('a digit clears the small numbers of its cell, and itself around', () {
    final cell = empty;
    final peer = SudokuGrid.peers[cell].firstWhere((p) => givens[p] == 0);
    final other = List.generate(81, (i) => i).firstWhere(
      (i) => i != cell && givens[i] == 0 && !SudokuGrid.peers[cell].contains(i),
    );
    var state = SudokuState(givens);
    for (final (target, digit) in [
      (cell, 1),
      (cell, 2),
      (peer, 4),
      (peer, 5),
      (other, 4),
    ]) {
      state = state.toggleNote(target, digit)!;
    }
    final next = state.place(cell, 4)!;
    expect(next.notes[cell], 0);
    expect(next.hasNote(peer, 4), isFalse);
    expect(next.hasNote(peer, 5), isTrue);
    expect(next.hasNote(other, 4), isTrue, reason: 'not in its units');
  });

  test('erase takes the digit first, then the small numbers', () {
    final state = SudokuState(givens)
        .toggleNote(empty, 3)!
        .toggleNote(empty, 7)!;
    expect(state.erase(empty)!.notes[empty], 0);
    final placed = state.place(empty, 5)!;
    final erased = placed.erase(empty)!;
    expect(erased.values[empty], 0);
    expect(erased.erase(empty), isNull, reason: 'nothing left');
    expect(state.erase(given), isNull);
  });

  test('small numbers go in empty cells only, and toggle', () {
    final state = SudokuState(givens);
    expect(state.toggleNote(given, 2), isNull);
    final noted = state.toggleNote(empty, 2)!;
    expect(noted.hasNote(empty, 2), isTrue);
    expect(noted.toggleNote(empty, 2)!.hasNote(empty, 2), isFalse);
    expect(noted.place(empty, 9)!.toggleNote(empty, 2), isNull);
  });

  test('a digit twice in a unit marks the cells that hold it there', () {
    final digit = givens[given];
    final peer = SudokuGrid.peers[given].firstWhere((p) => givens[p] == 0);
    final next = SudokuState(givens).place(peer, digit)!;
    expect(next.conflicts, containsAll([given, peer]));
    for (final cell in next.conflicts) {
      expect(next.values[cell], digit);
      expect(SudokuGrid.peers[peer], contains(cell == peer ? given : cell));
    }
    expect(next.erase(peer)!.conflicts, isEmpty);
  });

  test('the changes of an action take it back and play it again', () {
    final before = SudokuState(givens).toggleNote(empty, 4)!;
    final peer = SudokuGrid.peers[empty].firstWhere((p) => givens[p] == 0);
    final start = before.toggleNote(peer, 6)!;
    final after = start.place(empty, 6)!;
    final changes = start.changesTo(after);
    expect(
      changes.map((change) => change.cell),
      [
        ...{empty, peer},
      ]..sort(),
    );
    final undone = after.applied(changes, undo: true);
    expect(undone.values, start.values);
    expect(undone.notes, start.notes);
    final redone = undone.applied(changes);
    expect(redone.values, after.values);
    expect(redone.notes, after.notes);
  });

  test('a grid is full when every cell has a digit', () {
    final solution = SudokuGrid.decode(seed1Level1Solution);
    var state = SudokuState(givens);
    expect(state.isFull, isFalse);
    for (var cell = 0; cell < 81; cell++) {
      if (givens[cell] == 0) state = state.place(cell, solution[cell])!;
    }
    expect(state.isFull, isTrue);
    expect(state.conflicts, isEmpty);
    expect(state.countOf(5), 9);
  });
}
