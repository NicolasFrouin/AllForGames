import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../cards/deal_random.dart';
import '../../l10n/app_localizations.dart';
import '../../saves/game_save_store.dart';
import '../../stats/game_record.dart';
import '../../stats/play_timer.dart';
import '../../stats/stats_store.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_generator.dart';
import 'mahjong_layout.dart';
import 'mahjong_solver.dart';
import 'mahjong_state.dart';
import 'mahjong_tiles.dart';

/// What a tap on a tile did.
enum TileTap { selected, deselected, matched, blocked, ignored }

/// What changed the board last, so the board can animate it.
enum MahjongAction { none, deal, match, undo, shuffle }

/// Keys of the Mahjong-specific counters in [GameRecord.details].
abstract final class MahjongStatKeys {
  static const pairsMatched = 'pairsMatched';
  static const hints = 'hints';
  static const shuffles = 'shuffles';
  static const tilesLeft = 'tilesLeft';
  static const bestCombo = 'bestCombo';
  static const timeToFirstMatchMs = 'timeToFirstMatchMs';
  static const longestThinkMs = 'longestThinkMs';

  static final labels = <String, String Function(AppLocalizations)>{
    pairsMatched: (l10n) => l10n.mahjongPairsMatched,
    hints: (l10n) => l10n.mahjongHints,
    shuffles: (l10n) => l10n.mahjongShuffles,
    tilesLeft: (l10n) => l10n.mahjongTilesLeft,
    bestCombo: (l10n) => l10n.mahjongBestCombo,
    timeToFirstMatchMs: (l10n) => l10n.mahjongTimeToFirstMatch,
    longestThinkMs: (l10n) => l10n.mahjongLongestThink,
  };
}

/// A board before an action, for undo.
class _Snapshot {
  const _Snapshot(this.slots, this.score, this.solution);

  final List<int> slots;
  final int score;

  /// Null when unknown (a game continued from a save).
  final List<TilePair>? solution;
}

/// Runs one Mahjong game at a time. It saves the game after each action, so
/// the player can continue it later, and records it when it ends.
///
/// It also keeps an order of pairs that clears the board, mended after each
/// match, so a hint can show a pair that keeps the game winnable.
class MahjongController extends ChangeNotifier {
  MahjongController({
    required this._stats,
    required this._saves,
    MahjongDifficulty difficulty = MahjongDifficulty.medium,
    bool transposed = false,
    int? seed,
    MahjongState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(
      difficulty: difficulty,
      transposed: transposed,
      seed: seed,
      initialState: initialState,
    );
  }

  /// Continues a game saved by [toJson]. Throws a [FormatException] when
  /// [json] is not a readable Mahjong save.
  MahjongController.restore(
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
      throw FormatException('Unreadable Mahjong save: $error');
    }
  }

  static const gameId = 'mahjong';

  /// Matches closer than this in time make a combo.
  static const comboWindow = Duration(seconds: 4);

  /// Points of a match, plus [comboBonus] for each match before it in the
  /// combo (up to [maxComboBonus]).
  static const matchPoints = 10;
  static const comboBonus = 5;
  static const maxComboBonus = 20;

  /// Version of the [toJson] format.
  static const _saveVersion = 1;

  /// Boards the hint solver may look at: a few tens of milliseconds.
  static const _solverBudget = 20000;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <_Snapshot>[];
  final _counters = <String, int>{};

  late MahjongState _state;
  late int _seed;
  late MahjongDifficulty _difficulty;
  late DateTime _startedAt;
  late PlayTimer _timer;
  late int _initialTiles;
  List<TilePair>? _solution;

