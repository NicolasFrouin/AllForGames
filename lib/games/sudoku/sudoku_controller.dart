import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'sudoku_deal.dart';
import 'sudoku_grid.dart';
import 'sudoku_level.dart';
import 'sudoku_solver.dart';
import 'sudoku_state.dart';

/// Keys of the Sudoku-specific counters in [GameRecord.details].
abstract final class SudokuStatKeys {
  static const notesPlaced = 'notesPlaced';
  static const erases = 'erases';
  static const conflicts = 'conflicts';

  static final labels = <String, String Function(AppLocalizations)>{
    notesPlaced: (l10n) => l10n.sudokuNotesPlaced,
    erases: (l10n) => l10n.sudokuErases,
    conflicts: (l10n) => l10n.sudokuConflicts,
  };
}

/// Runs one Sudoku at a time: the selected cell, the actions with undo and
/// redo, the play time. It saves the game after each action, so the player
/// can continue it later, and records it when it is won.
///
/// Every deal has one solution (see [SudokuDeal]): the grid is won when it
/// equals it.
class SudokuController extends ChangeNotifier {
  SudokuController({
    required this._stats,
    required this._saves,
    SudokuLevel level = SudokuLevel.level3,
    int? seed,
    SudokuDeal? deal,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(level: level, seed: seed, deal: deal);
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable Sudoku save.
  SudokuController.restore(
    Map<String, Object?> json, {
    required this._stats,
    required this._saves,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    try {
      _restore(json);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      // A missing field or a value of the wrong type.
      throw FormatException('Unreadable Sudoku save: $error');
    }
  }

  static const gameId = 'sudoku';

  /// The variant of the records: one rule set, twelve levels.
  static const variant = 'classic';

  /// Points for each cell the player filled right, times the level number.
  static const pointsPerCell = 10;

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;

  late SudokuState _state;
  late List<int> _solution;
  late SudokuLevel _level;
  late int _seed;
  late DateTime _startedAt;
  late PlayTimer _timer;
  int? _selected;
  bool _started = false;
  final _undo = <List<SudokuCellChange>>[];
  final _redo = <List<SudokuCellChange>>[];
  int _moves = 0;
  int _undos = 0;
  int _notesPlaced = 0;
  int _erases = 0;
  int _conflicts = 0;
  GameRecord? _result;

  SudokuState get state => _state;
  List<int> get solution => _solution;
  SudokuLevel get level => _level;
  int get seed => _seed;

  /// The cell the digits and the erase go to.
  int? get selected => _selected;

  /// The player has played: the timer runs from then, and a new game over
  /// this one can record it as abandoned.
  bool get started => _started;

  /// Digits placed and erased.
  int get moves => _moves;
  Duration get playTime => _timer.elapsed;
  bool get isWon => _result != null;
  bool get canUndo => !isWon && _undo.isNotEmpty;
  bool get canRedo => !isWon && _redo.isNotEmpty;
  bool get canErase => switch (_selected) {
    final cell? => !isWon && _state.erase(cell) != null,
    null => false,
  };

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  void select(int cell) {
    if (isWon || cell == _selected) return;
    _selected = cell;
    notifyListeners();
  }

  /// Moves the selection [rows] down and [columns] right, around the edges.
  void moveSelection(int rows, int columns) {
    final from = _selected ?? 40;
    select(
      (SudokuGrid.rowOf(from) + rows) % 9 * 9 +
          (SudokuGrid.columnOf(from) + columns) % 9,
    );
  }

  /// Puts [digit] in the selected cell, or with [note] writes it there as a
  /// small number (or takes it away). Returns whether the grid changed.
  bool enter(int digit, {bool note = false}) {
    final cell = _selected;
    if (isWon || cell == null) return false;
    if (note) {
      final next = _state.toggleNote(cell, digit);
      if (next == null) return false;
      if (next.hasNote(cell, digit)) _notesPlaced++;
      _commit(next);
      return true;
    }
    final next = _state.place(cell, digit);
    if (next == null) return false;
    _moves++;
    if (next.conflicts.contains(cell)) _conflicts++;
    _commit(next);
    return true;
  }

  /// Takes the player's digit, or else the small numbers, from the selected
  /// cell. Returns whether the grid changed.
  bool erase() {
    final cell = _selected;
    if (isWon || cell == null) return false;
    final next = _state.erase(cell);
    if (next == null) return false;
    _moves++;
    _erases++;
    _commit(next);
    return true;
  }

  bool undo() {
    if (!canUndo) return false;
    final changes = _undo.removeLast();
    _redo.add(changes);
    _undos++;
    _state = _state.applied(changes, undo: true);
    _selected = changes.first.cell;
    _played();
    return true;
  }

  bool redo() {
    if (!canRedo) return false;
    final changes = _redo.removeLast();
    _undo.add(changes);
    _state = _state.applied(changes);
    _selected = changes.first.cell;
    _played();
    return true;
  }

  /// Also saves the game: the app may never come back from a pause.
  void pause() {
    _timer.pause();
    save();
  }

  void resume() {
    if (_started && !isWon) _timer.start();
  }

  /// Saves the game so the player can continue it later. A won game is not
  /// saved: it is in the statistics.
  void save() {
    if (isWon) return;
    unawaited(
      _saves.save(
        SavedGame(
          gameId: gameId,
          moves: _moves,
          playTime: _timer.elapsed,
          savedAt: _clock(),
          data: toJson(),
        ),
      ),
    );
  }

  /// Deals a new game and saves it. With [abandon], the current game counts
  /// as abandoned if the player has started it and did not finish it;
  /// else it leaves no record.
  ///
  /// [level] defaults to the current one; [deal] replaces the deal of the
  /// seed (used by tests).
  void newGame({
    SudokuLevel? level,
    int? seed,
    SudokuDeal? deal,
    bool abandon = false,
  }) {
    if (abandon && _started && !isWon) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(level: level ?? _level, seed: seed, deal: deal);
    save();
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'level': _level.name,
    'givens': SudokuGrid.encode(_state.givens),
    'solution': SudokuGrid.encode(_solution),
    'values': SudokuGrid.encode(_state.values),
    'notes': _state.notes,
    'selected': _selected,
    'undo': [for (final changes in _undo) _encodeChanges(changes)],
    'redo': [for (final changes in _redo) _encodeChanges(changes)],
    'started': _started,
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'moves': _moves,
    'undos': _undos,
    'notesPlaced': _notesPlaced,
    'erases': _erases,
    'conflicts': _conflicts,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown Sudoku save version ${json['version']}');
    }
    final givens = SudokuGrid.decode(json['givens'] as String);
    final solution = SudokuGrid.decode(json['solution'] as String);
    final values = SudokuGrid.decode(json['values'] as String);
    final notes = (json['notes'] as List<Object?>).cast<int>();
    final solutions = solveSudoku(givens, limit: 2);
    if (solutions.length != 1 || !listEquals(solutions.single, solution)) {
      throw const FormatException('Sudoku save without one solution');
    }
    if (notes.length != SudokuGrid.cellCount ||
        notes.any((mask) => mask & ~0x3FE != 0) ||
        [
          for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
            givens[cell] == 0 || values[cell] == givens[cell],
        ].contains(false)) {
      throw const FormatException('Bad Sudoku grid');
    }
    _state = SudokuState(givens, values: values, notes: notes);
    if (listEquals(values, solution)) {
      throw const FormatException('Finished Sudoku game');
    }
    _solution = solution;
    _seed = json['seed'] as int;
    _level = SudokuLevel.values.byName(json['level'] as String);
    final selected = json['selected'] as int?;
    if (selected != null &&
        (selected < 0 || selected >= SudokuGrid.cellCount)) {
      throw FormatException('Bad Sudoku cell $selected');
    }
    _selected = selected;
    _undo
      ..clear()
      ..addAll([
        for (final changes in json['undo'] as List<Object?>)
          _decodeChanges(changes),
      ]);
    _redo
      ..clear()
      ..addAll([
        for (final changes in json['redo'] as List<Object?>)
          _decodeChanges(changes),
      ]);
    _started = json['started'] as bool;
    _startedAt = DateTime.parse(json['startedAt'] as String);
    _timer = PlayTimer(
      clock: _clock,
      elapsed: Duration(milliseconds: json['playTimeMs'] as int),
    );
    if (_started) _timer.start();
    _moves = json['moves'] as int;
    _undos = json['undos'] as int;
    _notesPlaced = json['notesPlaced'] as int;
    _erases = json['erases'] as int;
    _conflicts = json['conflicts'] as int;
    _result = null;
  }

  static List<int> _encodeChanges(List<SudokuCellChange> changes) => [
    for (final change in changes) ...[
      change.cell,
      change.valueBefore,
      change.notesBefore,
      change.value,
      change.notes,
    ],
  ];

  static List<SudokuCellChange> _decodeChanges(Object? json) {
    final numbers = (json as List<Object?>).cast<int>();
    if (numbers.isEmpty || numbers.length % 5 != 0) {
      throw const FormatException('Bad Sudoku history');
    }
    final changes = <SudokuCellChange>[];
    for (var i = 0; i < numbers.length; i += 5) {
      final cell = numbers[i];
      if (cell < 0 || cell >= SudokuGrid.cellCount) {
        throw FormatException('Bad Sudoku cell $cell');
      }
      changes.add((
        cell: cell,
        valueBefore: numbers[i + 1],
        notesBefore: numbers[i + 2],
        value: numbers[i + 3],
        notes: numbers[i + 4],
      ));
    }
    return changes;
  }

  void _start({required SudokuLevel level, int? seed, SudokuDeal? deal}) {
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _level = level;
    final dealt = deal ?? SudokuDeal.deal(level, _seed);
    _state = SudokuState(dealt.givens);
    _solution = dealt.solution;
    _selected = null;
    _undo.clear();
    _redo.clear();
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock);
    _started = false;
    _moves = 0;
    _undos = 0;
    _notesPlaced = 0;
    _erases = 0;
    _conflicts = 0;
    _result = null;
  }

  void _commit(SudokuState next) {
    _undo.add(_state.changesTo(next));
    _redo.clear();
    _state = next;
    _played();
  }

  void _played() {
    if (!_started) {
      _started = true;
      // The game starts with the first action: the time before it is not play.
      _startedAt = _clock();
      _timer.start();
    }
    if (listEquals(_state.values, _solution)) {
      _timer.pause();
      _selected = null;
      final record = _record(GameOutcome.won);
      _result = record;
      unawaited(_stats.add(record));
      unawaited(_saves.remove(gameId));
    } else {
      save();
    }
    notifyListeners();
  }

  GameRecord _record(GameOutcome outcome) {
    var right = 0;
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
      if (!_state.isGiven(cell) && _state.values[cell] == _solution[cell]) {
        right++;
      }
    }
    return GameRecord(
      gameId: gameId,
      variant: variant,
      seed: _seed,
      startedAt: _startedAt,
      endedAt: _clock(),
      playTime: _timer.elapsed,
      outcome: outcome,
      moves: _moves,
      undos: _undos,
      score: right * pointsPerCell * _level.number,
      difficulty: _level.name,
      details: {
        SudokuStatKeys.notesPlaced: _notesPlaced,
        SudokuStatKeys.erases: _erases,
        SudokuStatKeys.conflicts: _conflicts,
      },
    );
  }
}
