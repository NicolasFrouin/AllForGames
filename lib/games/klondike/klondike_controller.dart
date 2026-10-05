import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'klondike_state.dart';

enum MoveInput { tap, drag }

/// Keys of the Klondike-specific counters in [GameRecord.details].
abstract final class KlondikeStatKeys {
  static const stockDraws = 'stockDraws';
  static const stockRecycles = 'stockRecycles';
  static const cardsToFoundation = 'cardsToFoundation';
  static const cardsRevealed = 'cardsRevealed';
  static const tapMoves = 'tapMoves';
  static const dragMoves = 'dragMoves';
  static const foundationToTableau = 'foundationToTableau';
  static const autoCompleted = 'autoCompleted';
  static const timeToFirstMoveMs = 'timeToFirstMoveMs';
  static const longestThinkMs = 'longestThinkMs';

  static const labels = {
    stockDraws: 'Stock draws',
    stockRecycles: 'Stock recycles',
    cardsToFoundation: 'Cards on foundations',
    cardsRevealed: 'Cards revealed',
    tapMoves: 'Tap moves',
    dragMoves: 'Drag moves',
    foundationToTableau: 'Foundation take-backs',
    autoCompleted: 'Auto-finished',
    timeToFirstMoveMs: 'Time to first move',
    longestThinkMs: 'Longest think time',
  };
}

/// Runs one Klondike game at a time. It saves the game after each action, so
/// the player can continue it later, and records it when it ends.
class KlondikeController extends ChangeNotifier {
  KlondikeController({
    required this._stats,
    required this._saves,
    int drawCount = 1,
    int? seed,
    KlondikeState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(drawCount: drawCount, seed: seed, initialState: initialState);
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable Klondike save.
  KlondikeController.restore(
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
      throw FormatException('Unreadable Klondike save: $error');
    }
  }

  static const gameId = 'klondike';

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <({KlondikeState state, int score})>[];
  final _counters = <String, int>{};

  late KlondikeState _state;
  late int _seed;
  late DateTime _startedAt;
  late PlayTimer _timer;
  late int _initialFaceDown;
  int _score = 0;
  int _moves = 0;
  int _undos = 0;
  Duration? _timeToFirstMove;
  Duration _lastActionAt = Duration.zero;
  Duration _longestThink = Duration.zero;
  GameRecord? _result;
  bool _finished = false;
  Set<String> _lastMovedCardIds = const {};

  KlondikeState get state => _state;
  int get seed => _seed;
  int get score => _score;
  int get moves => _moves;
  int get undos => _undos;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;
  bool get canAutoComplete => !_finished && _state.canAutoComplete;

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// Cards that changed pile in the last action, so the board can draw them on top.
  Set<String> get lastMovedCardIds => _lastMovedCardIds;

  bool draw() {
    if (_finished) return false;
    final result = _state.draw();
    if (result == null) return false;
    _bump(
      result.recycled
          ? KlondikeStatKeys.stockRecycles
          : KlondikeStatKeys.stockDraws,
    );
    _commit(result.state, result.scoreDelta);
    return true;
  }

  bool move(
    PileRef from,
    int count,
    PileRef to, {
    MoveInput input = MoveInput.drag,
  }) {
    if (_finished) return false;
    final result = _state.move(from, count, to);
    if (result == null) return false;
    _bump(
      input == MoveInput.tap
          ? KlondikeStatKeys.tapMoves
          : KlondikeStatKeys.dragMoves,
    );
    if (from.type == PileType.foundation) {
      _bump(KlondikeStatKeys.foundationToTableau);
    }
    _commit(result.state, result.scoreDelta);
    return true;
  }

  /// Moves the tapped cards to the best legal pile, if there is one.
  bool tap(PileRef from, int count) {
    if (_finished) return false;
    final to = _state.autoTarget(from, count);
    return to != null && move(from, count, to, input: MoveInput.tap);
  }

  /// Sends all remaining cards to the foundations. Counts as one move.
  void autoComplete() {
    if (!canAutoComplete) return;
    var next = _state;
    var scoreDelta = 0;
    for (
      var step = next.nextFoundationMove();
      step != null;
      step = next.nextFoundationMove()
    ) {
      final result = next.move(step.from, 1, step.to)!;
      next = result.state;
      scoreDelta += result.scoreDelta;
    }
    _bump(KlondikeStatKeys.autoCompleted);
    _commit(next, scoreDelta);
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _lastMovedCardIds = _movedCardIds(_state, previous.state);
    _state = previous.state;
    _score = previous.score;
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
  void newGame({int? drawCount, int? seed, KlondikeState? initialState}) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      drawCount: drawCount ?? _state.drawCount,
      seed: seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  /// The whole game, undo history included, for [KlondikeController.restore].
  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'drawCount': _state.drawCount,
    'state': _state.encode(),
    'history': [
      for (final entry in _history) [entry.score, entry.state.encode()],
    ],
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'score': _score,
    'moves': _moves,
    'undos': _undos,
    'counters': {..._counters},
    'initialFaceDown': _initialFaceDown,
    'timeToFirstMoveMs': _timeToFirstMove?.inMilliseconds,
    'lastActionMs': _lastActionAt.inMilliseconds,
    'longestThinkMs': _longestThink.inMilliseconds,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown Klondike save version ${json['version']}');
    }
    final drawCount = json['drawCount'] as int;
    KlondikeState decode(Object? text) =>
        KlondikeState.decode(text as String, drawCount: drawCount);
    Duration duration(Object? ms) => Duration(milliseconds: ms as int);

    _seed = json['seed'] as int;
    _state = decode(json['state']);
    _history.addAll([
      for (final entry
          in (json['history'] as List<Object?>).cast<List<Object?>>())
        (state: decode(entry[1]), score: entry[0] as int),
    ]);
    _startedAt = DateTime.parse(json['startedAt'] as String);
    _timer = PlayTimer(clock: _clock, elapsed: duration(json['playTimeMs']))
      ..start();
    _score = json['score'] as int;
    _moves = json['moves'] as int;
    _undos = json['undos'] as int;
    for (final MapEntry(:key, :value)
        in (json['counters'] as Map<String, Object?>).entries) {
      _counters[key] = value as int;
    }
    _initialFaceDown = json['initialFaceDown'] as int;
    if (json['timeToFirstMoveMs'] case final ms?) {
      _timeToFirstMove = duration(ms);
    }
    _lastActionAt = duration(json['lastActionMs']);
    _longestThink = duration(json['longestThinkMs']);
  }

