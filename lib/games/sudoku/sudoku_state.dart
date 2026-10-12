import 'sudoku_grid.dart';

/// One cell before and after an action: its digit (0 for none) and its
/// small numbers (bit d for d).
typedef SudokuCellChange = ({
  int cell,
  int valueBefore,
  int notesBefore,
  int value,
  int notes,
});

/// A Sudoku in play: the [givens], the digits on the grid ([values], the
/// givens too) and the small numbers the player wrote ([notes], bit d for
/// the digit d).
///
/// Immutable: an action returns a new state, or null when it changes
/// nothing. The rules let the player place any digit in an empty cell: a
/// digit that is already in the cell's row, column or box shows as a
/// [conflicts] cell, and the grid is won only when it equals its solution.
class SudokuState {
  SudokuState(this.givens, {List<int>? values, List<int>? notes})
    : values = List.unmodifiable(values ?? givens),
      notes = List.unmodifiable(notes ?? List.filled(SudokuGrid.cellCount, 0));

  final List<int> givens;
  final List<int> values;
  final List<int> notes;

  bool isGiven(int cell) => givens[cell] != 0;

  bool hasNote(int cell, int digit) => notes[cell] & (1 << digit) != 0;

  /// The cells whose digit is also in their row, column or box.
  late final Set<int> conflicts = {
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
      if (values[cell] != 0 &&
          SudokuGrid.peers[cell].any((peer) => values[peer] == values[cell]))
        cell,
  };

  bool get isFull => !values.contains(0);

  /// How many cells hold [digit].
  int countOf(int digit) => values.where((value) => value == digit).length;

  /// Puts [digit] in [cell] (over the player's digit or small numbers there)
  /// and takes it from the small numbers of the cells in the same row,
  /// column and box.
  SudokuState? place(int cell, int digit) {
    if (isGiven(cell) || values[cell] == digit) return null;
    final bit = 1 << digit;
    final nextNotes = [...notes];
    nextNotes[cell] = 0;
    for (final peer in SudokuGrid.peers[cell]) {
      nextNotes[peer] &= ~bit;
    }
    return SudokuState(
      givens,
      values: [...values]..[cell] = digit,
      notes: nextNotes,
    );
  }

  /// Takes the player's digit from [cell], or else its small numbers.
  SudokuState? erase(int cell) {
    if (isGiven(cell)) return null;
    if (values[cell] != 0) {
      return SudokuState(givens, values: [...values]..[cell] = 0, notes: notes);
    }
    if (notes[cell] == 0) return null;
    return SudokuState(givens, values: values, notes: [...notes]..[cell] = 0);
  }

  /// Writes the small number [digit] in an empty [cell], or takes it away.
  SudokuState? toggleNote(int cell, int digit) {
    if (values[cell] != 0) return null;
    return SudokuState(
      givens,
      values: values,
      notes: [...notes]..[cell] ^= 1 << digit,
    );
  }

  /// The cells that differ in [next], for undo and redo.
  List<SudokuCellChange> changesTo(SudokuState next) => [
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
      if (values[cell] != next.values[cell] || notes[cell] != next.notes[cell])
        (
          cell: cell,
          valueBefore: values[cell],
          notesBefore: notes[cell],
          value: next.values[cell],
          notes: next.notes[cell],
        ),
  ];

  /// This state with [changes] made, or taken back when [undo].
  SudokuState applied(List<SudokuCellChange> changes, {bool undo = false}) {
    final nextValues = [...values];
    final nextNotes = [...notes];
    for (final change in changes) {
      nextValues[change.cell] = undo ? change.valueBefore : change.value;
      nextNotes[change.cell] = undo ? change.notesBefore : change.notes;
    }
    return SudokuState(givens, values: nextValues, notes: nextNotes);
  }
}
