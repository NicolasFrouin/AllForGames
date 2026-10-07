import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../../cards/confetti.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_store.dart';
import '../../skins/minesweeper_themes.dart';
import 'minesweeper_art.dart';
import 'minesweeper_controller.dart';
import 'minesweeper_difficulty.dart';
import 'minesweeper_motion.dart';
import 'minesweeper_state.dart';

/// The size of the cells of a board of [columns] by [rows], and where each
/// cell is.
class MinesweeperBoardGeometry {
  const MinesweeperBoardGeometry(this.columns, this.rows, this.cell);

  /// The biggest cells that fit in [room].
  factory MinesweeperBoardGeometry.fit(Size room, int columns, int rows) {
    final cell = [
      room.width / columns,
      room.height / rows,
      maxCell,
    ].reduce(min);
    return MinesweeperBoardGeometry(columns, rows, max(cell, 1));
  }

  static const maxCell = 60.0;

  /// Smaller cells are hard to tap: the board keeps this size, and the
  /// player pans (and zooms) it.
  static const minCell = 22.0;

  /// Room around the cells, for the frame of the board.
  static const frame = 6.0;

  final int columns;
  final int rows;
  final double cell;

  Size get size => Size(columns * cell, rows * cell);

  Rect rectOf(int index) => Rect.fromLTWH(
    index % columns * cell,
    index ~/ columns * cell,
    cell,
    cell,
  );

  /// The cell at [position] on the board, or null outside it.
  int? cellAt(Offset position) {
    final x = (position.dx / cell).floor();
    final y = (position.dy / cell).floor();
    if (x < 0 || x >= columns || y < 0 || y >= rows) return null;
    return y * columns + x;
  }

  /// Whether a board of [difficulty] gets bigger cells in [room] with rows
  /// and columns swapped (a phone held upright).
  static bool prefersTurned(Size room, MinesweeperDifficulty difficulty) {
    final (columns, rows) = difficulty.size();
    if (columns == rows) return false;
    final normal = MinesweeperBoardGeometry.fit(room, columns, rows).cell;
    final turned = MinesweeperBoardGeometry.fit(room, rows, columns).cell;
    return turned > normal * 1.1;
  }
}

/// What a cell shows at rest.
enum _Look { covered, flagged, open, mine, exploded, wrongFlag }

_Look _lookOf(MinesweeperState state, int cell) {
  if (state.isFlagged(cell)) {
    return state.isLost && !state.isMine(cell)
        ? _Look.wrongFlag
        : _Look.flagged;
  }
  if (state.isMine(cell) && (state.isOpen(cell) || state.isLost)) {
    return cell == state.exploded ? _Look.exploded : _Look.mine;
  }
  return state.isOpen(cell) ? _Look.open : _Look.covered;
}

