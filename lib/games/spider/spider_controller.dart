import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../cards/playing_card.dart';
import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'spider_deal_picker.dart';
import 'spider_difficulty.dart';
import 'spider_state.dart';

enum SpiderInput { tap, drag }

/// What changed the board last, so the board can animate it.
enum SpiderAction { none, deal, stockDeal, move, undo }

/// Keys of the Spider-specific counters in [GameRecord.details].
abstract final class SpiderStatKeys {
  static const stockDeals = 'stockDeals';
  static const runsCompleted = 'runsCompleted';
  static const cardsRevealed = 'cardsRevealed';
  static const emptyColumnUses = 'emptyColumnUses';
  static const longestRunMoved = 'longestRunMoved';
  static const tapMoves = 'tapMoves';
  static const dragMoves = 'dragMoves';
  static const timeToFirstMoveMs = 'timeToFirstMoveMs';
  static const longestThinkMs = 'longestThinkMs';

  static final labels = <String, String Function(AppLocalizations)>{
    stockDeals: (l10n) => l10n.spiderStockDeals,
    runsCompleted: (l10n) => l10n.spiderRunsCompleted,
    cardsRevealed: (l10n) => l10n.spiderCardsRevealed,
    emptyColumnUses: (l10n) => l10n.spiderEmptyColumnUses,
    longestRunMoved: (l10n) => l10n.spiderLongestRunMoved,
    tapMoves: (l10n) => l10n.spiderTapMoves,
    dragMoves: (l10n) => l10n.spiderDragMoves,
    timeToFirstMoveMs: (l10n) => l10n.spiderTimeToFirstMove,
    longestThinkMs: (l10n) => l10n.spiderLongestThink,
  };
}

/// A run that the last action completed: the column it was on, its cards as
/// they lay there (the king first), and the face-down card under it that
/// turned face up when it left.
typedef CompletedRun = ({
  int column,
  List<PlayingCard> cards,
  String? revealedId,
});

