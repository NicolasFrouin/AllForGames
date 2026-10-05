import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../../cards/confetti.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/tile_styles.dart';
import 'mahjong_controller.dart';
import 'mahjong_layout.dart';
import 'mahjong_motion.dart';
import 'mahjong_moving_tile.dart';
import 'mahjong_state.dart';
import 'mahjong_tile_view.dart';
import 'mahjong_tiles.dart';

/// The size of the tiles and where each one goes, for a layout in a size.
class MahjongBoardGeometry {
  factory MahjongBoardGeometry.fit(Size size, MahjongLayout layout) {
    final (width, ratio) = _fit(
      size,
      layout.width / 2,
      layout.height / 2,
      layout.layers,
    );
    return MahjongBoardGeometry._(width, width * ratio, layout);
  }

  MahjongBoardGeometry._(this.tileWidth, this.tileHeight, MahjongLayout layout)
    : depth = tileWidth * _depthRatio,
      size = Size(
        tileWidth * (layout.width / 2 + _depthRatio * layout.layers),
        tileHeight * layout.height / 2 +
            tileWidth * _depthRatio * layout.layers,
      ),
      _layers = layout.layers;

  /// Thickness of a tile, and shift of each layer up and to the left, for a
  /// tile width of 1.
  static const _depthRatio = 0.13;

  /// Height of a tile for a width of 1: taller tiles where the room is tall.
  static const _minRatio = 1.15;
  static const _maxRatio = 1.36;
  static const _maxTileWidth = 84.0;

  final double tileWidth;
  final double tileHeight;
  final double depth;
  final int _layers;

  /// The size of the whole board.
  final Size size;

  /// Room around a tile for its halo.
  double get margin => tileWidth * 0.2;

  Rect faceRect(TilePosition p) => Rect.fromLTWH(
    p.x / 2 * tileWidth + (_layers - 1 - p.z) * depth,
    p.y / 2 * tileHeight + (_layers - 1 - p.z) * depth,
    tileWidth,
    tileHeight,
  );

  /// The tile width and height ratio of a layout of [columns] by [rows]
  /// tiles on [layers] in [size].
  static (double, double) _fit(
    Size size,
    double columns,
    double rows,
    int layers,
  ) {
    final extra = _depthRatio * layers;
    final byWidth = size.width / (columns + extra);
    final ratio = ((size.height / byWidth - extra) / rows).clamp(
      _minRatio,
      _maxRatio,
    );
    final width = [
      byWidth,
      size.height / (rows * ratio + extra),
      _maxTileWidth,
    ].reduce(min);
    return (max(width, 1.0), ratio);
  }

  /// Whether [layout] with rows and columns swapped has bigger tiles in
  /// [size] (a tall screen).
  static bool prefersTransposed(Size size, MahjongLayout layout) {
    double area(double columns, double rows) {
      final (width, ratio) = _fit(size, columns, rows, layout.layers);
      return width * width * ratio;
    }

    final columns = layout.width / 2;
    final rows = layout.height / 2;
    return area(rows, columns) > area(columns, rows) * 1.1;
  }
}

/// Where a tile rests on the board.
typedef _Target = ({int id, TileFace face, Rect rect, int z});

/// Everything a tile widget shows: the board keeps the widget of a tile
/// while its look stays the same.
typedef _TileLook = ({
  _Target target,
  bool leaving,
  bool selected,
  bool dimmed,
  bool hinted,
  TileMotion? motion,
});

/// The key of a tile in the paint order, apart from the `ValueKey('tile-$id')`
/// that tests find.
class _TileKey extends ValueKey<int> {
  const _TileKey(super.value);
}

/// The tiles in paint order. It changes when a tile takes off, lands or is
/// gone, not at every frame.
class _PaintOrder extends ChangeNotifier {
  List<int> ids = const [];

  void update(List<int> next) {
    if (listEquals(ids, next)) return;
    ids = next;
    notifyListeners();
  }
}