  /// The board where the solver found no order, so it does not search again.
  List<int>? _unsolvedSlots;
  int _score = 0;
  int _moves = 0;
  int _undos = 0;
  int _combo = 0;
  int _bestCombo = 0;
  Duration? _lastMatchAt;
  Duration? _timeToFirstMatch;
  Duration _lastActionAt = Duration.zero;
  Duration _longestThink = Duration.zero;
  GameRecord? _result;
  bool _finished = false;
  int? _selected;
  TilePair? _hint;
  int _hintSerial = 0;
  MahjongAction _lastAction = MahjongAction.none;
  int _actionSerial = 0;

  MahjongState get state => _state;
  int get seed => _seed;
  MahjongDifficulty get difficulty => _difficulty;
  int get score => _score;

  /// Matches made, also those taken back.
  int get moves => _moves;
  int get undos => _undos;
  int get hints => _counters[MahjongStatKeys.hints] ?? 0;
  int get shuffles => _counters[MahjongStatKeys.shuffles] ?? 0;

  /// Matches in a row, each within [comboWindow] of the one before.
  int get combo => _combo;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;

  /// No match is left: the player can undo or shuffle.
  bool get isStuck => !_finished && _state.isStuck;
  bool get canHint => !_finished && _state.freePairs.isNotEmpty;

  /// The record of the won game, or null while the game runs.
  GameRecord? get result => _result;

  /// The tile the player picked first, waiting for its match.
  int? get selected => _selected;

  /// The pair of the last hint, until the next action.
  TilePair? get hintPair => _hint;

  /// Changes at every hint, so the board shows each one once.
  int get hintSerial => _hintSerial;

  /// The last action ([MahjongAction.none] for a game that continues).
  MahjongAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Selects a free tile, or matches it with the selected one. A tap on the
  /// selected tile unselects it, a tap on a free tile that does not match
  /// selects that one instead.
  TileTap tap(int id) {
    if (_finished || _state.positionOf(id) == null) return TileTap.ignored;
    if (!_state.isFree(id)) return TileTap.blocked;
    final selected = _selected;
    if (selected == id) {
      _selected = null;
      notifyListeners();
      return TileTap.deselected;
    }
    if (selected != null && match(selected, id)) return TileTap.matched;
    _selected = id;
    notifyListeners();
    return TileTap.selected;
  }

  /// Removes [a] and [b] when they are free and match.
  bool match(int a, int b) {
    if (_finished) return false;
    final next = _state.match(a, b);
    if (next == null) return false;
    _remember();
    final now = _timer.elapsed;
    final lastMatch = _lastMatchAt;
    _combo = _combo > 0 && lastMatch != null && now - lastMatch <= comboWindow
        ? _combo + 1
        : 1;
    _bestCombo = max(_bestCombo, _combo);
    _lastMatchAt = now;
    _timeToFirstMatch ??= now;
    _score += matchPoints + min((_combo - 1) * comboBonus, maxComboBonus);
    _moves++;
    if (_solution case final solution?) {
      _solution = mendSolution(next, solution, a, b);
    }
    _apply(next, MahjongAction.match);
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
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _score = previous.score;
    _solution = previous.solution;
    _undos++;
    _combo = 0;
    _apply(_state.withSlots(previous.slots), MahjongAction.undo);
    save();
    notifyListeners();
  }

  /// Shows a pair to match: one that keeps the game winnable when the
  /// controller knows one, else the pair that frees the most tiles. Null
  /// when no match is left.
  TilePair? hint() {
    if (!canHint) return null;
    final pair = _winningPair() ?? _mostFreeingPair();
    _bump(MahjongStatKeys.hints);
    _hint = pair;
    _hintSerial++;
    _combo = 0;
    _noteAction();
    save();
    notifyListeners();
    return pair;
  }