/// Runs one Spider game at a time. It saves the game after each action, so
/// the player can continue it later, and records it when it ends.
class SpiderController extends ChangeNotifier {
  SpiderController({
    required this._stats,
    required this._saves,
    SpiderDifficulty difficulty = SpiderDifficulty.medium,
    int? seed,
    SpiderState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(difficulty: difficulty, seed: seed, initialState: initialState);
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable Spider save.
  SpiderController.restore(
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
      throw FormatException('Unreadable Spider save: $error');
    }
  }

  static const gameId = 'spider';

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;

  /// The boards before each action of [_actions], for undo.
  final _history = <SpiderState>[];

  /// The actions since the deal, to save the game: `[from, count, to]` for a
  /// move, `[]` for a stock deal.
  final _actions = <List<int>>[];
  final _counters = <String, int>{};

  late SpiderState _initial;
  late SpiderState _state;
  late int _seed;
  late DateTime _startedAt;
  late PlayTimer _timer;
  int _moves = 0;
  int _undos = 0;
  Duration? _timeToFirstMove;
  Duration _lastActionAt = Duration.zero;
  Duration _longestThink = Duration.zero;
  GameRecord? _result;
  bool _finished = false;
  List<String> _lastMovedCardIds = const [];
  List<CompletedRun> _lastCompletedRuns = const [];
  SpiderAction _lastAction = SpiderAction.none;
  int _actionSerial = 0;

  SpiderState get state => _state;
  int get seed => _seed;
  SpiderDifficulty get difficulty => _state.difficulty;

  /// See [SpiderScoring].
  int get score => SpiderScoring.score(
    moves: _moves,
    undos: _undos,
    runs: _state.runs.length,
  );
  int get moves => _moves;
  int get undos => _undos;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;
  bool get canDeal => !_finished && _state.canDeal;

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// Cards that changed place in the last action, in the order they moved:
  /// the moved cards from the bottom one, the dealt cards from the first
  /// column. The cards of [lastCompletedRuns] come after them.
  List<String> get lastMovedCardIds => _lastMovedCardIds;

  /// The runs that the last action completed, in the order they left.
  List<CompletedRun> get lastCompletedRuns => _lastCompletedRuns;

  /// The last action ([SpiderAction.none] for a game that continues).
  SpiderAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Moves the top [count] cards of column [from] onto column [to].
  bool move(
    int from,
    int count,
    int to, {
    SpiderInput input = SpiderInput.drag,
  }) {
    if (_finished) return false;
    final next = _state.move(from, count, to);
    if (next == null) return false;
    _bump(
      input == SpiderInput.tap
          ? SpiderStatKeys.tapMoves
          : SpiderStatKeys.dragMoves,
    );
    if (_state.columns[to].isEmpty) _bump(SpiderStatKeys.emptyColumnUses);
    _counters[SpiderStatKeys.longestRunMoved] = max(
      _counters[SpiderStatKeys.longestRunMoved] ?? 0,
      count,
    );
    final source = _state.columns[from];
    _commit(
      next,
      [from, count, to],
      SpiderAction.move,
      [for (final card in source.sublist(source.length - count)) card.id],
    );
    return true;
  }

  /// Moves the tapped cards to the best column, if one takes them.
  bool tap(int column, int count) {
    if (_finished) return false;
    final to = _state.autoTarget(column, count);
    return to != null && move(column, count, to, input: SpiderInput.tap);
  }

  /// Deals a card on each column from the stock.
  bool dealStock() {
    if (_finished) return false;
    final next = _state.deal();
    if (next == null) return false;
    _bump(SpiderStatKeys.stockDeals);
    final stock = _state.stock;
    _commit(next, const [], SpiderAction.stockDeal, [
      for (var i = 0; i < min(SpiderState.columnCount, stock.length); i++)
        stock[stock.length - 1 - i].id,
    ]);
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _actions.removeLast();
    _lastMovedCardIds = _movedCardIds(_state, previous);
    _lastCompletedRuns = const [];
    _lastAction = SpiderAction.undo;
    _actionSerial++;
    _state = previous;
    _undos++;
    _noteAction();
    save();
    notifyListeners();
  }

  /// Also saves the game: the app may never come back from a pause.
  void pause() {
    _timer.pause();
    save();
  }

  void resume() {
    if (!_finished) _timer.start();
  }

  /// Saves the game so the player can continue it later. A won game is not
  /// saved: it is in the statistics.
  void save() {
    if (_finished) return;
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

  /// Deals a new game and saves it. The current game counts as abandoned if
  /// the player made at least one move and did not win it.
  ///
  /// Without [seed], the deal is a winnable one of [difficulty] that the
  /// player has not played yet (see [pickSpiderSeed]), and never the current
  /// deal again. [difficulty] defaults to the one of the current game.
  void newGame({
    SpiderDifficulty? difficulty,
    int? seed,
    SpiderState? initialState,
  }) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? this.difficulty,
      seed: seed,
      current: _seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  /// The whole game, for [SpiderController.restore]: the board at the start
  /// and the actions since, which give back the undo history.
  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'difficulty': difficulty.name,
    'initial': _initial.encode(),
    'actions': [
      for (final action in _actions) [...action],
    ],
    'state': _state.encode(),
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'moves': _moves,
    'undos': _undos,
    'counters': {..._counters},
    'timeToFirstMoveMs': _timeToFirstMove?.inMilliseconds,
    'lastActionMs': _lastActionAt.inMilliseconds,
    'longestThinkMs': _longestThink.inMilliseconds,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown Spider save version ${json['version']}');
    }
    final difficulty = SpiderDifficulty.values.byName(
      json['difficulty'] as String,
    );
    Duration duration(Object? ms) => Duration(milliseconds: ms as int);

    _seed = json['seed'] as int;
    _initial = SpiderState.decode(json['initial'] as String, difficulty);
    _state = _initial;
    for (final action
        in (json['actions'] as List<Object?>).cast<List<Object?>>().map(
          (action) => action.cast<int>(),
        )) {
      final next = switch (action) {
        [] => _state.deal(),
        [final from, final count, final to] => _state.move(from, count, to),
        _ => null,
      };
      if (next == null) throw FormatException('Not a Spider action: $action');
      _history.add(_state);
      _actions.add(action);
      _state = next;
    }
    if (_state.encode() != json['state']) {
      throw const FormatException('The actions do not give the saved board');
    }
    _startedAt = DateTime.parse(json['startedAt'] as String);
    _timer = PlayTimer(clock: _clock, elapsed: duration(json['playTimeMs']))
      ..start();
    _moves = json['moves'] as int;
    _undos = json['undos'] as int;
    for (final MapEntry(:key, :value)
        in (json['counters'] as Map<String, Object?>).entries) {
      _counters[key] = value as int;
    }
    if (json['timeToFirstMoveMs'] case final ms?) {
      _timeToFirstMove = duration(ms);
    }
    _lastActionAt = duration(json['lastActionMs']);
    _longestThink = duration(json['longestThinkMs']);
  }

