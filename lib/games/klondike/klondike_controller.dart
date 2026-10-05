import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

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

/// Runs one Klondike game at a time and records its statistics.
class KlondikeController extends ChangeNotifier {
  KlondikeController({
    required this._stats,
    int drawCount = 1,
    int? seed,
    KlondikeState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(drawCount: drawCount, seed: seed, initialState: initialState);
  }

  static const gameId = 'klondike';

  final StatsStore _stats;
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
    _saveProgress();
    notifyListeners();
  }

  void pause() => _timer.pause();

  void resume() {
    if (!_finished) _timer.start();
  }

  /// Records the game as abandoned if the player made at least one move.
  void abandon() {
    if (_finished) return;
    _finished = true;
    _timer.pause();
    if (_moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
  }

  void newGame({int? drawCount, int? seed}) {
    abandon();
    _start(drawCount: drawCount ?? _state.drawCount, seed: seed);
    notifyListeners();
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
    } else {
      _saveProgress();
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

  void _saveProgress() =>
      unawaited(_stats.saveInProgress(_record(GameOutcome.abandoned)));

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
