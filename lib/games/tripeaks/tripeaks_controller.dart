import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'tripeaks_deal_picker.dart';
import 'tripeaks_difficulty.dart';
import 'tripeaks_state.dart';

/// What changed the board last, so the board can animate it.
enum TriPeaksAction { none, deal, play, draw, undo }

/// Keys of the TriPeaks-specific counters in [GameRecord.details].
abstract final class TriPeaksStatKeys {
  static const cardsCleared = 'cardsCleared';
  static const longestRun = 'longestRun';
  static const peaksCleared = 'peaksCleared';
  static const draws = 'draws';
  static const stockLeft = 'stockLeft';
  static const timeToFirstMoveMs = 'timeToFirstMoveMs';
  static const longestThinkMs = 'longestThinkMs';

  static final labels = <String, String Function(AppLocalizations)>{
    cardsCleared: (l10n) => l10n.tripeaksCardsCleared,
    longestRun: (l10n) => l10n.tripeaksLongestRun,
    peaksCleared: (l10n) => l10n.tripeaksPeaksCleared,
    draws: (l10n) => l10n.tripeaksDraws,
    stockLeft: (l10n) => l10n.tripeaksStockLeft,
    timeToFirstMoveMs: (l10n) => l10n.tripeaksTimeToFirstMove,
    longestThinkMs: (l10n) => l10n.tripeaksLongestThink,
  };
}