  void _start({
    required SpiderDifficulty difficulty,
    int? seed,
    int? current,
    SpiderState? initialState,
  }) {
    _seed = seed ?? _pickSeed(difficulty, current: current);
    _initial = initialState ?? SpiderState.deal(_seed, difficulty);
    _state = _initial;
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock)..start();
    _history.clear();
    _actions.clear();
    _counters.clear();
    _moves = 0;
    _undos = 0;
    _timeToFirstMove = null;
    _lastActionAt = Duration.zero;
    _longestThink = Duration.zero;
    _result = null;
    _finished = false;
    _lastMovedCardIds = const [];
    _lastCompletedRuns = const [];
    _lastAction = SpiderAction.deal;
    _actionSerial++;
  }

  /// A winnable seed of [difficulty] not in the records of that level (the
  /// abandoned game is already there) nor [current], the deal on screen.
  int _pickSeed(SpiderDifficulty difficulty, {int? current}) => pickSpiderSeed(
    difficulty: difficulty,
    played: {
      for (final record in _stats.recordsFor(
        gameId,
        variant: difficulty.variant,
      ))
        record.seed,
      ?current,
    },
    random: Random(),
  );

  void _commit(
    SpiderState next,
    List<int> action,
    SpiderAction kind,
    List<String> moved,
  ) {
    _history.add(_state);
    _actions.add(action);
    _lastCompletedRuns = _completedRuns(_state, next);
    _lastMovedCardIds = moved;
    _lastAction = kind;
    _actionSerial++;
    _state = next;
    _moves++;
    _noteAction();
    if (_state.isWon) {
      _finished = true;
      _timer.pause();
      final record = _record(GameOutcome.won);
      _result = record;
      unawaited(_stats.add(record));
      unawaited(_saves.remove(gameId));
    } else {
      save();
    }
    notifyListeners();
  }

  void _noteAction() {
    final now = _timer.elapsed;
    _timeToFirstMove ??= now;
    final think = now - _lastActionAt;
    if (think > _longestThink) _longestThink = think;
    _lastActionAt = now;
  }

  void _bump(String key) => _counters[key] = (_counters[key] ?? 0) + 1;

  GameRecord _record(GameOutcome outcome) => GameRecord(
    gameId: gameId,
    variant: difficulty.variant,
    seed: _seed,
    startedAt: _startedAt,
    endedAt: _clock(),
    playTime: _timer.elapsed,
    outcome: outcome,
    moves: _moves,
    undos: _undos,
    score: score,
    details: {
      ..._counters,
      // From the board, so undone runs and reveals do not count.
      SpiderStatKeys.runsCompleted: _state.runs.length,
      SpiderStatKeys.cardsRevealed:
          _initial.faceDownCount - _state.faceDownCount,
      if (_timeToFirstMove case final first?)
        SpiderStatKeys.timeToFirstMoveMs: first.inMilliseconds,
      SpiderStatKeys.longestThinkMs: _longestThink.inMilliseconds,
    },
  );

  /// The runs of [after] that [before] did not have, each with the column
  /// where its king was.
  static List<CompletedRun> _completedRuns(
    SpiderState before,
    SpiderState after,
  ) {
    if (after.runs.length == before.runs.length) return const [];
    final columnOf = {
      for (final (i, column) in before.columns.indexed)
        for (final card in column) card.id: i,
    };
    final faceDown = {
      for (final column in before.columns)
        for (final card in column)
          if (!card.faceUp) card.id,
    };
    return [
      for (final run in after.runs.skip(before.runs.length))
        if (columnOf[run.last.id] case final column?)
          (
            column: column,
            cards: run.reversed.toList(),
            revealedId: switch (after.columns[column].lastOrNull?.id) {
              final id? when faceDown.contains(id) => id,
              _ => null,
            },
          ),
    ];
  }

  static List<String> _movedCardIds(SpiderState before, SpiderState after) {
    final previous = _locations(before);
    return [
      for (final MapEntry(:key, :value) in _locations(after).entries)
        if (previous[key] != value) key,
    ];
  }

  /// Where each card is: `s` for the stock, `c<i>` for a column, `r<i>` for
  /// a run.
  static Map<String, String> _locations(SpiderState state) => {
    for (final card in state.stock) card.id: 's',
    for (final (i, column) in state.columns.indexed)
      for (final card in column) card.id: 'c$i',
    for (final (i, run) in state.runs.indexed)
      for (final card in run) card.id: 'r$i',
  };
}
