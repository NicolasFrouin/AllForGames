import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'deal_picker.dart';
import 'klondike_auto_win.dart';
import 'klondike_difficulty.dart';
// Its KlondikeAction is one step of a solution.
import 'klondike_solver.dart' as solver;
import 'klondike_state.dart';

enum MoveInput { tap, drag }

/// What changed the board last, so the board can animate it.
enum KlondikeAction { none, deal, draw, recycle, move, autoComplete, undo }

/// Where the auto-win is: off, looking for a win, or playing it.
enum AutoWinPhase { off, searching, playing }

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

  static final labels = <String, String Function(AppLocalizations)>{
    stockDraws: (l10n) => l10n.klondikeStockDraws,
    stockRecycles: (l10n) => l10n.klondikeStockRecycles,
    cardsToFoundation: (l10n) => l10n.klondikeCardsToFoundation,
    cardsRevealed: (l10n) => l10n.klondikeCardsRevealed,
    tapMoves: (l10n) => l10n.klondikeTapMoves,
    dragMoves: (l10n) => l10n.klondikeDragMoves,
    foundationToTableau: (l10n) => l10n.klondikeFoundationToTableau,
    autoCompleted: (l10n) => l10n.klondikeAutoCompleted,
    timeToFirstMoveMs: (l10n) => l10n.klondikeTimeToFirstMove,
    longestThinkMs: (l10n) => l10n.klondikeLongestThink,
  };
}