  void _start({
    required int drawCount,
    int? seed,
    KlondikeState? initialState,
  }) {
    _seed = seed ?? Random().nextInt(1 << 31);
    _state =
        initialState ?? KlondikeState.deal(Random(_seed), drawCount: drawCount);
    _initialFaceDown = _state.faceDownCount;
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock)..start();
    _history.clear();
    _counters.clear();
    _score = 0;
    _moves = 0;
    _undos = 0;
    _timeToFirstMove = null;
    _lastActionAt = Duration.zero;
    _longestThink = Duration.zero;
    _result = null;
    _finished = false;
    _lastMovedCardIds = const {};
  }

  void _commit(KlondikeState next, int scoreDelta) {
    _history.add((state: _state, score: _score));
    _lastMovedCardIds = _movedCardIds(_state, next);
    _state = next;
    _score = max(0, _score + scoreDelta);
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
    variant: 'draw${_state.drawCount}',
    seed: _seed,
    startedAt: _startedAt,
    endedAt: _clock(),
    playTime: _timer.elapsed,
    outcome: outcome,
    moves: _moves,
    undos: _undos,
    score: _score,
    details: {
      ..._counters,
      KlondikeStatKeys.cardsToFoundation: _state.foundationCardCount,
      // From the board, so undone reveals do not count.
      KlondikeStatKeys.cardsRevealed: _initialFaceDown - _state.faceDownCount,
      if (_timeToFirstMove case final first?)
        KlondikeStatKeys.timeToFirstMoveMs: first.inMilliseconds,
      KlondikeStatKeys.longestThinkMs: _longestThink.inMilliseconds,
    },
  );

  static Set<String> _movedCardIds(KlondikeState before, KlondikeState after) {
    final previous = _locations(before);
    return {
      for (final MapEntry(:key, :value) in _locations(after).entries)
        if (previous[key] != value) key,
    };
  }

  static Map<String, PileRef> _locations(KlondikeState state) => {
    for (final ref in [
      PileRef.stock,
      PileRef.waste,
      for (var i = 0; i < 4; i++) PileRef.foundation(i),
      for (var i = 0; i < 7; i++) PileRef.tableau(i),
    ])
      for (final card in state.pile(ref)) card.id: ref,
  };
}
