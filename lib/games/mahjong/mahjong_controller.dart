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
import 'mahjong_tray.dart';

/// What a tap on a tile did. In tray mode, a tile [picked] waits in the
/// tray, a tile [matched] cleared a tile of the tray.
enum TileTap { selected, deselected, matched, picked, blocked, ignored }

/// What changed the board last, so the board can animate it.
enum MahjongAction { none, deal, match, pick, undo, shuffle }

/// Keys of the Mahjong-specific counters in [GameRecord.details].
abstract final class MahjongStatKeys {
  static const pairsMatched = 'pairsMatched';
  static const hints = 'hints';
  static const shuffles = 'shuffles';
  static const tilesLeft = 'tilesLeft';
  static const bestCombo = 'bestCombo';
  static const timeToFirstMatchMs = 'timeToFirstMatchMs';
  static const longestThinkMs = 'longestThinkMs';

  /// Tray mode: the most tiles the tray held at once (4 for a lost game),
  /// and the tiles that went into the tray to wait for their partner.
  static const mostHeld = 'mostHeld';
  static const tilesHeld = 'tilesHeld';

  static final labels = <String, String Function(AppLocalizations)>{
    pairsMatched: (l10n) => l10n.mahjongPairsMatched,
    hints: (l10n) => l10n.mahjongHints,
    shuffles: (l10n) => l10n.mahjongShuffles,
    tilesLeft: (l10n) => l10n.mahjongTilesLeft,
    bestCombo: (l10n) => l10n.mahjongBestCombo,
    timeToFirstMatchMs: (l10n) => l10n.mahjongTimeToFirstMatch,
    longestThinkMs: (l10n) => l10n.mahjongLongestThink,
    mostHeld: (l10n) => l10n.mahjongMostHeld,
    tilesHeld: (l10n) => l10n.mahjongTilesHeld,
  };
}

/// The variant of a record: the layout, or the tray mode on the layout.
String mahjongVariant(MahjongMode mode, String layoutId) =>
    mode == MahjongMode.tray ? '$_trayPrefix$layoutId' : layoutId;

/// The mode and the layout id of a record's [variant].
(MahjongMode, String) mahjongModeAndLayout(String variant) =>
    variant.startsWith(_trayPrefix)
    ? (MahjongMode.tray, variant.substring(_trayPrefix.length))
    : (MahjongMode.classic, variant);

const _trayPrefix = 'tray-';

/// A board before an action, for undo.
class _Snapshot {
  const _Snapshot(this.slots, this.tray, this.score, this.solution, this.picks);

  final List<int> slots;
  final List<int> tray;
  final int score;

  /// Null when unknown (a game continued from a save).
  final List<TilePair>? solution;
  final List<int>? picks;
}