/// Runs one Klondike game at a time. It saves the game after each action, so
/// the player can continue it later, and records it when it ends.
class KlondikeController extends ChangeNotifier {
  KlondikeController({
    required this._stats,
    required this._saves,
    int drawCount = 1,
    KlondikeDifficulty difficulty = KlondikeDifficulty.medium,
    int? seed,
    KlondikeState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(
      drawCount: drawCount,
      difficulty: difficulty,
      seed: seed,
      initialState: initialState,
    );
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

  /// Time before each action of the auto-win: a draw, a move, a move taken
  /// back. Quick, but slow enough to follow.
  static const autoDrawPace = Duration(milliseconds: 100);
  static const autoMovePace = Duration(milliseconds: 300);
  static const autoUndoPace = Duration(milliseconds: 150);

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <({KlondikeState state, int score})>[];
  final _counters = <String, int>{};

  late KlondikeState _state;
  late int _seed;
  KlondikeDifficulty? _difficulty;
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
  bool _canceled = false;
  _AutoWinRun? _autoWin;
  Set<String> _lastMovedCardIds = const {};
  KlondikeAction _lastAction = KlondikeAction.none;
  int _actionSerial = 0;

  KlondikeState get state => _state;
  int get seed => _seed;

  /// The list of `klondikeDeals` that holds the deal, null for a seed in
  /// none of them (a link to any seed).
  KlondikeDifficulty? get difficulty => _difficulty;
  int get score => _score;
  int get moves => _moves;
  int get undos => _undos;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _autoWin == null && _history.isNotEmpty;
  bool get canAutoComplete =>
      !_finished && _autoWin == null && _state.canAutoComplete;

  /// The game was played for the player ([startAutoWin]): it leaves no
  /// record and no save.
  bool get canceled => _canceled;

  /// A new game over this one can record it as abandoned.
  bool get canAbandon => !_finished && !_canceled && _moves > 0;

  AutoWinPhase get autoWinPhase => switch (_autoWin) {
    null => AutoWinPhase.off,
    _AutoWinRun(playing: false) => AutoWinPhase.searching,
    _ => AutoWinPhase.playing,
  };

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// Cards that changed pile in the last action, in the order they moved
  /// (bottom card first; the foundation order for an auto-complete).
  Set<String> get lastMovedCardIds => _lastMovedCardIds;

  /// The last action ([KlondikeAction.none] for a game that continues).
  KlondikeAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  bool draw() => _autoWin == null && _draw();

  bool _draw() {
    if (_finished) return false;
    final result = _state.draw();
    if (result == null) return false;
    _bump(
      result.recycled
          ? KlondikeStatKeys.stockRecycles
          : KlondikeStatKeys.stockDraws,
    );
    _commit(
      result.state,
      result.scoreDelta,
      result.recycled ? KlondikeAction.recycle : KlondikeAction.draw,
    );
    return true;
  }

  bool move(
    PileRef from,
    int count,
    PileRef to, {
    MoveInput input = MoveInput.drag,
  }) => _autoWin == null && _move(from, count, to, input);

  bool _move(PileRef from, int count, PileRef to, MoveInput input) {
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
    _commit(result.state, result.scoreDelta, KlondikeAction.move);
    return true;
  }

  /// Moves the tapped cards to the best legal pile, if there is one.
  bool tap(PileRef from, int count) {
    if (_finished || _autoWin != null) return false;
    final to = _state.autoTarget(from, count);
    return to != null && move(from, count, to, input: MoveInput.tap);
  }

  /// Sends all remaining cards to the foundations. Counts as one move.
  void autoComplete() {
    if (canAutoComplete) _autoComplete();
  }

  void _autoComplete() {
    var next = _state;
    var scoreDelta = 0;
    final order = <String>{};
    for (
      var step = next.nextFoundationMove();
      step != null;
      step = next.nextFoundationMove()
    ) {
      order.add(next.pile(step.from).last.id);
      final result = next.move(step.from, 1, step.to)!;
      next = result.state;
      scoreDelta += result.scoreDelta;
    }
    _bump(KlondikeStatKeys.autoCompleted);
    _commit(next, scoreDelta, KlondikeAction.autoComplete, moved: order);
  }

  void undo() {
    if (canUndo) _undo();
  }

  void _undo() {
    final previous = _history.removeLast();
    _lastMovedCardIds = _movedCardIds(_state, previous.state);
    _lastAction = KlondikeAction.undo;
    _actionSerial++;
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
    if (!_finished && !_canceled) _timer.start();
  }

  /// Finds a win and plays it, one action every [autoMovePace] or so (first
  /// taking back the moves that lost the game, if any). From then on, the
  /// game is canceled: no record, no save. Returns whether a win was found;
  /// without one, or when [stopAutoWin] came first, the game goes on as it
  /// was.
  Future<bool> startAutoWin() async {
    if (_finished || _autoWin != null) return false;
    final run = _autoWin = _AutoWinRun();
    notifyListeners();
    final plan = await planAutoWin([
      for (final entry in _history) entry.state,
      _state,
    ]);
    // Stopped, a new deal, or the screen closed in the meantime.
    if (!identical(run, _autoWin)) return plan != null;
    if (plan == null) {
      _autoWin = null;
      notifyListeners();
      return false;
    }
    _canceled = true;
    _timer.pause();
    unawaited(_saves.remove(gameId));
    run.playing = true;
    notifyListeners();
    _playAutoWin(
      run,
      [
        for (var i = 0; i < plan.undos; i++) (autoUndoPace, _undo),
        for (final action in plan.actions)
          switch (action) {
            solver.DrawAction() => (autoDrawPace, () => _draw()),
            solver.MoveAction(:final from, :final count, :final to) => (
              autoMovePace,
              () => _move(from, count, to, MoveInput.tap),
            ),
          },
      ].iterator,
    );
    return true;
  }

  /// Plays the next of [steps] after its pace, until the game is won. Once
  /// only foundation moves are left, they go as one auto-complete.
  void _playAutoWin(
    _AutoWinRun run,
    Iterator<(Duration, void Function())> steps,
  ) {
    final next = _state.canAutoComplete
        ? (autoMovePace, _autoComplete)
        : steps.moveNext()
        ? steps.current
        : null;
    if (next == null) return stopAutoWin();
    final (pace, play) = next;
    run.timer = Timer(pace, () {
      play();
      _finished ? stopAutoWin() : _playAutoWin(run, steps);
    });
  }

  /// Stops the auto-win: the player goes on by hand (a canceled game stays
  /// canceled).
  void stopAutoWin() {
    if (_autoWin == null) return;
    _autoWin!.timer?.cancel();
    _autoWin = null;
    notifyListeners();
  }

  /// Saves the game so the player can continue it later. A won game is not
  /// saved: it is in the statistics.
  void save() {
    if (_finished || _canceled) return;
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
  /// as abandoned if the player made at least one move and did not win it;
  /// else it leaves no record.
  ///
  /// Without [seed], the deal is a winnable one of [difficulty] that the
  /// player has not played yet (see [pickDealSeed]), and never the current
  /// deal again. [drawCount] and [difficulty] default to those of the current
  /// game (medium when it has none).
  void newGame({
    int? drawCount,
    KlondikeDifficulty? difficulty,
    int? seed,
    KlondikeState? initialState,
    bool abandon = false,
  }) {
    if (abandon && canAbandon) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      drawCount: drawCount ?? _state.drawCount,
      difficulty: difficulty ?? _difficulty ?? KlondikeDifficulty.medium,
      seed: seed,
      current: _seed,
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
    'difficulty': _difficulty?.name,
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
    // Saves before difficulty levels have none: the lists tell it.
    _difficulty =
        KlondikeDifficulty.values.asNameMap()[json['difficulty']] ??
        difficultyOfSeed(drawCount, _seed);
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
    required KlondikeDifficulty difficulty,
    int? seed,
    int? current,
    KlondikeState? initialState,
  }) {
    _seed = seed ?? _pickSeed(drawCount, difficulty, current: current);
    _difficulty = difficultyOfSeed(drawCount, _seed);
    _state = initialState ?? KlondikeState.deal(_seed, drawCount: drawCount);
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
    _canceled = false;
    _autoWin?.timer?.cancel();
    _autoWin = null;
    _lastMovedCardIds = const {};
    _lastAction = KlondikeAction.deal;
    _actionSerial++;
  }

  /// A winnable seed of [difficulty] not in the records of [drawCount] games
  /// (an abandoned game is already there) nor [current], the deal on screen.
  int _pickSeed(int drawCount, KlondikeDifficulty difficulty, {int? current}) =>
      pickDealSeed(
        drawCount: drawCount,
        difficulty: difficulty,
        played: {
          for (final record in _stats.recordsFor(
            gameId,
            variant: _variant(drawCount),
          ))
            record.seed,
          ?current,
        },
        random: Random(),
      );

  static String _variant(int drawCount) => 'draw$drawCount';

  void _commit(
    KlondikeState next,
    int scoreDelta,
    KlondikeAction action, {
    Set<String>? moved,
  }) {
    _history.add((state: _state, score: _score));
    _lastMovedCardIds = moved ?? _movedCardIds(_state, next);
    _lastAction = action;
    _actionSerial++;
    _state = next;
    _score = max(0, _score + scoreDelta);
    _moves++;
    _noteAction();
    if (_state.isWon) {
      _finished = true;
      _timer.pause();
      if (!_canceled) {
        final record = _record(GameOutcome.won);
        _result = record;
        unawaited(_stats.add(record));
      }
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

  @override
  void dispose() {
    _autoWin?.timer?.cancel();
    _autoWin = null;
    super.dispose();
  }

  GameRecord _record(GameOutcome outcome) => GameRecord(
    gameId: gameId,
    variant: _variant(_state.drawCount),
    seed: _seed,
    startedAt: _startedAt,
    endedAt: _clock(),
    playTime: _timer.elapsed,
    outcome: outcome,
    moves: _moves,
    undos: _undos,
    score: _score,
    difficulty: _difficulty?.name,
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

/// One auto-win: it looks for a win, then plays it ([playing]), one action
/// per [timer].
class _AutoWinRun {
  bool playing = false;
  Timer? timer;
}