/// Draws the Mahjong board. One timeline moves the tiles: each action plans
/// a [TileMotion] for the tiles it changes (a drop for a new deal, a flight
/// for a shuffle, a vanish for a match), and a hint makes its tiles glow for
/// a moment.
///
/// A frame only repaints the tiles that move or glow ([MovingTile]); the
/// tile widgets are built when an action changes them, and the tile layer
/// when the paint order changes.
class MahjongBoard extends StatefulWidget {
  const MahjongBoard({
    super.key,
    required this.controller,
    this.tileStyle = classicTileStyle,
    this.onCelebrated,
  });

  final MahjongController controller;
  final TileStyle tileStyle;

  /// Called once after a win, when the celebration has played (at once with
  /// reduced motion): time for the win dialog.
  final VoidCallback? onCelebrated;

  @override
  State<MahjongBoard> createState() => _MahjongBoardState();
}

class _MahjongBoardState extends State<MahjongBoard>
    with SingleTickerProviderStateMixin {
  // Durations in milliseconds.
  static const _layerDelay = 170.0;
  static const _dropDuration = 300.0;
  static const _vanishDuration = 380.0;
  static const _flightDuration = 520.0;

  /// From the end of the winning match to the win dialog.
  static const _celebration = 1250.0;

  /// Where the confetti of a win bursts from, one after the other, as
  /// fractions of the board size.
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

  /// Time on the timeline, in ms. It only goes forward: motions are planned
  /// at times on it, and a frame only moves the tiles that listen to it.
  final _clock = ValueNotifier<double>(0);
  double _tickerStart = 0;
  double _end = 0;

  /// The last motion of each tile. A motion that has ended leaves its tile
  /// where it rests, so it stays until the next one.
  final _motions = <int, TileMotion>{};

  /// Matched tiles, drawn until they have vanished.
  final _leaving = <int, _Target>{};

  /// Tiles on the board (false) and leaving it (true), from the back to the
  /// front.
  List<(_Target, bool)> _byDepth = const [];
  final _paintOrder = _PaintOrder();

  /// The widget of each tile, with the look it was built for.
  final _tileWidgets = <int, (_TileLook, Widget)>{};
  AppLocalizations? _tileL10n;
  bool? _tileAnimate;
  TileStyle? _tileStyle;

  /// The win celebration: its confetti, and when to call `onCelebrated`.
  Confetti? _confetti;
  double? _celebratedAt;
  Map<int, _Target> _targets = const {};
  MahjongBoardGeometry? _geometry;
  int? _seenSerial;
  int? _seenHint;

  MahjongController get _controller => widget.controller;
  double get _now => _clock.value;

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _paintOrder.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final now = _tickerStart + elapsed.inMicroseconds / 1000;
    _clock.value = now;
    if (now >= _end) _stopTimeline();
    _paintOrder.update(_orderAt(now));
    if (_celebratedAt case final at? when now >= at) {
      _celebratedAt = null;
      widget.onCelebrated?.call();
    }
  }

  void _stopTimeline() {
    _ticker.stop();
    _confetti = null;
    if (_leaving.isNotEmpty) {
      _leaving.clear();
      _sortByDepth();
    }
  }

  /// Adds motions (and a celebration) planned from now. Running motions go
  /// on from where they are.
  void _addMotions(
    Map<int, TileMotion> added, {
    Confetti? confetti,
    double? celebratedAt,
  }) {
    if (added.isEmpty && confetti == null && celebratedAt == null) return;
    final now = _now;
    for (final MapEntry(key: id, value: motion) in added.entries) {
      _motions[id] = motion.shifted(-now);
    }
    if (confetti != null) _confetti = confetti.shifted(-now);
    if (celebratedAt != null) _celebratedAt = now + celebratedAt;
    _end = [
      for (final motion in _motions.values) motion.end,
      ?_confetti?.end,
      ?_celebratedAt,
    ].fold(now, max);
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
        builder: (context, _) {
          final state = _controller.state;
          final geometry = MahjongBoardGeometry.fit(
            constraints.biggest,
            state.layout,
          );
          _geometry = geometry;
          _plan(state, geometry, animate: animate);
          final tiles = _tiles(state, geometry, l10n, animate: animate);
          // The tile layer is built below with this order.
          _paintOrder.ids = _orderAt(_now);
          return Center(
            child: SizedBox.fromSize(
              key: _boardKey,
              size: geometry.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Changes of the paint order rebuild this layer only, with
                  // the same tile widgets.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: ListenableBuilder(
                        listenable: _paintOrder,
                        builder: (context, _) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final id in _paintOrder.ids) tiles[id]!,
                          ],
                        ),
                      ),
                    ),
                  ),
                  OverlayPortal(
                    controller: _confettiLayer,
                    overlayChildBuilder: (context) => _confettiOverlay(),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Compares the new places of the tiles with the old ones and plans the
  /// motions of the last action. Runs on every build, so it only plans what
  /// changed.
  void _plan(
    MahjongState state,
    MahjongBoardGeometry geometry, {
    required bool animate,
  }) {
    final previous = _targets;
    _targets = {
      for (final id in state.tileIds) id: _target(state, id, geometry),
    };
    final serial = _controller.actionSerial;
    final action = serial == _seenSerial ? null : _controller.lastAction;
    _seenSerial = serial;
    final hinted = _controller.hintSerial != _seenHint;
    _seenHint = _controller.hintSerial;

    final won = action != null && _controller.result != null;
    if (!animate) {
      _stopTimeline();
      _motions.clear();
      _celebratedAt = null;
      _sortByDepth();
      if (won) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCelebrated?.call();
        });
      }
      return;
    }

    final added = <int, TileMotion>{};
    switch (action) {
      case MahjongAction.deal:
        _stopTimeline();
        _motions.clear();
        _celebratedAt = null;
        added.addAll(_dropMotions(state, geometry));
      case MahjongAction.match:
        added.addAll(_vanishMotions(previous));
      case MahjongAction.undo || MahjongAction.shuffle:
        added.addAll(_returnMotions(previous, geometry));
      case MahjongAction.none || null:
        break;
    }
    if (hinted) {
      if (_controller.hintPair case (final a, final b)) {
        for (final id in [a, b]) {
          added[id] = const TileMotion(
            kind: TileMotionKind.pulse,
            start: 0,
            duration: 1800,
          );
        }
      }
    }
    _sortByDepth();
    if (won) {
      _celebrate(added, geometry);
    } else {
      _addMotions(added);
    }
  }

  _Target _target(MahjongState state, int id, MahjongBoardGeometry geometry) {
    final p = state.layout.positions[state.positionOf(id)!];
    return (id: id, face: state.faceOf(id), rect: geometry.faceRect(p), z: p.z);
  }

  /// Paint order on the table: layer by layer, then from the back (top
  /// left) to the front (bottom right), so the thickness of a tile hides
  /// under its neighbors.
  void _sortByDepth() {
    _byDepth = [
      for (final target in _targets.values) (target, false),
      for (final target in _leaving.values) (target, true),
    ];
    _byDepth.sort((a, b) {
      final (ta, _) = a;
      final (tb, _) = b;
      if (ta.z != tb.z) return ta.z.compareTo(tb.z);
      return (ta.rect.left + ta.rect.top).compareTo(tb.rect.left + tb.rect.top);
    });
  }

  /// The tiles at rest, then the tiles in the air (flying or vanishing).
  List<int> _orderAt(double time) {
    bool airborne((_Target, bool) entry) {
      final (target, leaving) = entry;
      return leaving || (_motions[target.id]?.isAirborneAt(time) ?? false);
    }

    return [
      for (final entry in _byDepth)
        if (!airborne(entry)) entry.$1.id,
      for (final entry in _byDepth)
        if (airborne(entry)) entry.$1.id,
    ];
  }

  /// A new deal falls into place layer by layer, from the table up.
  Map<int, TileMotion> _dropMotions(
    MahjongState state,
    MahjongBoardGeometry geometry,
  ) => {
    for (final id in state.tileIds)
      id: () {
        final p = state.layout.positions[state.positionOf(id)!];
        return TileMotion(
          kind: TileMotionKind.drop,
          start: p.z * _layerDelay + ((p.x + p.y) % 8) * 14,
          duration: _dropDuration,
          height: geometry.tileHeight * 0.9,
        );
      }(),
  };

  /// The matched tiles fly toward each other and fade away.
  Map<int, TileMotion> _vanishMotions(Map<int, _Target> previous) {
    final gone = [
      for (final MapEntry(key: id, value: target) in previous.entries)
        if (!_targets.containsKey(id)) target,
    ];
    if (gone.isEmpty) return const {};
    final middle =
        gone.fold(Offset.zero, (sum, target) => sum + target.rect.center) /
        gone.length.toDouble();
    return {
      for (final target in gone)
        target.id: () {
          _leaving[target.id] = target;
          final from = _motions[target.id]?.poseAt(_now).offset ?? Offset.zero;
          return TileMotion(
            kind: TileMotionKind.vanish,
            start: 0,
            duration: _vanishDuration,
            from: from,
            to: (middle - target.rect.center) * 0.7,
          );
        }(),
    };
  }

  /// After an undo or a shuffle: tiles fly to their new places, and
  /// matched tiles that come back appear.
  Map<int, TileMotion> _returnMotions(
    Map<int, _Target> previous,
    MahjongBoardGeometry geometry,
  ) {
    final added = <int, TileMotion>{};
    final moved = [
      for (final target in _targets.values)
        if (previous[target.id] case final before?
            when before.rect != target.rect)
          (target, before),
    ];
    final stagger = moved.isEmpty ? 0.0 : min(6.0, 360 / moved.length);
    for (final (i, (target, before)) in moved.indexed) {
      final pose = _motions[target.id]?.poseAt(_now).offset ?? Offset.zero;
      added[target.id] = TileMotion(
        kind: TileMotionKind.fly,
        start: i * stagger,
        duration: _flightDuration,
        from: before.rect.topLeft + pose - target.rect.topLeft,
        height: geometry.tileHeight * 0.5,
      );
    }
    for (final id in _targets.keys) {
      if (!previous.containsKey(id)) {
        _leaving.remove(id);
        added[id] = const TileMotion(
          kind: TileMotionKind.appear,
          start: 0,
          duration: 260,
        );
      }
    }
    return added;
  }

  /// After the last pair has vanished, confetti bursts from a few points of
  /// the cleared board; the win dialog comes a moment later.
  void _celebrate(Map<int, TileMotion> added, MahjongBoardGeometry geometry) {
    final landed = added.values.fold(0.0, (end, m) => max(end, m.end));
    final size = geometry.size;
    _addMotions(
      added,
      confetti: Confetti(
        origins: [
          for (final (x, y) in _bursts) Offset(size.width * x, size.height * y),
        ],
        starts: [for (var i = 0; i < _bursts.length; i++) landed + i * 110],
        scale: geometry.tileWidth / 64,
        seed: _controller.actionSerial,
      ),
      celebratedAt: landed + _celebration,
    );
  }

  void _tap(int id) {
    if (_controller.tap(id) != TileTap.blocked) return;
    final geometry = _geometry;
    if (geometry == null || MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      _addMotions({
        id: TileMotion(
          kind: TileMotionKind.shake,
          start: 0,
          duration: 320,
          height: geometry.tileWidth * 0.08,
        ),
      });
    });
  }

  /// The widget of each tile on the board or leaving it. A tile keeps its
  /// widget while it looks the same, so an action only rebuilds the tiles it
  /// changes.
  Map<int, Widget> _tiles(
    MahjongState state,
    MahjongBoardGeometry geometry,
    AppLocalizations l10n, {
    required bool animate,
  }) {
    if (l10n != _tileL10n ||
        animate != _tileAnimate ||
        widget.tileStyle != _tileStyle) {
      _tileWidgets.clear();
      _tileL10n = l10n;
      _tileAnimate = animate;
      _tileStyle = widget.tileStyle;
    }
    final hint = _controller.hintPair;
    final tiles = <int, Widget>{};
    for (final (target, leaving) in _byDepth) {
      final id = target.id;
      final _TileLook look = (
        target: target,
        leaving: leaving,
        selected: !leaving && _controller.selected == id,
        dimmed: !leaving && !state.isFree(id),
        // The hint pulses, then stays softly lit until the next action.
        hinted: !leaving && hint != null && (hint.$1 == id || hint.$2 == id),
        motion: _motions[id],
      );
      final kept = _tileWidgets[id];
      if (kept != null && kept.$1 == look) {
        tiles[id] = kept.$2;
      } else {
        final tile = _tile(look, geometry, l10n, animate: animate);
        _tileWidgets[id] = (look, tile);
        tiles[id] = tile;
      }
    }
    _tileWidgets.removeWhere((id, _) => !tiles.containsKey(id));
    return tiles;
  }

  /// Built once per change of the tile: a frame only moves it and lights it
  /// ([MovingTile]).
  Widget _tile(
    _TileLook look,
    MahjongBoardGeometry geometry,
    AppLocalizations l10n, {
    required bool animate,
  }) {
    final (:target, :leaving, :selected, :dimmed, :hinted, :motion) = look;
    final id = target.id;
    final margin = geometry.margin;
    final faceSize = Size(geometry.tileWidth, geometry.tileHeight);
    return Positioned(
      key: _TileKey(id),
      left: target.rect.left - margin,
      top: target.rect.top - margin,
      width: faceSize.width + geometry.depth + 2 * margin,
      height: faceSize.height + geometry.depth + 2 * margin,
      child: _Lift(
        lifted: selected,
        distance: geometry.depth * 1.2,
        animate: animate,
        child: MovingTile(
          clock: _clock,
          motion: motion,
          faceRect: Offset(margin, margin) & faceSize,
          depth: geometry.depth,
          hinted: hinted,
          child: KeyedSubtree(
            key: ValueKey('tile-$id'),
            // A tile that vanishes lets taps through to the tiles under it.
            child: IgnorePointer(
              ignoring: leaving,
              child: Stack(
                children: [
                  IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.all(margin),
                      child: RepaintBoundary(
                        child: MahjongTileView(
                          face: target.face,
                          faceSize: faceSize,
                          depth: geometry.depth,
                          style: widget.tileStyle,
                          selected: selected,
                          dimmed: dimmed,
                        ),
                      ),
                    ),
                  ),
                  // Only the face takes taps: a tile's thickness lies over
                  // the tiles around it.
                  Positioned(
                    left: margin,
                    top: margin,
                    width: faceSize.width,
                    height: faceSize.height,
                    child: Semantics(
                      label: tileName(target.face, l10n),
                      button: true,
                      selected: selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tap(id),
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

/// A selected tile rises a little toward the top left.
class _Lift extends StatelessWidget {
  const _Lift({
    required this.lifted,
    required this.distance,
    required this.animate,
    required this.child,
  });

  final bool lifted;
  final double distance;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: lifted ? 1 : 0),
      duration: Duration(milliseconds: animate ? 140 : 0),
      curve: Curves.easeOutCubic,
      // Always a translation (none at rest), so the tile below keeps its
      // widgets when it rises.
      builder: (context, t, child) => Transform.translate(
        offset: Offset(-0.5, -1) * distance * t,
        child: child,
      ),
      child: child,
    );
  }
}
