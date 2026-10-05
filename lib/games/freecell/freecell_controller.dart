import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'freecell_deal_picker.dart';
import 'freecell_difficulty.dart';
import 'freecell_state.dart';

enum FreeCellInput { tap, drag }

/// What changed the board last, so the board can animate it.
enum FreeCellAction { none, deal, move, finish, undo }

/// Keys of the FreeCell-specific counters in [GameRecord.details].
abstract final class FreeCellStatKeys {
  static const cardsToFoundation = 'cardsToFoundation';
  static const autoMoves = 'autoMoves';
  static const freeCellUses = 'freeCellUses';
  static const mostFreeCellsUsed = 'mostFreeCellsUsed';
  static const supermoves = 'supermoves';
  static const emptyColumnUses = 'emptyColumnUses';
  static const tapMoves = 'tapMoves';
  static const dragMoves = 'dragMoves';
  static const autoFinished = 'autoFinished';
  static const timeToFirstMoveMs = 'timeToFirstMoveMs';
  static const longestThinkMs = 'longestThinkMs';

  static final labels = <String, String Function(AppLocalizations)>{
    cardsToFoundation: (l10n) => l10n.freecellCardsToFoundation,
    autoMoves: (l10n) => l10n.freecellAutoMoves,
    freeCellUses: (l10n) => l10n.freecellFreeCellUses,
    mostFreeCellsUsed: (l10n) => l10n.freecellMostFreeCellsUsed,
    supermoves: (l10n) => l10n.freecellSupermoves,
    emptyColumnUses: (l10n) => l10n.freecellEmptyColumnUses,
    tapMoves: (l10n) => l10n.freecellTapMoves,
    dragMoves: (l10n) => l10n.freecellDragMoves,
    autoFinished: (l10n) => l10n.freecellAutoFinished,
    timeToFirstMoveMs: (l10n) => l10n.freecellTimeToFirstMove,
    longestThinkMs: (l10n) => l10n.freecellLongestThink,
  };
}

/// Runs one FreeCell game at a time. It saves the game after each action,
/// so the player can continue it later, and records it when it ends.
///
/// After each move, the cards that can safely go to the foundations go
/// there by themselves ([FreeCellState.nextSafeMove]): the move and these
/// automatic moves are one action, undone together.
class FreeCellController extends ChangeNotifier {
  FreeCellController({
    required this._stats,
    required this._saves,
    FreeCellDifficulty difficulty = FreeCellDifficulty.medium,
    int? seed,
    FreeCellState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(difficulty: difficulty, seed: seed, initialState: initialState);
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable FreeCell save.
  FreeCellController.restore(
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
      throw FormatException('Unreadable FreeCell save: $error');
    }
  }

  static const gameId = 'freecell';

  /// The rules of the records: 4 free cells, 8 cascades.
  static const variant = 'classic';

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <({FreeCellState state, int score})>[];
  final _counters = <String, int>{};

  late FreeCellState _state;
  late int _seed;
  FreeCellDifficulty? _difficulty;
  late DateTime _startedAt;
  late PlayTimer _timer;
  int _score = 0;
  int _moves = 0;
  int _undos = 0;
  Duration? _timeToFirstMove;
  Duration _lastActionAt = Duration.zero;
  Duration _longestThink = Duration.zero;
  GameRecord? _result;
  bool _finished = false;
  List<String> _lastMovedCardIds = const [];
  int _lastAutoMoveCount = 0;
  FreeCellState? _lastLanding;
  FreeCellAction _lastAction = FreeCellAction.none;
  int _actionSerial = 0;

  FreeCellState get state => _state;
  int get seed => _seed;

  /// The list of `freecellDeals` that holds the deal, null for a seed in
  /// none of them (a link to any seed).
  FreeCellDifficulty? get difficulty => _difficulty;
  int get score => _score;
  int get moves => _moves;
  int get undos => _undos;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;
  bool get canFinish => !_finished && _state.canFinish;

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// Cards that changed pile in the last action, in the order they moved:
  /// the cards the player moved (bottom card first), then the automatic
  /// moves to the foundations; the foundation order for a finish.
  List<String> get lastMovedCardIds => _lastMovedCardIds;

  /// How many cards at the end of [lastMovedCardIds] went to the
  /// foundations by themselves.
  int get lastAutoMoveCount => _lastAutoMoveCount;

  /// The board between the two steps of the last action: after the player's
  /// move, before the automatic moves. Null when the last action had none.
  FreeCellState? get lastLanding => _lastLanding;

  /// The last action ([FreeCellAction.none] for a game that continues).
  FreeCellAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Moves the top [count] cards of [from] to [to], then plays the safe
  /// moves to the foundations. Returns false when the move is not legal.
  bool move(
    FreeCellPile from,
    int count,
    FreeCellPile to, {
    FreeCellInput input = FreeCellInput.drag,
  }) {
    if (_finished) return false;
    final moved = _state.move(from, count, to);
    if (moved == null) return false;
    _bump(
      input == FreeCellInput.tap
          ? FreeCellStatKeys.tapMoves
          : FreeCellStatKeys.dragMoves,
    );
    if (count > 1) _bump(FreeCellStatKeys.supermoves);
    if (to.type == FreeCellPileType.cell) {
      _bump(FreeCellStatKeys.freeCellUses);
    }
    if (to.type == FreeCellPileType.cascade &&
        _state.cascades[to.index].isEmpty) {
      _bump(FreeCellStatKeys.emptyColumnUses);
    }
    _counters[FreeCellStatKeys.mostFreeCellsUsed] = max(
      _counters[FreeCellStatKeys.mostFreeCellsUsed] ?? 0,
      moved.usedCellCount,
    );
    final source = _state.pile(from);
    final order = [
      for (final card in source.skip(source.length - count)) card.id,
    ];
    var next = moved;
    var automatic = 0;
    for (
      var step = next.nextSafeMove();
      step != null;
      step = next.nextSafeMove()
    ) {
      order.add(next.pile(step.from).last.id);
      next = next.move(step.from, 1, step.to)!;
      automatic++;
    }
    if (automatic > 0) {
      _counters[FreeCellStatKeys.autoMoves] =
          (_counters[FreeCellStatKeys.autoMoves] ?? 0) + automatic;
    }
    _commit(
      next,
      FreeCellAction.move,
      order,
      automatic: automatic,
      landing: automatic > 0 ? moved : null,
    );
    return true;
  }

  /// Moves the tapped cards where [FreeCellState.tapTarget] sends them, if
  /// they can move.
  bool tap(FreeCellPile from, int count) {
    if (_finished) return false;
    final to = _state.tapTarget(from, count);
    return to != null && move(from, count, to, input: FreeCellInput.tap);
  }

  /// Sends all remaining cards to the foundations. Counts as one move.
  void finish() {
    if (!canFinish) return;
    var next = _state;
    final order = <String>[];
    for (
      var step = next.nextFinishMove();
      step != null;
      step = next.nextFinishMove()
    ) {
      order.add(next.pile(step.from).last.id);
      next = next.move(step.from, 1, step.to)!;
    }
    _bump(FreeCellStatKeys.autoFinished);
    _commit(next, FreeCellAction.finish, order);
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _lastMovedCardIds = _movedCardIds(_state, previous.state);
    _lastAutoMoveCount = 0;
    _lastLanding = null;
    _lastAction = FreeCellAction.undo;
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
  /// player has not played yet (see [pickFreeCellSeed]), and never the
  /// current deal again. [difficulty] defaults to the one of the current
  /// game (medium when it has none).
  void newGame({
    FreeCellDifficulty? difficulty,
    int? seed,
    FreeCellState? initialState,
  }) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? _difficulty ?? FreeCellDifficulty.medium,
      seed: seed,
      current: _seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  /// The whole game, undo history included, for
  /// [FreeCellController.restore].
  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
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
    'timeToFirstMoveMs': _timeToFirstMove?.inMilliseconds,
    'lastActionMs': _lastActionAt.inMilliseconds,
    'longestThinkMs': _longestThink.inMilliseconds,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown FreeCell save version ${json['version']}');
    }
    FreeCellState decode(Object? text) => FreeCellState.decode(text as String);
    Duration duration(Object? ms) => Duration(milliseconds: ms as int);

    _seed = json['seed'] as int;
    _difficulty =
        FreeCellDifficulty.values.asNameMap()[json['difficulty']] ??
        freeCellDifficultyOfSeed(_seed);
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
    if (json['timeToFirstMoveMs'] case final ms?) {
      _timeToFirstMove = duration(ms);
    }
    _lastActionAt = duration(json['lastActionMs']);
    _longestThink = duration(json['longestThinkMs']);
  }