/// Runs one TriPeaks game at a time. It saves the game after each action,
/// so the player can continue it later, and records it when it ends.
///
/// The last tableau card wins: the cards left in the stock then go onto the
/// waste one by one, each a bonus ([TriPeaksScoring.stockCardLeft]).
class TriPeaksController extends ChangeNotifier {
  TriPeaksController({
    required this._stats,
    required this._saves,
    TriPeaksDifficulty difficulty = TriPeaksDifficulty.medium,
    int? seed,
    TriPeaksState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(difficulty: difficulty, seed: seed, initialState: initialState);
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable TriPeaks save.
  TriPeaksController.restore(
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
      throw FormatException('Unreadable TriPeaks save: $error');
    }
  }

  static const gameId = 'tripeaks';

  /// The rules of the records: three peaks, 23 stock cards, no redeal.
  static const variant = 'classic';

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <({TriPeaksState state, int score, int run})>[];
  final _counters = <String, int>{};

  late TriPeaksState _state;
  late int _seed;
  TriPeaksDifficulty? _difficulty;
  late DateTime _startedAt;
  late PlayTimer _timer;
  int _score = 0;
  int _moves = 0;
  int _undos = 0;
  int _run = 0;
  int _stockLeftAtWin = 0;
  Duration? _timeToFirstMove;
  Duration _lastActionAt = Duration.zero;
  Duration _longestThink = Duration.zero;
  GameRecord? _result;
  bool _finished = false;
  List<String> _lastMovedCardIds = const [];
  int _lastBonusCount = 0;
  TriPeaksAction _lastAction = TriPeaksAction.none;
  int _actionSerial = 0;

  TriPeaksState get state => _state;
  int get seed => _seed;

  /// The list of `triPeaksDeals` that holds the deal, null for a seed in
  /// none of them (a link to any seed).
  TriPeaksDifficulty? get difficulty => _difficulty;
  int get score => _score;
  int get moves => _moves;
  int get undos => _undos;

  /// Tableau cards played since the last draw.
  int get run => _run;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;

  /// No card fits the waste and the stock is empty: only undo or a new game
  /// are left.
  bool get isStuck => !_finished && _state.isStuck;

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// Cards that changed pile in the last action, in the order they moved:
  /// the card played or drawn, then on a win the stock cards that go onto
  /// the waste.
  List<String> get lastMovedCardIds => _lastMovedCardIds;

  /// How many cards at the end of [lastMovedCardIds] are bonus cards of a
  /// win, from the stock.
  int get lastBonusCount => _lastBonusCount;

  /// The last action ([TriPeaksAction.none] for a game that continues).
  TriPeaksAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Plays the tableau card at [position] onto the waste. Returns false when
  /// it does not fit.
  bool play(int position) {
    if (_finished) return false;
    final next = _state.play(position);
    if (next == null) return false;
    final run = _run + 1;
    _counters[TriPeaksStatKeys.longestRun] = max(
      _counters[TriPeaksStatKeys.longestRun] ?? 0,
      run,
    );
    final peaks = next.peaksCleared - _state.peaksCleared;
    _commit(
      next,
      TriPeaksAction.play,
      _state.tableau[position]!.id,
      score: _score + TriPeaksScoring.card(run) + peaks * TriPeaksScoring.peak,
      run: run,
    );
    return true;
  }

  /// Turns the top stock card onto the waste. Returns false when the stock
  /// is empty.
  bool draw() {
    if (_finished) return false;
    final next = _state.draw();
    if (next == null) return false;
    _bump(TriPeaksStatKeys.draws);
    _commit(next, TriPeaksAction.draw, next.wasteTop.id, score: _score, run: 0);
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _lastMovedCardIds = _movedCardIds(_state, previous.state);
    _lastBonusCount = 0;
    _lastAction = TriPeaksAction.undo;
    _actionSerial++;
    _state = previous.state;
    _score = previous.score;
    _run = previous.run;
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
  /// player has not played yet (see [pickTriPeaksSeed]), and never the
  /// current deal again. [difficulty] defaults to the one of the current
  /// game (medium when it has none).
  void newGame({
    TriPeaksDifficulty? difficulty,
    int? seed,
    TriPeaksState? initialState,
  }) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? _difficulty ?? TriPeaksDifficulty.medium,
      seed: seed,
      current: _seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  /// The whole game, undo history included, for
  /// [TriPeaksController.restore].
  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'difficulty': _difficulty?.name,
    'state': _state.encode(),
    'history': [
      for (final entry in _history)
        [entry.score, entry.run, entry.state.encode()],
    ],
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'score': _score,
    'moves': _moves,
    'undos': _undos,
    'run': _run,
    'counters': {..._counters},
    'timeToFirstMoveMs': _timeToFirstMove?.inMilliseconds,
    'lastActionMs': _lastActionAt.inMilliseconds,
    'longestThinkMs': _longestThink.inMilliseconds,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown TriPeaks save version ${json['version']}');
    }
    TriPeaksState decode(Object? text) => TriPeaksState.decode(text as String);
    Duration duration(Object? ms) => Duration(milliseconds: ms as int);

    _seed = json['seed'] as int;
    _difficulty =
        TriPeaksDifficulty.values.asNameMap()[json['difficulty']] ??
        triPeaksDifficultyOfSeed(_seed);
    _state = decode(json['state']);
    if (_state.isWon) throw const FormatException('A won game is not saved');
    _history.addAll([
      for (final entry
          in (json['history'] as List<Object?>).cast<List<Object?>>())
        (score: entry[0] as int, run: entry[1] as int, state: decode(entry[2])),
    ]);
    _startedAt = DateTime.parse(json['startedAt'] as String);
    _timer = PlayTimer(clock: _clock, elapsed: duration(json['playTimeMs']))
      ..start();
    _score = json['score'] as int;
    _moves = json['moves'] as int;
    _undos = json['undos'] as int;
    _run = json['run'] as int;
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
    required TriPeaksDifficulty difficulty,
    int? seed,
    int? current,
    TriPeaksState? initialState,
  }) {
    _seed = seed ?? _pickSeed(difficulty, current: current);
    _difficulty = triPeaksDifficultyOfSeed(_seed);
    _state = initialState ?? TriPeaksState.deal(_seed);
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock)..start();
    _history.clear();
    _counters.clear();
    _score = 0;
    _moves = 0;
    _undos = 0;
    _run = 0;
    _stockLeftAtWin = 0;
    _timeToFirstMove = null;
    _lastActionAt = Duration.zero;
    _longestThink = Duration.zero;
    _result = null;
    _finished = false;
    _lastMovedCardIds = const [];
    _lastBonusCount = 0;
    _lastAction = TriPeaksAction.deal;
    _actionSerial++;
  }

  /// A winnable seed of [difficulty] not in the records (the abandoned game
  /// is already there) nor [current], the deal on screen.
  int _pickSeed(TriPeaksDifficulty difficulty, {int? current}) =>
      pickTriPeaksSeed(
        difficulty: difficulty,
        played: {
          for (final record in _stats.recordsFor(gameId)) record.seed,
          ?current,
        },
        random: Random(),
      );

  void _commit(
    TriPeaksState next,
    TriPeaksAction action,
    String movedId, {
    required int score,
    required int run,
  }) {
    _history.add((state: _state, score: _score, run: _run));
    _lastMovedCardIds = [movedId];
    _lastBonusCount = 0;
    _lastAction = action;
    _actionSerial++;
    _state = next;
    _score = score;
    _run = run;
    _moves++;
    _noteAction();
    if (_state.isWon) {
      _finished = true;
      _stockLeftAtWin = _state.stock.length;
      _lastMovedCardIds = [
        movedId,
        for (final card in _state.stock.reversed) card.id,
      ];
      _lastBonusCount = _stockLeftAtWin;
      _state = _state.collectStock();
      _score += _stockLeftAtWin * TriPeaksScoring.stockCardLeft;
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
    variant: variant,
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
      TriPeaksStatKeys.cardsCleared: TriPeaksState.positions - _state.cardsLeft,
      TriPeaksStatKeys.peaksCleared: _state.peaksCleared,
      TriPeaksStatKeys.stockLeft: _finished
          ? _stockLeftAtWin
          : _state.stock.length,
      if (_timeToFirstMove case final first?)
        TriPeaksStatKeys.timeToFirstMoveMs: first.inMilliseconds,
      TriPeaksStatKeys.longestThinkMs: _longestThink.inMilliseconds,
    },
  );

  static List<String> _movedCardIds(TriPeaksState before, TriPeaksState after) {
    final previous = _locations(before);
    return [
      for (final MapEntry(:key, :value) in _locations(after).entries)
        if (previous[key] != value) key,
    ];
  }

  /// Where each card is: its tableau place, or -1 for the stock and -2 for
  /// the waste.
  static Map<String, int> _locations(TriPeaksState state) => {
    for (final (i, card) in state.tableau.indexed) ?card?.id: i,
    for (final card in state.stock) card.id: -1,
    for (final card in state.waste) card.id: -2,
  };
}
