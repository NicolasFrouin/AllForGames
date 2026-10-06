import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'minesweeper_difficulty.dart';
import 'minesweeper_generator.dart';
import 'minesweeper_solver.dart';
import 'minesweeper_state.dart';

/// What changed the board last, so the board can animate it.
enum MinesweeperAction { none, deal, open, flag, unflag, lose, win }

/// Keys of the Minesweeper-specific counters in [GameRecord.details].
abstract final class MinesweeperStatKeys {
  static const boardValue = 'boardValue';
  static const efficiency = 'efficiency';
  static const chords = 'chords';
  static const flagsPlaced = 'flagsPlaced';
  static const hints = 'hints';
  static const cellsRevealed = 'cellsRevealed';

  static final labels = <String, String Function(AppLocalizations)>{
    boardValue: (l10n) => l10n.minesweeperBoardValue,
    efficiency: (l10n) => l10n.minesweeperEfficiency,
    chords: (l10n) => l10n.minesweeperChords,
    flagsPlaced: (l10n) => l10n.minesweeperFlagsPlaced,
    hints: (l10n) => l10n.minesweeperHints,
    cellsRevealed: (l10n) => l10n.minesweeperCellsRevealed,
  };
}

/// Runs one Minesweeper game at a time. It saves the game after each action,
/// so the player can continue it later, and records it when it is won or
/// lost.
///
/// The mines are placed at the first tap, around it (see [generateMines]):
/// the board can then be cleared by logic alone, and a hint shows a cell
/// that logic proves safe.
class MinesweeperController extends ChangeNotifier {
  MinesweeperController({
    required this._stats,
    required this._saves,
    MinesweeperDifficulty difficulty = MinesweeperDifficulty.medium,
    bool turned = false,
    int? seed,
    MinesweeperState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(
      difficulty: difficulty,
      turned: turned,
      seed: seed,
      initialState: initialState,
    );
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable Minesweeper save.
  MinesweeperController.restore(
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
      throw FormatException('Unreadable Minesweeper save: $error');
    }
  }

  static const gameId = 'minesweeper';

  /// The variant of the records: one rule set, three levels.
  static const variant = 'classic';

  /// Points per unit of [MinesweeperState.boardValue] cleared.
  static const pointsPerBoardValue = 10;

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;

  late MinesweeperState _state;
  late int _seed;
  late MinesweeperDifficulty _difficulty;
  late bool _turned;
  late DateTime _startedAt;
  late PlayTimer _timer;
  int? _firstTap;
  bool _started = false;
  int _clicks = 0;
  int _chords = 0;
  int _flagsPlaced = 0;
  int _hints = 0;
  GameRecord? _result;
  int? _hintCell;
  int _hintSerial = 0;
  MinesweeperAction _lastAction = MinesweeperAction.none;
  int _actionSerial = 0;
  int? _lastCell;

  MinesweeperState get state => _state;
  int get seed => _seed;
  MinesweeperDifficulty get difficulty => _difficulty;

  /// Rows and columns swapped (a tall screen).
  bool get turned => _turned;

  /// The cell the player opened first, where the mines were placed around.
  int? get firstTap => _firstTap;

  /// The player has played: the timer runs from then, and a new game over
  /// this one records it as abandoned.
  bool get started => _started;

  /// Opens, chords and flags that changed the board.
  int get clicks => _clicks;
  int get hints => _hints;
  int get minesLeft => _state.mineCount - _state.flagCount;
  Duration get playTime => _timer.elapsed;
  bool get isOver => _state.isOver;
  bool get canHint => _state.hasMines && !_state.isOver;

  /// The record of the won or lost game, or null while the game runs.
  GameRecord? get result => _result;

  /// The safe cell of the last hint, until the next action.
  int? get hintCell => _hintCell;

  /// Changes at every hint, so the board shows each one once.
  int get hintSerial => _hintSerial;

  MinesweeperAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Where the last action happened: a reveal spreads from there.
  int? get lastCell => _lastCell;

  /// Opens a hidden cell (the first one places the mines), or chords on an
  /// open number. Returns whether the board changed.
  bool open(int cell) {
    if (_state.isOver) return false;
    if (_state.isOpen(cell)) return chord(cell);
    if (!_state.hasMines) _placeMines(cell);
    final next = _state.open(cell);
    if (next == null) return false;
    _act(next, cell);
    return true;
  }

  /// Opens the other hidden neighbors of an open number whose flags around
  /// match it. Returns whether the board changed.
  bool chord(int cell) {
    final next = _state.chord(cell);
    if (next == null) return false;
    _chords++;
    _act(next, cell);
    return true;
  }

  /// Flags a hidden cell or takes its flag back. Flags wait for the first
  /// tap: before it, the board has no mines.
  bool toggleFlag(int cell) {
    if (!_state.hasMines) return false;
    final next = _state.toggleFlag(cell);
    if (next == null) return false;
    if (next.isFlagged(cell)) _flagsPlaced++;
    _act(next, cell);
    return true;
  }

  /// Shows a hidden cell that logic proves safe from what is open, or null
  /// when the game is not running.
  int? hint() {
    if (!canHint) return null;
    final cell = MinesweeperSolver.of(_state).findSafe();
    if (cell == null) return null;
    _hints++;
    _hintCell = cell;
    _hintSerial++;
    _startTimer();
    save();
    notifyListeners();
    return cell;
  }

  /// After a loss: the same board again, with the first tap opened. The
  /// timer starts at the next action.
  void retry() {
    final firstTap = _firstTap;
    if (!_state.isLost || firstTap == null) return;
    final mines = _state.mines;
    _start(
      difficulty: _difficulty,
      turned: _turned,
      seed: _seed,
      initialState: MinesweeperState.withMines(
        _state.columns,
        _state.rows,
        mines,
      ),
    );
    _firstTap = firstTap;
    if (!_state.isMine(firstTap)) {
      _state = _state.open(firstTap)!;
      _clicks = 1;
    }
    _lastCell = firstTap;
    save();
    notifyListeners();
  }

  /// Also saves the game: the app may never come back from a pause.
  void pause() {
    _timer.pause();
    save();
  }

  void resume() {
    if (_started && !_state.isOver) _timer.start();
  }

  /// Saves the game so the player can continue it later. A game won or lost
  /// is not saved: it is in the statistics.
  void save() {
    if (_state.isOver) return;
    unawaited(
      _saves.save(
        SavedGame(
          gameId: gameId,
          moves: _clicks,
          playTime: _timer.elapsed,
          savedAt: _clock(),
          data: toJson(),
        ),
      ),
    );
  }

  /// Deals a new game and saves it. The current game counts as abandoned if
  /// the player has started it and did not finish it.
  ///
  /// [difficulty] and [turned] default to the current ones.
  void newGame({
    MinesweeperDifficulty? difficulty,
    bool? turned,
    int? seed,
    MinesweeperState? initialState,
  }) {
    if (_started && !_state.isOver) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? _difficulty,
      turned: turned ?? _turned,
      seed: seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'difficulty': _difficulty.name,
    'turned': _turned,
    'columns': _state.columns,
    'rows': _state.rows,
    'mineCount': _state.mineCount,
    'firstTap': _firstTap,
    'mines': _state.hasMines ? _state.mines : null,
    'covers': _state.encodeCovers(),
    'started': _started,
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'clicks': _clicks,
    'chords': _chords,
    'flagsPlaced': _flagsPlaced,
    'hints': _hints,
    'hintCell': _hintCell,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException(
        'Unknown Minesweeper save version ${json['version']}',
      );
    }
    final columns = json['columns'] as int;
    final rows = json['rows'] as int;
    final mineCount = json['mineCount'] as int;
    final length = columns * rows;
    final covers = json['covers'] as String;
    final mines = (json['mines'] as List<Object?>?)?.cast<int>();
    int? cell(Object? value) {
      if (value == null) return null;
      final cell = value as int;
      if (cell < 0 || cell >= length) {
        throw FormatException('Bad Minesweeper cell $cell');
      }
      return cell;
    }

    if (columns <= 0 || rows <= 0 || covers.length != length) {
      throw const FormatException('Bad Minesweeper board size');
    }
    if (mines == null) {
      if (covers.contains(RegExp('[^-]'))) {
        throw const FormatException('Minesweeper cells open before the mines');
      }
      _state = MinesweeperState.empty(columns, rows, mineCount);
    } else {
      if (mines.length != mineCount ||
          mines.toSet().length != mines.length ||
          mines.any((mine) => cell(mine) == null)) {
        throw const FormatException('Bad Minesweeper mines');
      }
      _state = MinesweeperState.withMines(columns, rows, mines, covers: covers);
      if (_state.isOver) {
        throw const FormatException('Finished Minesweeper game');
      }
    }
    _seed = json['seed'] as int;
    _difficulty = MinesweeperDifficulty.values.byName(
      json['difficulty'] as String,
    );
    _turned = json['turned'] as bool;
    _firstTap = cell(json['firstTap']);
    _started = json['started'] as bool;
    _startedAt = DateTime.parse(json['startedAt'] as String);
    _timer = PlayTimer(
      clock: _clock,
      elapsed: Duration(milliseconds: json['playTimeMs'] as int),
    );
    if (_started) _timer.start();
    _clicks = json['clicks'] as int;
    _chords = json['chords'] as int;
    _flagsPlaced = json['flagsPlaced'] as int;
    _hints = json['hints'] as int;
    _hintCell = cell(json['hintCell']);
  }