  void _start({
    required FreeCellDifficulty difficulty,
    int? seed,
    int? current,
    FreeCellState? initialState,
  }) {
    _seed = seed ?? _pickSeed(difficulty, current: current);
    _difficulty = freeCellDifficultyOfSeed(_seed);
    _state = initialState ?? FreeCellState.deal(_seed);
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
    _lastMovedCardIds = const [];
    _lastAutoMoveCount = 0;
    _lastLanding = null;
    _lastAction = FreeCellAction.deal;
    _actionSerial++;
  }

  /// A winnable seed of [difficulty] not in the records (the abandoned game
  /// is already there) nor [current], the deal on screen.
  int _pickSeed(FreeCellDifficulty difficulty, {int? current}) =>
      pickFreeCellSeed(
        difficulty: difficulty,
        played: {
          for (final record in _stats.recordsFor(gameId)) record.seed,
          ?current,
        },
        random: Random(),
      );

  void _commit(
    FreeCellState next,
    FreeCellAction action,
    List<String> moved, {
    int automatic = 0,
    FreeCellState? landing,
  }) {
    _history.add((state: _state, score: _score));
    _lastMovedCardIds = moved;
    _lastAutoMoveCount = automatic;
    _lastLanding = landing;
    _lastAction = action;
    _actionSerial++;
    _score +=
        (next.foundationCardCount - _state.foundationCardCount) *
        FreeCellScoring.toFoundation;
    _state = next;
    _moves++;
    _noteAction();
    if (_state.isWon) {
      _finished = true;
      _score += FreeCellScoring.winBonus(_moves);
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
      FreeCellStatKeys.cardsToFoundation: _state.foundationCardCount,
      if (_timeToFirstMove case final first?)
        FreeCellStatKeys.timeToFirstMoveMs: first.inMilliseconds,
      FreeCellStatKeys.longestThinkMs: _longestThink.inMilliseconds,
    },
  );

  static List<String> _movedCardIds(FreeCellState before, FreeCellState after) {
    final previous = _locations(before);
    return [
      for (final MapEntry(:key, :value) in _locations(after).entries)
        if (previous[key] != value) key,
    ];
  }

  static Map<String, FreeCellPile> _locations(FreeCellState state) => {
    for (final ref in FreeCellPile.all)
      for (final card in state.pile(ref)) card.id: ref,
  };
}