  /// When no match is left, moves the tiles to new places from where the
  /// game can be won.
  bool shuffle() {
    if (!isStuck) return false;
    _remember();
    _bump(MahjongStatKeys.shuffles);
    final shuffled = shuffleTiles(
      _state,
      DealRandom(_seed + 7919 * (shuffles + _moves)),
    );
    _solution = shuffled.solution;
    _combo = 0;
    _apply(shuffled.state, MahjongAction.shuffle);
    save();
    notifyListeners();
    return true;
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
  /// the player made at least one match and did not win it.
  ///
  /// [difficulty] defaults to the current one; [transposed] (rows and
  /// columns swapped, for tall screens) to the current orientation.
  void newGame({
    MahjongDifficulty? difficulty,
    bool? transposed,
    int? seed,
    MahjongState? initialState,
  }) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? _difficulty,
      transposed: transposed ?? _state.layout.transposed,
      seed: seed,
      initialState: initialState,
    );
    save();
    notifyListeners();
  }

  /// The whole game, undo history included, for [MahjongController.restore].
  Map<String, Object?> toJson() => {
    'version': _saveVersion,
    'seed': _seed,
    'difficulty': _difficulty.name,
    'layout': _state.layout.id,
    'transposed': _state.layout.transposed,
    'faces': _state.faces,
    'slots': _state.slots,
    'solution': _encodePairs(_solution),
    'history': [
      for (final entry in _history) [entry.score, entry.slots],
    ],
    'startedAt': _startedAt.toUtc().toIso8601String(),
    'playTimeMs': _timer.elapsed.inMilliseconds,
    'score': _score,
    'moves': _moves,
    'undos': _undos,
    'counters': {..._counters},
    'initialTiles': _initialTiles,
    'combo': _combo,
    'bestCombo': _bestCombo,
    'lastMatchMs': _lastMatchAt?.inMilliseconds,
    'timeToFirstMatchMs': _timeToFirstMatch?.inMilliseconds,
    'lastActionMs': _lastActionAt.inMilliseconds,
    'longestThinkMs': _longestThink.inMilliseconds,
  };

  void _restore(Map<String, Object?> json) {
    if (json['version'] != _saveVersion) {
      throw FormatException('Unknown Mahjong save version ${json['version']}');
    }
    Duration duration(Object? ms) => Duration(milliseconds: ms as int);
    Duration? optionalDuration(Object? ms) => ms == null ? null : duration(ms);
    List<int> ints(Object? list) => (list as List<Object?>).cast<int>();

    final layout = layoutById(
      json['layout'] as String,
      transposed: json['transposed'] as bool,
    );
    if (layout == null) {
      throw FormatException('Unknown Mahjong layout ${json['layout']}');
    }
    final faces = ints(json['faces']);
    if (faces.length != layout.length ||
        faces.any((face) => face < 0 || face >= TileFace.count)) {
      throw const FormatException('Bad Mahjong tile faces');
    }
    MahjongState board(Object? slots) {
      final list = ints(slots);
      final ids = list.where((id) => id != MahjongState.empty).toList();
      if (list.length != layout.length ||
          ids.any((id) => id < 0 || id >= faces.length) ||
          ids.toSet().length != ids.length) {
        throw const FormatException('Bad Mahjong board');
      }
      return MahjongState(layout: layout, faces: faces, slots: list);
    }

    _seed = json['seed'] as int;
    _difficulty = MahjongDifficulty.values.byName(json['difficulty'] as String);
    _state = board(json['slots']);
    final solution = _decodePairs(json['solution']);
    _solution = solution != null && _state.isSolvedBy(solution)
        ? solution
        : null;
    _history.addAll([
      for (final entry
          in (json['history'] as List<Object?>).cast<List<Object?>>())
        _Snapshot(board(entry[1]).slots, entry[0] as int, null),
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
    _initialTiles = json['initialTiles'] as int;
    _combo = json['combo'] as int;
    _bestCombo = json['bestCombo'] as int;
    _lastMatchAt = optionalDuration(json['lastMatchMs']);
    _timeToFirstMatch = optionalDuration(json['timeToFirstMatchMs']);
    _lastActionAt = duration(json['lastActionMs']);
    _longestThink = duration(json['longestThinkMs']);
  }

  void _start({
    required MahjongDifficulty difficulty,
    required bool transposed,
    int? seed,
    MahjongState? initialState,
  }) {
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _difficulty = difficulty;
    if (initialState != null) {
      _state = initialState;
      _solution = solveMahjong(initialState, budget: _solverBudget);
    } else {
      final deal = generateDeal(
        difficulty.layout(transposed: transposed),
        _seed,
        trapPercent: difficulty.trapPercent,
      );
      _state = deal.state;
      _solution = deal.solution;
    }
    _unsolvedSlots = null;
    _initialTiles = _state.tileCount;
    _startedAt = _clock();
    _timer = PlayTimer(clock: _clock)..start();
    _history.clear();
    _counters.clear();
    _score = 0;
    _moves = 0;
    _undos = 0;
    _combo = 0;
    _bestCombo = 0;
    _lastMatchAt = null;
    _timeToFirstMatch = null;
    _lastActionAt = Duration.zero;
    _longestThink = Duration.zero;
    _result = null;
    _finished = false;
    _selected = null;
    _hint = null;
    _lastAction = MahjongAction.deal;
    _actionSerial++;
  }

  void _remember() => _history.add(_Snapshot(_state.slots, _score, _solution));

  void _apply(MahjongState next, MahjongAction action) {
    _state = next;
    _selected = null;
    _hint = null;
    _lastAction = action;
    _actionSerial++;
    _noteAction();
  }

  /// The first pair of the order that clears the board, searching for one
  /// when the order is unknown (after a match it could not mend).
  TilePair? _winningPair() {
    if (_solution == null && !listEquals(_unsolvedSlots, _state.slots)) {
      _solution = solveMahjong(_state, budget: _solverBudget);
      if (_solution == null) _unsolvedSlots = _state.slots;
    }
    return _solution?.firstOrNull;
  }

  TilePair _mostFreeingPair() {
    final pairs = _state.freePairs;
    var best = pairs.first;
    var bestFreed = -1;
    for (final (a, b) in pairs) {
      final next = _state.match(a, b)!;
      final freed = next.tileIds
          .where((id) => next.isFree(id) && !_state.isFree(id))
          .length;
      if (freed > bestFreed) {
        best = (a, b);
        bestFreed = freed;
      }
    }
    return best;
  }

  void _noteAction() {
    final now = _timer.elapsed;
    final think = now - _lastActionAt;
    if (think > _longestThink) _longestThink = think;
    _lastActionAt = now;
  }

  void _bump(String key) => _counters[key] = (_counters[key] ?? 0) + 1;

  GameRecord _record(GameOutcome outcome) => GameRecord(
    gameId: gameId,
    variant: _state.layout.id,
    seed: _seed,
    startedAt: _startedAt,
    endedAt: _clock(),
    playTime: _timer.elapsed,
    outcome: outcome,
    moves: _moves,
    undos: _undos,
    score: _score,
    difficulty: _difficulty.name,
    details: {
      MahjongStatKeys.hints: hints,
      MahjongStatKeys.shuffles: shuffles,
      // From the board, so matches taken back do not count.
      MahjongStatKeys.pairsMatched: (_initialTiles - _state.tileCount) ~/ 2,
      MahjongStatKeys.tilesLeft: _state.tileCount,
      MahjongStatKeys.bestCombo: _bestCombo,
      if (_timeToFirstMatch case final first?)
        MahjongStatKeys.timeToFirstMatchMs: first.inMilliseconds,
      MahjongStatKeys.longestThinkMs: _longestThink.inMilliseconds,
    },
  );

  static List<int>? _encodePairs(List<TilePair>? pairs) => pairs == null
      ? null
      : [
          for (final (a, b) in pairs) ...[a, b],
        ];

  static List<TilePair>? _decodePairs(Object? json) {
    if (json == null) return null;
    final ids = (json as List<Object?>).cast<int>();
    return [for (var i = 0; i + 1 < ids.length; i += 2) (ids[i], ids[i + 1])];
  }
}