/// Runs one Mahjong game at a time, in either [MahjongMode]. It saves the
/// game after each action, so the player can continue it later, and records
/// it when it ends.
///
/// It also keeps an order that wins the game (pairs in classic mode, picks
/// in tray mode), mended after each action, so a hint can show a move that
/// keeps the game winnable.
class MahjongController extends ChangeNotifier {
  MahjongController({
    required this._stats,
    required this._saves,
    MahjongDifficulty difficulty = MahjongDifficulty.medium,
    MahjongMode mode = MahjongMode.classic,
    bool transposed = false,
    int? seed,
    MahjongState? initialState,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _start(
      difficulty: difficulty,
      mode: mode,
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

  /// Version of the [toJson] format. Version 1 had four flower faces (34 to
  /// 37) and four season faces (38 to 41), any flower matching any flower,
  /// and no tray mode.
  static const _saveVersion = 2;

  /// Boards the hint solver may look at: a few tens of milliseconds.
  static const _solverBudget = 20000;

  final StatsStore _stats;
  final GameSaveStore _saves;
  final DateTime Function() _clock;
  final _history = <_Snapshot>[];
  final _counters = <String, int>{};

  late MahjongState _state;
  late MahjongMode _mode;
  List<int> _tray = const [];
  late int _seed;
  late MahjongDifficulty _difficulty;
  late DateTime _startedAt;
  late PlayTimer _timer;
  late int _initialTiles;
  List<TilePair>? _solution;
  List<int>? _picks;

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
  List<int> _hint = const [];
  int _hintSerial = 0;
  MahjongAction _lastAction = MahjongAction.none;
  int _actionSerial = 0;

  /// The board. In tray mode, the tiles of the tray are not on it.
  MahjongState get state => _state;
  MahjongMode get mode => _mode;
  bool get isTray => _mode == MahjongMode.tray;

  /// Ids of the tiles in the tray, in the order they came (tray mode).
  List<int> get tray => _tray;
  TrayState get trayState => TrayState(_state, _tray);
  int get seed => _seed;
  MahjongDifficulty get difficulty => _difficulty;
  int get score => _score;

  /// Tiles left to clear: on the board, and in the tray.
  int get tilesLeft => _state.tileCount + _tray.length;

  /// Matches made (picks in tray mode), also those taken back.
  int get moves => _moves;
  int get undos => _undos;
  int get hints => _counters[MahjongStatKeys.hints] ?? 0;
  int get shuffles => _counters[MahjongStatKeys.shuffles] ?? 0;

  /// Matches in a row, each within [comboWindow] of the one before.
  int get combo => _combo;
  Duration get playTime => _timer.elapsed;
  bool get canUndo => !_finished && _history.isNotEmpty;

  /// No move is left that does not lose: in classic mode, no match (the
  /// player can undo or shuffle); in tray mode, the tray is one tile from
  /// full and no free tile clears one of it (the player can undo).
  bool get isStuck =>
      !_finished && (isTray ? trayState.isStuck : _state.isStuck);
  bool get canHint =>
      !_finished && (isTray ? !trayState.isStuck : _state.freePairs.isNotEmpty);

  /// The record of the game once it is over (won, or lost in tray mode),
  /// null while it runs.
  GameRecord? get result => _result;

  /// The tray filled up: the game is over.
  bool get isLost => _result?.outcome == GameOutcome.lost;

  /// The tile the player picked first, waiting for its match.
  int? get selected => _selected;

  /// The pair of the last hint (classic mode), until the next action.
  TilePair? get hintPair =>
      !isTray && _hint.length == 2 ? (_hint[0], _hint[1]) : null;

  /// The tiles the last hint lights, until the next action: a pair in
  /// classic mode; in tray mode the tile to pick, and the tile of the tray
  /// it clears.
  List<int> get hintedTiles => _hint;

  /// Changes at every hint, so the board shows each one once.
  int get hintSerial => _hintSerial;

  /// The last action ([MahjongAction.none] for a game that continues).
  MahjongAction get lastAction => _lastAction;

  /// Changes at every action, so the board sees each one once.
  int get actionSerial => _actionSerial;

  /// Classic mode: selects a free tile, or matches it with the selected
  /// one. A tap on the selected tile unselects it, a tap on a free tile that
  /// does not match selects that one instead. Tray mode: picks the tile.
  TileTap tap(int id) {
    if (_finished || _state.positionOf(id) == null) return TileTap.ignored;
    if (!_state.isFree(id)) return TileTap.blocked;
    if (isTray) return _pick(id);
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

  /// Removes [a] and [b] when they are free and match (classic mode).
  bool match(int a, int b) {
    if (_finished || isTray) return false;
    final next = _state.match(a, b);
    if (next == null) return false;
    _remember();
    _scoreMatch();
    _moves++;
    if (_solution case final solution?) {
      _solution = mendSolution(next, solution, a, b);
    }
    _apply(next, MahjongAction.match);
    if (_state.isWon) {
      _finish(GameOutcome.won);
    } else {
      save();
    }
    notifyListeners();
    return true;
  }

  /// Tray mode: [id] goes into the tray, or clears its partner there. The
  /// game is lost at once when the tray fills.
  TileTap _pick(int id) {
    final before = trayState;
    final next = before.pick(id)!;
    _remember();
    _moves++;
    final cleared = next.tray.length < before.tray.length;
    if (cleared) {
      _scoreMatch();
    } else {
      _bump(MahjongStatKeys.tilesHeld);
      _counters[MahjongStatKeys.mostHeld] = max(
        _counters[MahjongStatKeys.mostHeld] ?? 0,
        next.tray.length,
      );
    }
    if (_picks case final picks?) {
      // Taking a tile earlier never blocks another: only the tray can fill.
      final mended = [
        for (final pick in picks)
          if (pick != id) pick,
      ];
      _picks = next.isSolvedBy(mended) ? mended : null;
    }
    _tray = next.tray;
    _apply(next.board, MahjongAction.pick);
    if (next.isWon) {
      _finish(GameOutcome.won);
    } else if (next.isLost) {
      _finish(GameOutcome.lost);
    } else {
      save();
    }
    notifyListeners();
    return cleared ? TileTap.matched : TileTap.picked;
  }

  void undo() {
    if (!canUndo) return;
    final previous = _history.removeLast();
    _score = previous.score;
    _solution = previous.solution;
    _picks = previous.picks;
    _tray = previous.tray;
    _undos++;
    _combo = 0;
    _apply(_state.withSlots(previous.slots), MahjongAction.undo);
    save();
    notifyListeners();
  }

  /// Classic mode: shows a pair to match, one that keeps the game winnable
  /// when the controller knows one, else the pair that frees the most
  /// tiles. Null when no match is left.
  TilePair? hint() {
    if (!canHint || isTray) return null;
    final pair = _winningPair() ?? _mostFreeingPair();
    _showHint([pair.$1, pair.$2]);
    return pair;
  }

  /// Tray mode: shows a tile to pick, one that keeps the game winnable when
  /// the controller knows or finds one, else a safe one (it clears a tile
  /// of the tray, or its partner is free too). Null when there is none.
  int? hintPick() {
    if (!canHint || !isTray) return null;
    final pick = _winningPick() ?? _safePick();
    if (pick == null) return null;
    _showHint([pick, ?trayState.partnerOf(pick)]);
    return pick;
  }

  void _showHint(List<int> tiles) {
    _bump(MahjongStatKeys.hints);
    _hint = tiles;
    _hintSerial++;
    _combo = 0;
    _noteAction();
    save();
    notifyListeners();
  }

  /// When no match is left, moves the tiles to new places from where the
  /// game can be won (classic mode).
  bool shuffle() {
    if (!isStuck || isTray) return false;
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

  /// Saves the game so the player can continue it later. A finished game is
  /// not saved: it is in the statistics.
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
  /// the player made at least one move and did not finish it.
  ///
  /// [difficulty] and [mode] default to the current ones; [transposed]
  /// (rows and columns swapped, for tall screens) to the current
  /// orientation.
  void newGame({
    MahjongDifficulty? difficulty,
    MahjongMode? mode,
    bool? transposed,
    int? seed,
    MahjongState? initialState,
  }) {
    if (!_finished && _moves > 0) {
      unawaited(_stats.add(_record(GameOutcome.abandoned)));
    }
    _start(
      difficulty: difficulty ?? _difficulty,
      mode: mode ?? _mode,
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
    'mode': _mode.name,
    'seed': _seed,
    'difficulty': _difficulty.name,
    'layout': _state.layout.id,
    'transposed': _state.layout.transposed,
    'faces': _state.faces,
    'slots': _state.slots,
    'tray': _tray,
    'solution': isTray ? _picks : _encodePairs(_solution),
    'history': [
      for (final entry in _history) [entry.score, entry.slots, entry.tray],
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
    final version = json['version'];
    if (version != _saveVersion && version != 1) {
      throw FormatException('Unknown Mahjong save version $version');
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
    final faces = [
      for (final face in ints(json['faces']))
        version == 1 ? _faceOfVersion1(face) : face,
    ];
    if (faces.length != layout.length ||
        faces.any((face) => face < 0 || face >= TileFace.count)) {
      throw const FormatException('Bad Mahjong tile faces');
    }
    _mode = MahjongMode.values.byName(
      json['mode'] as String? ?? MahjongMode.classic.name,
    );
    // A board, and the tray beside it (none in classic mode).
    (List<int>, List<int>) board(Object? slots, Object? tray) {
      final list = ints(slots);
      final waiting = isTray && tray != null ? ints(tray) : const <int>[];
      final ids = [...list.where((id) => id != MahjongState.empty), ...waiting];
      if (list.length != layout.length ||
          waiting.length >= TrayState.capacity ||
          ids.any((id) => id < 0 || id >= faces.length) ||
          ids.toSet().length != ids.length) {
        throw const FormatException('Bad Mahjong board');
      }
      return (list, waiting);
    }

    _seed = json['seed'] as int;
    _difficulty = MahjongDifficulty.values.byName(json['difficulty'] as String);
    final (slots, tray) = board(json['slots'], json['tray']);
    _state = MahjongState(layout: layout, faces: faces, slots: slots);
    _tray = tray;
    final solution = json['solution'];
    if (isTray) {
      final picks = solution == null ? null : ints(solution);
      _picks = picks != null && trayState.isSolvedBy(picks) ? picks : null;
    } else {
      final pairs = _decodePairs(solution);
      _solution = pairs != null && _state.isSolvedBy(pairs) ? pairs : null;
    }
    _history.addAll([
      for (final entry
          in (json['history'] as List<Object?>).cast<List<Object?>>())
        if (board(entry[1], entry.length > 2 ? entry[2] : null) case (
          final slots,
          final tray,
        ))
          _Snapshot(slots, tray, entry[0] as int, null, null),
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
    required MahjongMode mode,
    required bool transposed,
    int? seed,
    MahjongState? initialState,
  }) {
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _difficulty = difficulty;
    _mode = mode;
    _tray = const [];
    _solution = null;
    _picks = null;
    final layout = difficulty.layout(transposed: transposed);
    if (initialState != null) {
      _state = initialState;
      if (isTray) {
        _picks = solveTray(trayState, budget: _solverBudget);
      } else {
        _solution = solveMahjong(initialState, budget: _solverBudget);
      }
    } else if (isTray) {
      final deal = generateTrayDeal(layout, _seed, difficulty.tray);
      _state = deal.state;
      _picks = deal.solution;
    } else {
      final deal = generateDeal(
        layout,
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
    _hint = const [];
    _lastAction = MahjongAction.deal;
    _actionSerial++;
  }

  void _remember() =>
      _history.add(_Snapshot(_state.slots, _tray, _score, _solution, _picks));

  void _apply(MahjongState next, MahjongAction action) {
    _state = next;
    _selected = null;
    _hint = const [];
    _lastAction = action;
    _actionSerial++;
    _noteAction();
  }

  /// A pair cleared: points, more in a combo.
  void _scoreMatch() {
    final now = _timer.elapsed;
    final lastMatch = _lastMatchAt;
    _combo = _combo > 0 && lastMatch != null && now - lastMatch <= comboWindow
        ? _combo + 1
        : 1;
    _bestCombo = max(_bestCombo, _combo);
    _lastMatchAt = now;
    _timeToFirstMatch ??= now;
    _score += matchPoints + min((_combo - 1) * comboBonus, maxComboBonus);
  }

  /// Ends the game: it goes to the statistics, and its save away.
  void _finish(GameOutcome outcome) {
    _finished = true;
    _timer.pause();
    final record = _record(outcome);
    _result = record;
    unawaited(_stats.add(record));
    unawaited(_saves.remove(gameId));
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
      final freed = _freedBy(_state.match(a, b)!);
      if (freed > bestFreed) {
        best = (a, b);
        bestFreed = freed;
      }
    }
    return best;
  }

  /// The tiles free on [next] that are not free now.
  int _freedBy(MahjongState next) =>
      next.tileIds.where((id) => next.isFree(id) && !_state.isFree(id)).length;

  /// The first pick of the order that wins, searching for one when the
  /// order is unknown (after a pick out of it). The tiles gone tell what
  /// waits in the tray, so the board alone keys a failed search.
  int? _winningPick() {
    if (_picks == null && !listEquals(_unsolvedSlots, _state.slots)) {
      _picks = solveTray(trayState, budget: _solverBudget);
      if (_picks == null) _unsolvedSlots = _state.slots;
    }
    return _picks?.firstOrNull;
  }

  /// A free tile that clears a tile of the tray, else, while the tray has
  /// room, a tile of a free pair, else the free tile that frees the most.
  int? _safePick() {
    final tray = trayState;
    if (tray.freeMatches case [final match, ...]) return match;
    if (tray.tray.length >= TrayState.capacity - 1) return null;
    if (_state.freePairs case [(final a, _), ...]) return a;
    int? best;
    var bestFreed = -1;
    for (final id in _state.tileIds) {
      if (!_state.isFree(id)) continue;
      final freed = _freedBy(tray.pick(id)!.board);
      if (freed > bestFreed) {
        best = id;
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
    variant: mahjongVariant(_mode, _state.layout.id),
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
      if (!isTray) MahjongStatKeys.shuffles: shuffles,
      // From the board, so matches taken back do not count.
      MahjongStatKeys.pairsMatched: (_initialTiles - tilesLeft) ~/ 2,
      MahjongStatKeys.tilesLeft: tilesLeft,
      MahjongStatKeys.bestCombo: _bestCombo,
      if (_timeToFirstMatch case final first?)
        MahjongStatKeys.timeToFirstMatchMs: first.inMilliseconds,
      MahjongStatKeys.longestThinkMs: _longestThink.inMilliseconds,
      if (isTray) ...{
        MahjongStatKeys.mostHeld: _counters[MahjongStatKeys.mostHeld] ?? 0,
        MahjongStatKeys.tilesHeld: _counters[MahjongStatKeys.tilesHeld] ?? 0,
      },
    },
  );

  /// The flower (34) for the old flowers, the season (35) for the seasons.
  static int _faceOfVersion1(int face) => switch (face) {
    >= 34 && < 38 => 34,
    >= 38 && < 42 => 35,
    _ => face,
  };

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