/// Changes when the cells in motion change, so the still layer draws again.
class _StillVersion extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Draws the Minesweeper board, and turns taps into actions: tap opens (or
/// flags in [flagMode]), a hold of [flagHold] and a secondary tap flag, a
/// tap on a number chords.
///
/// One timeline animates the board: each action plans a [CellMotion] for
/// the cells it changes (a reveal spreading from the tap, a flag popping,
/// the mines of a lost game one after the other). Two layers draw it: the
/// cells at rest, repainted when an action changes them, and the cells in
/// motion, repainted at each frame. No widget rebuilds while it plays.
class MinesweeperBoard extends StatefulWidget {
  const MinesweeperBoard({
    super.key,
    required this.controller,
    this.theme = classicMinesweeperTheme,
    this.flagMode = false,
    this.flagHold = const Duration(
      milliseconds: SettingsStore.defaultFlagHoldMs,
    ),
    this.onCelebrated,
    this.onLost,
  });

  final MinesweeperController controller;
  final MinesweeperTheme theme;

  /// A tap flags a hidden cell instead of opening it.
  final bool flagMode;

  /// How long a finger holds a cell to flag it.
  final Duration flagHold;

  /// Called once after a win, when the celebration has played (at once with
  /// reduced motion): time for the win dialog.
  final VoidCallback? onCelebrated;

  /// Called once after a loss, when every mine has shown.
  final VoidCallback? onLost;

  @override
  State<MinesweeperBoard> createState() => _MinesweeperBoardState();
}

class _MinesweeperBoardState extends State<MinesweeperBoard>
    with SingleTickerProviderStateMixin {
  // Durations in milliseconds.
  static const _revealDuration = 210.0;

  /// Reveals spread from the tap at this pace per cell, at most over
  /// [_spreadTime].
  static const _revealStep = 26.0;
  static const _spreadTime = 420.0;

  /// From the last flag of a win to the win dialog.
  static const _celebration = 1250.0;

  /// Where the confetti of a win bursts from, as fractions of the board.
  static const _bursts = [
    (0.5, 0.45),
    (0.2, 0.3),
    (0.8, 0.3),
    (0.3, 0.75),
    (0.7, 0.75),
  ];

  late final Ticker _ticker = createTicker(_onTick);
  final _boardKey = GlobalKey();

  /// Confetti is drawn on the page overlay, above the app bar.
  final _confettiLayer = OverlayPortalController()..show();

  /// Time on the timeline, in ms. It only goes forward.
  final _clock = ValueNotifier<double>(0);
  double _tickerStart = 0;
  double _end = 0;

  /// The cells in motion. The still layer leaves them to the motion layer.
  final _motions = <int, CellMotion>{};
  final _still = _StillVersion();

  /// The covered cell under the finger, drawn pressed down.
  final _pressed = ValueNotifier<int?>(null);
  Confetti? _confetti;
  double? _celebratedAt;
  double? _lostAt;
  MinesweeperState? _previous;
  MinesweeperBoardGeometry? _geometry;
  MinesweeperArt? _art;
  int? _seenSerial;
  int? _seenHint;

  MinesweeperController get _controller => widget.controller;
  double get _now => _clock.value;

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _still.dispose();
    _pressed.dispose();
    _art?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final now = _tickerStart + elapsed.inMicroseconds / 1000;
    _clock.value = now;
    if (_lostAt case final at? when now >= at) {
      _lostAt = null;
      widget.onLost?.call();
    }
    if (_celebratedAt case final at? when now >= at) {
      _celebratedAt = null;
      widget.onCelebrated?.call();
    }
    if (now >= _end) _stopTimeline();
  }

  void _stopTimeline() {
    _ticker.stop();
    _confetti = null;
    if (_motions.isNotEmpty) {
      _motions.clear();
      _still.bump();
    }
  }

  /// Adds motions (and a celebration) planned from now. Running motions go
  /// on from where they are.
  void _addMotions(
    Map<int, CellMotion> added, {
    Confetti? confetti,
    double? celebratedAt,
    double? lostAt,
  }) {
    if (added.isEmpty && confetti == null) return;
    final now = _now;
    for (final MapEntry(key: cell, value: motion) in added.entries) {
      _motions[cell] = motion.shifted(-now);
    }
    if (confetti != null) _confetti = confetti.shifted(-now);
    if (celebratedAt != null) _celebratedAt = now + celebratedAt;
    if (lostAt != null) _lostAt = now + lostAt;
    _end = [
      for (final motion in _motions.values) motion.end,
      ?_confetti?.end,
      ?_celebratedAt,
      ?_lostAt,
    ].fold(now, max);
    _still.bump();
    if (!_ticker.isActive) {
      _tickerStart = now;
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: _controller,
        // The confetti layer stays out of the board, which a new hold time
        // builds again: its controller attaches to one layer only.
        builder: (context, _) => OverlayPortal(
          controller: _confettiLayer,
          overlayChildBuilder: (context) => _confettiOverlay(),
          child: _viewer(constraints, animate: animate, l10n: l10n),
        ),
      ),
    );
  }

  /// The board, in a viewer that pans it when it is too big for the screen.
  Widget _viewer(
    BoxConstraints constraints, {
    required bool animate,
    required AppLocalizations l10n,
  }) {
    final state = _controller.state;
    const frame = 2 * MinesweeperBoardGeometry.frame;
    final room = Size(
      max(0, constraints.maxWidth - frame),
      max(0, constraints.maxHeight - frame),
    );
    final fitted = MinesweeperBoardGeometry.fit(
      room,
      state.columns,
      state.rows,
    );
    final pans = fitted.cell < MinesweeperBoardGeometry.minCell;
    final geometry = pans
        ? MinesweeperBoardGeometry(
            state.columns,
            state.rows,
            MinesweeperBoardGeometry.minCell,
          )
        : fitted;
    _geometry = geometry;
    final art = _artFor(geometry.cell);
    _plan(state, geometry, animate: animate);
    final board = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.theme.frame,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(MinesweeperBoardGeometry.frame),
        child: Semantics(
          key: const ValueKey('minesweeper-board'),
          label: l10n.minesweeperBoardLabel(state.columns, state.rows),
          child: RawGestureDetector(
            // The hold time is set when the recognizer is made: a new
            // time needs a new one.
            key: ValueKey(widget.flagHold),
            behavior: HitTestBehavior.opaque,
            gestures: _gestures(),
            child: SizedBox.fromSize(
              key: _boardKey,
              size: geometry.size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _StillPainter(
                          state: state,
                          geometry: geometry,
                          art: art,
                          motions: _motions,
                          hintCell: _controller.hintCell,
                          version: _still,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _MotionPainter(
                          state: state,
                          geometry: geometry,
                          art: art,
                          motions: _motions,
                          clock: _clock,
                          pressed: _pressed,
                          version: _still,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!pans) return Center(child: board);
    // Smaller cells would be hard to tap: the player pans the board, and can
    // zoom out to see all of it.
    return InteractiveViewer(
      constrained: false,
      minScale: fitted.cell / MinesweeperBoardGeometry.minCell,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(24),
      child: board,
    );
  }

  Map<Type, GestureRecognizerFactory> _gestures() => {
    TapGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (tap) => tap
            ..onTapDown = _onTapDown
            ..onTapCancel = _release
            ..onTapUp = _onTapUp
            ..onSecondaryTapUp = _onSecondaryTapUp,
        ),
    LongPressGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: widget.flagHold,
            debugOwner: this,
          ),
          (hold) => hold.onLongPressStart = _onHold,
        ),
  };

  void _onTapDown(TapDownDetails details) => _press(details.localPosition);

  void _onTapUp(TapUpDetails details) {
    _release();
    _tap(details.localPosition);
  }

  void _onSecondaryTapUp(TapUpDetails details) => _flag(details.localPosition);

  void _onHold(LongPressStartDetails details) =>
      _flag(details.localPosition, felt: true);

  MinesweeperArt _artFor(double cell) {
    final art = _art;
    if (art != null && art.cell == cell && art.theme == widget.theme) {
      return art;
    }
    art?.dispose();
    return _art = MinesweeperArt(widget.theme, cell);
  }

  /// Compares the board with the one before and plans the motions of the
  /// last action. Runs on every build, so it only plans what changed.
  void _plan(
    MinesweeperState state,
    MinesweeperBoardGeometry geometry, {
    required bool animate,
  }) {
    final previous = _previous;
    _previous = state;
    final serial = _controller.actionSerial;
    final action = serial == _seenSerial ? null : _controller.lastAction;
    _seenSerial = serial;
    final hinted = _controller.hintSerial != _seenHint;
    _seenHint = _controller.hintSerial;

    if (!animate) {
      _stopTimeline();
      _celebratedAt = null;
      _lostAt = null;
      final callback = switch (action) {
        MinesweeperAction.win => widget.onCelebrated,
        MinesweeperAction.lose => widget.onLost,
        _ => null,
      };
      if (callback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) callback();
        });
      }
      return;
    }

    final from = _controller.lastCell;
    final sameBoard =
        previous != null &&
        previous.columns == state.columns &&
        previous.rows == state.rows;
    final added = <int, CellMotion>{};
    switch (action) {
      case MinesweeperAction.deal:
        _stopTimeline();
        _celebratedAt = null;
        _lostAt = null;
        added.addAll(_dealMotions(state, from));
      case MinesweeperAction.open when sameBoard && from != null:
        added.addAll(_revealMotions(previous, state, from));
      case MinesweeperAction.flag when from != null:
        added[from] = const CellMotion(
          CellMotionKind.flag,
          start: 0,
          duration: 260,
        );
      case MinesweeperAction.unflag when from != null:
        added[from] = const CellMotion(
          CellMotionKind.unflag,
          start: 0,
          duration: 170,
        );
      case MinesweeperAction.lose when sameBoard && from != null:
        added.addAll(_revealMotions(previous, state, from));
        final lostAt = _lossMotions(state, added);
        _addMotions(added, lostAt: lostAt);
        return;
      case MinesweeperAction.win when sameBoard && from != null:
        added.addAll(_revealMotions(previous, state, from));
        _celebrate(previous, state, from, added, geometry);
        return;
      default:
        break;
    }
    if (_controller.hintCell == null) {
      // The glow of a hint lasts until the next action.
      _motions.removeWhere((_, motion) => motion.kind == CellMotionKind.hint);
    }
    if (hinted) {
      if (_controller.hintCell case final cell?) {
        added[cell] = const CellMotion(
          CellMotionKind.hint,
          start: 0,
          duration: 1800,
        );
      }
    }
    _addMotions(added);
  }

  static double _distance(MinesweeperGrid grid, int a, int b) {
    final dx = grid.xs[a] - grid.xs[b];
    final dy = grid.ys[a] - grid.ys[b];
    return sqrt(dx * dx + dy * dy);
  }

  /// Spreads [cells] from [from], one step per cell of distance, at most
  /// over [spread] ms.
  static Map<int, CellMotion> _spread(
    MinesweeperGrid grid,
    Iterable<int> cells,
    int from,
    CellMotionKind kind, {
    required double duration,
    double after = 0,
    double step = _revealStep,
    double spread = _spreadTime,
  }) {
    final far = cells.fold(
      0.0,
      (far, cell) => max(far, _distance(grid, cell, from)),
    );
    final pace = far == 0 ? 0.0 : min(step, spread / far);
    return {
      for (final cell in cells)
        cell: CellMotion(
          kind,
          start: after + _distance(grid, cell, from) * pace,
          duration: duration,
        ),
    };
  }

  /// A new board pops in from the middle (from the first tap of a board
  /// played again).
  Map<int, CellMotion> _dealMotions(MinesweeperState state, int? from) =>
      _spread(
        state.grid,
        Iterable.generate(state.length),
        from ?? state.grid.cellAt(state.columns ~/ 2, state.rows ~/ 2),
        CellMotionKind.deal,
        duration: 260,
        step: 18,
        spread: 380,
      );

  /// The cells the action opened lose their cover, spreading from the tap.
  Map<int, CellMotion> _revealMotions(
    MinesweeperState previous,
    MinesweeperState state,
    int from,
  ) => _spread(
    state.grid,
    [
      for (var cell = 0; cell < state.length; cell++)
        if (state.isOpen(cell) && !previous.isOpen(cell) && !state.isMine(cell))
          cell,
    ],
    from,
    CellMotionKind.reveal,
    duration: _revealDuration,
  );

  /// The opened mine bursts, the other mines show one after the other from
  /// it, then the wrong flags get their cross. Returns when it is over.
  double _lossMotions(MinesweeperState state, Map<int, CellMotion> added) {
    final grid = state.grid;
    final hit = state.exploded!;
    added[hit] = const CellMotion(
      CellMotionKind.exploded,
      start: 0,
      duration: 700,
    );
    final mines =
        [
          for (final cell in state.mines)
            if (cell != hit && !state.isFlagged(cell)) cell,
        ]..sort(
          (a, b) => _distance(grid, a, hit).compareTo(_distance(grid, b, hit)),
        );
    final stagger = mines.isEmpty ? 0.0 : min(70.0, 1400 / mines.length);
    for (final (i, cell) in mines.indexed) {
      added[cell] = CellMotion(
        CellMotionKind.mine,
        start: 350 + i * stagger,
        duration: 420,
      );
    }
    final crossesAt = 350 + mines.length * stagger + 120;
    for (var cell = 0; cell < state.length; cell++) {
      if (state.isFlagged(cell) && !state.isMine(cell)) {
        added[cell] = CellMotion(
          CellMotionKind.wrongFlag,
          start: crossesAt,
          duration: 300,
        );
      }
    }
    return crossesAt + 450;
  }

  /// After the last reveal, a flag pops on every mine left, then confetti
  /// bursts over the board; the win dialog comes a moment later.
  void _celebrate(
    MinesweeperState previous,
    MinesweeperState state,
    int from,
    Map<int, CellMotion> added,
    MinesweeperBoardGeometry geometry,
  ) {
    final revealed = added.values.fold(0.0, (end, m) => max(end, m.end));
    added.addAll(
      _spread(
        state.grid,
        [
          for (final cell in state.mines)
            if (!previous.isFlagged(cell)) cell,
        ],
        from,
        CellMotionKind.flag,
        duration: 260,
        after: revealed,
        step: 22,
        spread: 500,
      ),
    );
    final landed = added.values.fold(0.0, (end, m) => max(end, m.end));
    final size = geometry.size;
    _addMotions(
      added,
      confetti: Confetti(
        origins: [
          for (final (x, y) in _bursts) Offset(size.width * x, size.height * y),
        ],
        starts: [for (var i = 0; i < _bursts.length; i++) landed + i * 110],
        scale: max(0.8, geometry.cell / 32),
        seed: _controller.actionSerial,
      ),
      celebratedAt: landed + _celebration,
    );
  }

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  void _press(Offset position) {
    final cell = _geometry?.cellAt(position);
    final state = _controller.state;
    if (cell == null || state.isOver || widget.flagMode && state.hasMines) {
      return;
    }
    if (state.coverOf(cell) == Cover.hidden) _pressed.value = cell;
  }

  void _release() => _pressed.value = null;

  void _tap(Offset position) {
    final cell = _geometry?.cellAt(position);
    if (cell == null) return;
    final state = _controller.state;
    final done = widget.flagMode && state.hasMines && !state.isOpen(cell)
        ? _controller.toggleFlag(cell)
        : _controller.open(cell);
    // A flag protects its cell; a number opens its neighbors only when its
    // flags match it.
    final refused =
        state.isFlagged(cell) || state.isOpen(cell) && state.countAt(cell) > 0;
    if (!done && refused && !state.isOver && _animate) _shake(cell);
  }

  /// With [felt], the phone buzzes when the flag changes: the finger can
  /// let go.
  void _flag(Offset position, {bool felt = false}) {
    final cell = _geometry?.cellAt(position);
    if (cell != null && _controller.toggleFlag(cell) && felt) {
      unawaited(Feedback.forLongPress(context));
    }
  }

  void _shake(int cell) {
    if (_motions.containsKey(cell)) return;
    _addMotions({
      cell: const CellMotion(CellMotionKind.shake, start: 0, duration: 320),
    });
  }

  Widget _confettiOverlay() {
    final confetti = _confetti;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (confetti == null || board == null || !board.hasSize) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            willChange: true,
            painter: ConfettiPainter(
              confetti,
              _clock,
              origin: board.localToGlobal(Offset.zero),
            ),
          ),
        ),
      ),
    );
  }
}

