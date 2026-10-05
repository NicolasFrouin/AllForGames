import 'dart:math';

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'mahjong_controller.dart';
import 'mahjong_layout.dart';
import 'mahjong_motion.dart';
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
class _Target {
  const _Target(this.id, this.face, this.rect, this.z);

  final int id;
  final TileFace face;
  final Rect rect;
  final int z;

  /// Paint order on the table: layer by layer, then from the back (top
  /// left) to the front (bottom right), so the thickness of a tile hides
  /// under its neighbors.
  (int, double) get order => (z, rect.left + rect.top);
}

/// Draws the Mahjong board in one [Stack]. One timeline moves the tiles:
/// each action plans a [TileMotion] for the tiles it changes (a drop for a
/// new deal, a flight for a shuffle, a vanish for a match), and a hint makes
/// its tiles glow for a moment.
class MahjongBoard extends StatefulWidget {
  const MahjongBoard({super.key, required this.controller, this.onCelebrated});

  final MahjongController controller;

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
  static const _burstDuration = 1100.0;

  /// The halo of a hinted tile once its pulses are over.
  static const _hintRest = 0.4;

  late final Ticker _ticker = createTicker(_onTick);

  /// Time on the timeline, in ms. A new batch of motions restarts it at 0.
  double _now = 0;
  double _end = 0;
  final _motions = <int, TileMotion>{};

  /// Matched tiles, drawn until they have vanished.
  final _leaving = <int, _Target>{};

  /// The win celebration: when its burst starts, and when to call
  /// `onCelebrated`.
  double? _burstAt;
  double? _celebratedAt;
  Map<int, _Target> _targets = const {};
  int? _seenSerial;
  int? _seenHint;