  void _start({
    required MinesweeperDifficulty difficulty,
    required bool turned,
    int? seed,
    MinesweeperState? initialState,
  }) {
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _difficulty = difficulty;
    _turned = turned;
    final (columns, rows) = difficulty.size(turned: turned);
    _state =
        initialState ?? MinesweeperState.empty(columns, rows, difficulty.mines);
    _firstTap = null;
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock);
    _started = false;
    _clicks = 0;
    _chords = 0;
    _flagsPlaced = 0;
    _hints = 0;
    _result = null;
    _hintCell = null;
    _lastCell = null;
    _lastAction = MinesweeperAction.deal;
    _actionSerial++;
  }

  void _placeMines(int firstTap) {
    final deal = generateMines(
      columns: _state.columns,
      rows: _state.rows,
      mineCount: _state.mineCount,
      seed: _seed,
      firstTap: firstTap,
    );
    _firstTap = firstTap;
    _state = MinesweeperState.withMines(
      _state.columns,
      _state.rows,
      deal.mines,
    );
  }

  void _startTimer() {
    if (_started) return;
    _started = true;
    // The game starts with the first action: the time before it is not play.
    _startedAt = _clock();
    _timer.start();
  }

  void _act(MinesweeperState next, int cell) {
    _startTimer();
    _firstTap ??= cell;
    _clicks++;
    _lastCell = cell;
    _hintCell = null;
    _actionSerial++;
    final opened = next.openCount > _state.openCount;
    if (next.isLost) {
      _state = next;
      _lastAction = MinesweeperAction.lose;
      _finish(GameOutcome.lost);
    } else if (next.isWon) {
      _state = next.flagMines();
      _lastAction = MinesweeperAction.win;
      _finish(GameOutcome.won);
    } else {
      _lastAction = opened
          ? MinesweeperAction.open
          : next.isFlagged(cell)
          ? MinesweeperAction.flag
          : MinesweeperAction.unflag;
      _state = next;
      save();
    }
    notifyListeners();
  }

  void _finish(GameOutcome outcome) {
    _timer.pause();
    final record = _record(outcome);
    _result = record;
    unawaited(_stats.add(record));
    unawaited(_saves.remove(gameId));
  }

  GameRecord _record(GameOutcome outcome) {
    final solved = _state.boardValueSolved;
    return GameRecord(
      gameId: gameId,
      variant: variant,
      seed: _seed,
      startedAt: _startedAt,
      endedAt: _clock(),
      playTime: _timer.elapsed,
      outcome: outcome,
      moves: _clicks,
      undos: 0,
      score: solved * pointsPerBoardValue,
      difficulty: _difficulty.name,
      details: {
        MinesweeperStatKeys.boardValue: _state.boardValue,
        // Board value cleared per 100 clicks (flags and chords count):
        // chords can take it above 100.
        MinesweeperStatKeys.efficiency: _clicks == 0
            ? 0
            : (solved * 100 / _clicks).round(),
        MinesweeperStatKeys.chords: _chords,
        MinesweeperStatKeys.flagsPlaced: _flagsPlaced,
        MinesweeperStatKeys.hints: _hints,
        MinesweeperStatKeys.cellsRevealed: _state.openSafeCount,
      },
    );
  }
}