/// How a cell at rest is drawn.
void _paintLook(
  Canvas canvas,
  MinesweeperArt art,
  Rect rect,
  _Look look,
  int count,
) {
  switch (look) {
    case _Look.covered:
      art.covered(canvas, rect);
    case _Look.flagged:
      art
        ..covered(canvas, rect)
        ..flag(canvas, rect);
    case _Look.open:
      art.open(canvas, rect);
      if (count > 0) art.number(canvas, rect, count);
    case _Look.mine:
      art
        ..open(canvas, rect)
        ..mine(canvas, rect);
    case _Look.exploded:
      art
        ..open(canvas, rect, exploded: true)
        ..mine(canvas, rect);
    case _Look.wrongFlag:
      art
        ..covered(canvas, rect)
        ..flag(canvas, rect)
        ..cross(canvas, rect);
  }
}

/// The cells at rest. It repaints when an action changes the board or when
/// cells start or stop moving, not at every frame.
class _StillPainter extends CustomPainter {
  _StillPainter({
    required this.state,
    required this.geometry,
    required this.art,
    required this.motions,
    required this.hintCell,
    required Listenable version,
  }) : super(repaint: version);

  final MinesweeperState state;
  final MinesweeperBoardGeometry geometry;
  final MinesweeperArt art;