  MahjongController get _controller => widget.controller;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    var celebrated = false;
    setState(() {
      _now = elapsed.inMicroseconds / 1000;
      if (_celebratedAt case final at? when _now >= at) {
        _celebratedAt = null;
        celebrated = true;
      }
      if (_now >= _end) _stopTimeline();
    });
    if (celebrated) widget.onCelebrated?.call();
  }

  void _stopTimeline() {
    _ticker.stop();
    _motions.clear();
    _leaving.clear();
    _burstAt = null;
  }

  /// Adds motions (and a celebration) to the timeline, with times from now.
  /// Running motions go on from where they are.
  void _addMotions(
    Map<int, TileMotion> added, {
    double? burstAt,
    double? celebratedAt,
  }) {
    if (added.isEmpty && celebratedAt == null) return;
    if (_ticker.isActive) {
      _ticker.stop();
      _motions.updateAll((_, motion) => motion.shifted(_now));
      if (_burstAt case final at?) _burstAt = at - _now;
      if (_celebratedAt case final at?) _celebratedAt = at - _now;
    }
    _now = 0;
    _motions.addAll(added);
    if (burstAt != null) _burstAt = burstAt;
    if (celebratedAt != null) _celebratedAt = celebratedAt;
    _end = [
      for (final motion in _motions.values) motion.end,
      ?_celebratedAt,
    ].fold(0.0, max);
    _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final state = _controller.state;
          final geometry = MahjongBoardGeometry.fit(
            constraints.biggest,
            state.layout,
          );
          _plan(state, geometry, animate: animate);
          return Center(
            child: SizedBox.fromSize(
              size: geometry.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._tiles(state, geometry, animate: animate),
                  if (_burstAt case final at? when _now > at)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BurstPainter(
                            ((_now - at) / _burstDuration).clamp(0.0, 1.0),
                          ),
                        ),
                      ),
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
      for (final id in state.tileIds)
        id: _target(state, id, state.positionOf(id)!, geometry),
    };
    final serial = _controller.actionSerial;
    final action = serial == _seenSerial ? null : _controller.lastAction;
    _seenSerial = serial;
    final hinted = _controller.hintSerial != _seenHint;
    _seenHint = _controller.hintSerial;

    final won = action != null && _controller.result != null;
    if (!animate) {
      _stopTimeline();
      _celebratedAt = null;
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
    if (won) {
      final landed = added.values.fold(0.0, (end, m) => max(end, m.end));
      _addMotions(
        added,
        burstAt: landed,
        celebratedAt: landed + _burstDuration + 150,
      );
    } else {
      _addMotions(added);
    }
  }

  _Target _target(
    MahjongState state,
    int id,
    int position,
    MahjongBoardGeometry geometry,
  ) {
    final p = state.layout.positions[position];
    return _Target(id, state.faceOf(id), geometry.faceRect(p), p.z);
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

  void _tap(int id, MahjongBoardGeometry geometry) {
    if (_controller.tap(id) != TileTap.blocked) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
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

  /// Tiles on the board in paint order, then the tiles in the air.
  List<Widget> _tiles(
    MahjongState state,
    MahjongBoardGeometry geometry, {
    required bool animate,
  }) {
    final entries = [
      for (final target in _targets.values) (target, false),
      for (final target in _leaving.values) (target, true),
    ];
    (int, int, double) order((_Target, bool) entry) {
      final (target, leaving) = entry;
      final airborne =
          leaving || (_motions[target.id]?.isAirborneAt(_now) ?? false);
      final (z, diagonal) = target.order;
      return (airborne ? 1 : 0, z, diagonal);
    }

    entries.sort((a, b) {
      final (ga, za, da) = order(a);
      final (gb, zb, db) = order(b);
      if (ga != gb) return ga.compareTo(gb);
      if (za != zb) return za.compareTo(zb);
      return da.compareTo(db);
    });
    final l10n = AppLocalizations.of(context);
    return [
      for (final (target, leaving) in entries)
        _tile(
          state,
          target,
          geometry,
          l10n,
          leaving: leaving,
          animate: animate,
        ),
    ];
  }

  Widget _tile(
    MahjongState state,
    _Target target,
    MahjongBoardGeometry geometry,
    AppLocalizations l10n, {
    required bool leaving,
    required bool animate,
  }) {
    final id = target.id;
    final pose = _motions[id]?.poseAt(_now);
    final selected = !leaving && _controller.selected == id;
    // The hint pulses, then stays softly lit until the next action.
    final hinted =
        !leaving &&
        switch (_controller.hintPair) {
          (final a, final b) => a == id || b == id,
          null => false,
        };
    final pulse = pose?.glow ?? 0;
    final glow = hinted ? _hintRest + (1 - _hintRest) * pulse : pulse;
    final margin = geometry.margin;
    final faceSize = Size(geometry.tileWidth, geometry.tileHeight);

    Widget child = Stack(
      children: [
        IgnorePointer(
          child: Padding(
            padding: EdgeInsets.all(margin),
            child: RepaintBoundary(
              child: MahjongTileView(
                face: target.face,
                faceSize: faceSize,
                depth: geometry.depth,
                selected: selected,
                dimmed: !leaving && !state.isFree(id),
                glow: glow,
              ),
            ),
          ),
        ),
        // Only the face takes taps: a tile's thickness lies over the tiles
        // around it.
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
              onTap: () => _tap(id, geometry),
            ),
          ),
        ),
      ],
    );
    // A tile that vanishes lets taps through to the tiles under it.
    if (leaving) child = IgnorePointer(child: child);
    child = _Lift(
      lifted: selected,
      distance: geometry.depth * 1.2,
      animate: animate,
      child: child,
    );
    if (pose != null) {
      if (pose.scale != 1) {
        child = Transform.scale(scale: pose.scale, child: child);
      }
      if (pose.opacity < 1) {
        child = Opacity(opacity: max(0, pose.opacity), child: child);
      }
    }
    final offset = pose?.offset ?? Offset.zero;
    return Positioned(
      key: ValueKey('tile-$id'),
      left: target.rect.left - margin + offset.dx,
      top: target.rect.top - margin + offset.dy,
      width: faceSize.width + geometry.depth + 2 * margin,
      height: faceSize.height + geometry.depth + 2 * margin,
      child: child,
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
      builder: (context, t, child) => t == 0
          ? child!
          : Transform.translate(
              offset: Offset(-0.5, -1) * distance * t,
              child: child,
            ),
      child: child,
    );
  }
}

/// The win: golden rings and sparks burst from the middle of the board.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.progress);

  /// From 0 to 1.
  final double progress;

  static const _sparks = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.shortestSide * 0.55;
    final fade = 1 - Curves.easeIn.transform(progress);
    for (var ring = 0; ring < 3; ring++) {
      final t = (progress - ring * 0.12).clamp(0.0, 1.0);
      if (t == 0) continue;
      canvas.drawCircle(
        center,
        reach * Curves.easeOutCubic.transform(t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = reach * 0.04 * (1 - t) + 1
          ..color = Color.fromRGBO(255, 213, 79, 0.9 * fade),
      );
    }
    final spread = Curves.easeOutCubic.transform(progress);
    for (var i = 0; i < _sparks; i++) {
      final angle = 2 * pi * i / _sparks + 0.3;
      final direction = Offset(cos(angle), sin(angle));
      final tip = center + direction * reach * (0.2 + 0.85 * spread);
      final tail = center + direction * reach * (0.1 + 0.6 * spread);
      canvas.drawLine(
        tail,
        tip,
        Paint()
          ..strokeWidth = reach * 0.025 + 1
          ..strokeCap = StrokeCap.round
          ..color =
              (i.isEven ? const Color(0xFFFFE082) : const Color(0xFFFF8A65))
                  .withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