  /// Read when painting: the cells in motion are left to [_MotionPainter].
  final Map<int, CellMotion> motions;
  final int? hintCell;

  /// The glow of a hinted cell once its pulses are over.
  static const hintRest = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    for (var cell = 0; cell < state.length; cell++) {
      if (motions.containsKey(cell)) continue;
      final rect = geometry.rectOf(cell);
      _paintLook(canvas, art, rect, _lookOf(state, cell), state.countAt(cell));
      if (cell == hintCell) art.glow(canvas, rect, hintRest);
    }
  }

  @override
  bool shouldRepaint(_StillPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.art != art ||
      oldDelegate.hintCell != hintCell ||
      oldDelegate.geometry.cell != geometry.cell;
}

/// The cells in motion at the time of the clock, and the pressed cell.
class _MotionPainter extends CustomPainter {
  _MotionPainter({
    required this.state,
    required this.geometry,
    required this.art,
    required this.motions,
    required this.clock,
    required this.pressed,
    required Listenable version,
  }) : super(repaint: Listenable.merge([clock, pressed, version]));

  final MinesweeperState state;
  final MinesweeperBoardGeometry geometry;
  final MinesweeperArt art;
  final Map<int, CellMotion> motions;
  final ValueNotifier<double> clock;
  final ValueNotifier<int?> pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final time = clock.value;
    final bursts = <(Rect, double, bool)>[];
    for (final MapEntry(key: cell, value: motion) in motions.entries) {
      final pose = motion.poseAt(time);
      final rect = geometry
          .rectOf(cell)
          .shift(Offset(pose.shake * geometry.cell, 0));
      final look = _lookOf(state, cell);
      final count = state.countAt(cell);
      // Until its cover starts to lift, a cell looks hidden.
      final lifting = pose.coverScale < 1 || pose.cover < 1;
      switch (motion.kind) {
        case CellMotionKind.deal:
          if (pose.cover <= 0) continue;
          if (look == _Look.open) {
            art.open(canvas, rect);
            if (count > 0) {
              art.number(canvas, rect, count, scale: pose.coverScale);
            }
          } else {
            art.covered(
              canvas,
              rect,
              opacity: pose.cover,
              scale: pose.coverScale,
            );
            if (look == _Look.flagged) {
              art.flag(canvas, rect, scale: pose.coverScale);
            }
          }
        case CellMotionKind.reveal:
          if (lifting) {
            art.open(canvas, rect);
            if (count > 0) art.number(canvas, rect, count, scale: pose.mark);
          }
          art.covered(
            canvas,
            rect,
            opacity: pose.cover,
            scale: pose.coverScale,
          );
        case CellMotionKind.flag || CellMotionKind.unflag:
          art
            ..covered(canvas, rect)
            ..flag(canvas, rect, scale: pose.mark);
        case CellMotionKind.mine || CellMotionKind.exploded:
          final exploded = motion.kind == CellMotionKind.exploded;
          if (lifting) {
            art
              ..open(canvas, rect, exploded: exploded)
              ..mine(canvas, rect, scale: pose.mark);
          }
          art.covered(
            canvas,
            rect,
            opacity: pose.cover,
            scale: pose.coverScale,
          );
          if (pose.burst case final burst?) bursts.add((rect, burst, exploded));
        case CellMotionKind.wrongFlag:
          art
            ..covered(canvas, rect)
            ..flag(canvas, rect)
            ..cross(canvas, rect, scale: pose.mark);
        case CellMotionKind.shake:
          _paintLook(canvas, art, rect, look, count);
        case CellMotionKind.hint:
          _paintLook(canvas, art, rect, look, count);
          art.glow(
            canvas,
            rect,
            max(pose.glow, time >= motion.end ? _StillPainter.hintRest : 0),
          );
      }
    }
    for (final (rect, progress, big) in bursts) {
      art.burst(canvas, rect, progress, big: big);
    }
    final down = pressed.value;
    if (down != null && !motions.containsKey(down)) {
      art.open(canvas, geometry.rectOf(down));
    }
  }

  @override
  bool shouldRepaint(_MotionPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.art != art ||
      oldDelegate.geometry.cell != geometry.cell;
}
