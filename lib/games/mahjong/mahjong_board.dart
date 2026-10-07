import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../../cards/confetti.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/tile_styles.dart';
import 'mahjong_controller.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_layout.dart';
import 'mahjong_motion.dart';
import 'mahjong_moving_tile.dart';
import 'mahjong_state.dart';
import 'mahjong_tile_view.dart';
import 'mahjong_tiles.dart';
import 'mahjong_tray.dart';

/// The size of the tiles and where each one goes, for a layout in a size,
/// and in tray mode the places of the tray on its side of the board.
class MahjongBoardGeometry {
  factory MahjongBoardGeometry.fit(
    Size size,
    MahjongLayout layout, {
    MahjongTraySide? tray,
  }) {
    final columns = layout.width / 2;
    final rows = layout.height / 2;
    var (width, ratio) = _fit(size, columns, rows, layout.layers);
    if (tray != null) {
      // The tray takes room from the board, so the tiles shrink a little:
      // the room they need at the first size is enough.
      final thickness = width * _trayThickness(ratio, tray);
      final room = _isSide(tray)
          ? Size(max(1.0, size.width - thickness), size.height)
          : Size(size.width, max(1.0, size.height - thickness));
      (width, ratio) = _fit(room, columns, rows, layout.layers);
    }
    return MahjongBoardGeometry._(width, width * ratio, layout, tray);
  }

  MahjongBoardGeometry._(
    this.tileWidth,
    this.tileHeight,
    MahjongLayout layout,
    MahjongTraySide? tray,
  ) : depth = tileWidth * _depthRatio,
      _layers = layout.layers {
    final board = Size(
      tileWidth * (layout.width / 2 + _depthRatio * layout.layers),
      tileHeight * layout.height / 2 + depth * layout.layers,
    );
    if (tray == null) {
      size = board;
      boardOffset = Offset.zero;
      trayRect = null;
      traySlots = const [];
      return;
    }
    final side = _isSide(tray);
    final padding = tileWidth * _trayPadding;
    final gap = tileWidth * _slotGap;
    final trayGap = tileWidth * _trayGap;
    const places = TrayState.capacity;
    final panel = side
        ? Size(
            tileWidth + depth + 2 * padding,
            places * tileHeight + (places - 1) * gap + depth + 2 * padding,
          )
        : Size(
            places * tileWidth + (places - 1) * gap + depth + 2 * padding,
            tileHeight + depth + 2 * padding,
          );
    size = side
        ? Size(
            board.width + trayGap + panel.width,
            max(board.height, panel.height),
          )
        : Size(
            max(board.width, panel.width),
            board.height + trayGap + panel.height,
          );
    // Across the tray, the board and the tray are centered on each other.
    double across(Size part) =>
        side ? (size.height - part.height) / 2 : (size.width - part.width) / 2;
    final (boardAt, panelAt) = switch (tray) {
      MahjongTraySide.top => (
        Offset(across(board), panel.height + trayGap),
        Offset(across(panel), 0),
      ),
      MahjongTraySide.bottom => (
        Offset(across(board), 0),
        Offset(across(panel), board.height + trayGap),
      ),
      MahjongTraySide.left => (
        Offset(panel.width + trayGap, across(board)),
        Offset(0, across(panel)),
      ),
      MahjongTraySide.right => (
        Offset(0, across(board)),
        Offset(board.width + trayGap, across(panel)),
      ),
    };
    boardOffset = boardAt;
    final trayAt = panelAt & panel;
    trayRect = trayAt;
    traySlots = [
      for (var i = 0; i < places; i++)
        Rect.fromLTWH(
          trayAt.left + padding + (side ? 0 : i * (tileWidth + gap)),
          trayAt.top + padding + (side ? i * (tileHeight + gap) : 0),
          tileWidth,
          tileHeight,
        ),
    ];
  }

  /// Thickness of a tile, and shift of each layer up and to the left, for a
  /// tile width of 1.
  static const _depthRatio = 0.13;

  /// Height of a tile for a width of 1: taller tiles where the room is tall.
  static const _minRatio = 1.15;
  static const _maxRatio = 1.36;
  static const _maxTileWidth = 84.0;

  /// Around the tray, for a tile width of 1: from the board, inside its
  /// frame, and between two places.
  static const _trayGap = 0.3;
  static const _trayPadding = 0.18;
  static const _slotGap = 0.2;

  final double tileWidth;
  final double tileHeight;
  final double depth;
  final int _layers;

  /// The size of the whole board, the tray included.
  late final Size size;

  /// Where the layout starts in [size], next to the tray.
  late final Offset boardOffset;

  /// The frame of the tray, and the face of a tile in each of its places
  /// (tray mode only).
  late final Rect? trayRect;
  late final List<Rect> traySlots;

  /// Room around a tile for its halo.
  double get margin => tileWidth * 0.2;

  Rect faceRect(TilePosition p) => Rect.fromLTWH(
    boardOffset.dx + p.x / 2 * tileWidth + (_layers - 1 - p.z) * depth,
    boardOffset.dy + p.y / 2 * tileHeight + (_layers - 1 - p.z) * depth,
    tileWidth,
    tileHeight,
  );

  static bool _isSide(MahjongTraySide tray) =>
      tray == MahjongTraySide.left || tray == MahjongTraySide.right;

  /// Across the places: the tray and its gap from the board, for tiles of
  /// width 1 and height [ratio].
  static double _trayThickness(double ratio, MahjongTraySide tray) =>
      (_isSide(tray) ? 1 : ratio) + _depthRatio + 2 * _trayPadding + _trayGap;

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
  /// [size] (a tall screen), with a [tray] on a side or not.
  static bool prefersTransposed(
    Size size,
    MahjongLayout layout, {
    MahjongTraySide? tray,
  }) {
    double area(MahjongLayout layout) {
      final geometry = MahjongBoardGeometry.fit(size, layout, tray: tray);
      return geometry.tileWidth * geometry.tileHeight;
    }

    return area(layout.toTransposed()) > area(layout) * 1.1;
  }
}

/// Where a tile rests: on the board, or in the tray. A [disc] of the discs
/// mode is a target too ([face] unused): it lies under the tiles of layer
/// [z], [rect] is its round.
typedef _Target = ({
  int id,
  TileFace face,
  Rect rect,
  int z,
  bool inTray,
  bool disc,
});

/// The id of disc [index] among the tile ids: below 0.
int _discId(int index) => -1 - index;

/// Everything a tile widget shows: the board keeps the widget of a tile
/// while its look stays the same.
typedef _TileLook = ({
  _Target target,
  bool leaving,
  bool selected,
  bool dimmed,
  bool faceDown,
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

/// Draws the Mahjong board, and the tray next to it in tray mode. One
/// timeline moves the tiles: each action plans a [TileMotion] for the tiles
/// it changes (a drop for a new deal, a flight for a shuffle or a pick into
/// the tray, a vanish for a match, a pop for a pair cleared in the tray),
/// and a hint makes its tiles glow for a moment.
///
/// A frame only repaints the tiles that move or glow ([MovingTile]); the
/// tile widgets are built when an action changes them, and the tile layer
/// when the paint order changes.
class MahjongBoard extends StatefulWidget {
  const MahjongBoard({
    super.key,
    required this.controller,
    this.tileStyle = classicTileStyle,
    this.traySide = MahjongTraySide.top,
    this.onCelebrated,
    this.onLost,
  });

  final MahjongController controller;
  final TileStyle tileStyle;

  /// Where the tray is in tray mode.
  final MahjongTraySide traySide;

  /// Called once after a win, when the celebration has played (at once with
  /// reduced motion): time for the win dialog.
  final VoidCallback? onCelebrated;

  /// Called once after a loss (a full tray), when the tray has flashed (at
  /// once with reduced motion): time for the loss dialog.
  final VoidCallback? onLost;

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
  static const _trayFlight = 420.0;
  static const _slideDuration = 240.0;
  static const _flashDuration = 900.0;

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

  /// A loss: when the full tray starts to flash, and when to call `onLost`.
  double? _flashStart;
  double? _lostAt;
  Map<int, _Target> _targets = const {};
  MahjongBoardGeometry? _geometry;
  int? _seenSerial;
  int? _seenHint;

  /// The hidden tiles face up at the last build, to see which turn.
  Set<int> _faceUp = const {};

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
    if (_lostAt case final at? when now >= at) {
      _lostAt = null;
      widget.onLost?.call();
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
    double? lostAt,
  }) {
    if (added.isEmpty &&
        confetti == null &&
        celebratedAt == null &&
        lostAt == null) {
      return;
    }
    final now = _now;
    for (final MapEntry(key: id, value: motion) in added.entries) {
      _motions[id] = motion.shifted(-now);
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
            tray: _controller.isTray ? widget.traySide : null,
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
                  if (geometry.trayRect case final trayRect?)
                    _TrayPanel(
                      rect: trayRect,
                      slots: geometry.traySlots,
                      filled: _controller.tray.length,
                      clock: _clock,
                      lost: _controller.isLost,
                      flashStart: _flashStart,
                    ),
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
      for (final (i, id) in _controller.tray.indexed)
        id: (
          id: id,
          face: state.faceOf(id),
          rect: geometry.traySlots[i],
          // Above every layer of the board.
          z: state.layout.layers,
          inTray: true,
          disc: false,
        ),
      for (final (i, disc) in state.discs.indexed)
        if (!state.isDiscFree(i))
          _discId(i): (
            id: _discId(i),
            face: const TileFace(0),
            rect: _discRect(disc, geometry),
            z: disc.z,
            inTray: false,
            disc: true,
          ),
    };
    final serial = _controller.actionSerial;
    final action = serial == _seenSerial ? null : _controller.lastAction;
    _seenSerial = serial;
    final hinted = _controller.hintSerial != _seenHint;
    _seenHint = _controller.hintSerial;

    final ended = action != null && _controller.result != null;
    final won = ended && _controller.result!.won;
    final lost = ended && _controller.isLost;
    if (action == MahjongAction.deal) {
      _flashStart = null;
      _lostAt = null;
    }
    if (!animate) {
      _stopTimeline();
      _motions.clear();
      _celebratedAt = null;
      _lostAt = null;
      _sortByDepth();
      if (won || lost) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          (won ? widget.onCelebrated : widget.onLost)?.call();
        });
      }
      return;
    }

    final added = <int, TileMotion>{};
    // A disc no tile lies on any more rises and fades away, after the pick.
    final tiles = {
      for (final MapEntry(:key, :value) in previous.entries)
        if (!value.disc) key: value,
    };
    if (action != MahjongAction.deal) {
      for (final target in previous.values) {
        if (!target.disc || _targets.containsKey(target.id)) continue;
        _leaving[target.id] = target;
        added[target.id] = TileMotion(
          kind: TileMotionKind.escape,
          start: 260,
          duration: 900,
          height: geometry.tileHeight * 1.6,
        );
      }
    }
    switch (action) {
      case MahjongAction.deal:
        _stopTimeline();
        _motions.clear();
        _celebratedAt = null;
        added.addAll(_dropMotions(state, geometry));
      case MahjongAction.match:
        added.addAll(_vanishMotions(tiles));
      case MahjongAction.pick:
        added.addAll(_pickMotions(tiles, geometry));
      case MahjongAction.undo || MahjongAction.shuffle:
        added.addAll(_returnMotions(previous, geometry));
      case MahjongAction.none || null:
        break;
    }
    if (hinted) {
      for (final id in _controller.hintedTiles) {
        added[id] = const TileMotion(
          kind: TileMotionKind.pulse,
          start: 0,
          duration: 1800,
        );
      }
    }
    for (final id in _turnedTiles(state)) {
      if (action != MahjongAction.deal) {
        added[id] ??= TileMotion(
          kind: TileMotionKind.turn,
          start: 0,
          duration: 240,
          height: geometry.tileHeight * 0.08,
        );
      }
    }
    _sortByDepth();
    if (won) {
      _celebrate(added, geometry);
    } else if (lost) {
      // The last tile lands in the tray, then the tray flashes.
      final landed = added.values.fold(0.0, (end, m) => max(end, m.end));
      _flashStart = _now + landed;
      _addMotions(added, lostAt: landed + _flashDuration);
    } else {
      _addMotions(added);
    }
  }

  /// The hidden tiles on the board that turned over or back since the last
  /// build.
  Set<int> _turnedTiles(MahjongState state) {
    final faceUp = {
      for (final id in state.hidden)
        if (state.positionOf(id) != null && _controller.isFaceUp(id)) id,
    };
    final turned = {
      ...faceUp.difference(_faceUp),
      for (final id in _faceUp.difference(faceUp))
        if (state.positionOf(id) != null) id,
    };
    _faceUp = faceUp;
    return turned;
  }

  _Target _target(MahjongState state, int id, MahjongBoardGeometry geometry) {
    final p = state.layout.positions[state.positionOf(id)!];
    return (
      id: id,
      face: state.faceOf(id),
      rect: geometry.faceRect(p),
      z: p.z,
      inTray: false,
      disc: false,
    );
  }

  /// A disc lies on the tile under its place, a little wider than a tile.
  Rect _discRect(TilePosition disc, MahjongBoardGeometry geometry) {
    final under = geometry.faceRect(TilePosition(disc.x, disc.y, disc.z - 1));
    final lift = geometry.depth * 0.35;
    return Rect.fromCircle(
      center: under.center - Offset(lift, lift),
      radius: geometry.tileWidth * discRadius / 2,
    );
  }

  /// Paint order on the table: layer by layer, then from the back (top
  /// left) to the front (bottom right), so the thickness of a tile hides
  /// under its neighbors.
  void _sortByDepth() {
    _byDepth = [
      for (final target in _targets.values) (target, false),
      for (final target in _leaving.values) (target, true),
    ];
    // A disc goes before the tiles of its layer, which lie on it.
    int layer(_Target target) => target.z * 2 - (target.disc ? 1 : 0);
    _byDepth.sort((a, b) {
      final (ta, _) = a;
      final (tb, _) = b;
      if (layer(ta) != layer(tb)) return layer(ta).compareTo(layer(tb));
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
    // A disc lands before the layer that lies on it.
    for (final (i, disc) in state.discs.indexed)
      _discId(i): TileMotion(
        kind: TileMotionKind.drop,
        start: (disc.z - 0.5) * _layerDelay,
        duration: _dropDuration,
        height: geometry.tileHeight * 0.9,
      ),
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

  /// Tray mode: the picked tile flies into its place in the tray, or to the
  /// tile of the tray it clears, and both pop; then the tray closes up.
  Map<int, TileMotion> _pickMotions(
    Map<int, _Target> previous,
    MahjongBoardGeometry geometry,
  ) {
    final added = <int, TileMotion>{};
    Offset poseOf(int id) => _motions[id]?.poseAt(_now).offset ?? Offset.zero;
    final gone = [
      for (final MapEntry(key: id, value: target) in previous.entries)
        if (!_targets.containsKey(id)) target,
    ];
    final picked = gone.where((target) => !target.inTray).firstOrNull;
    final partner = gone.where((target) => target.inTray).firstOrNull;
    var closesAt = 0.0;
    if (picked != null && partner != null) {
      // It lands a little up and to the right, both tiles in sight.
      final landing = partner.rect.shift(
        Offset(geometry.tileWidth * 0.22, -geometry.tileHeight * 0.12),
      );
      _leaving[picked.id] = (
        id: picked.id,
        face: picked.face,
        rect: landing,
        z: partner.z,
        inTray: true,
        disc: false,
      );
      _leaving[partner.id] = partner;
      const duration = _trayFlight / TileMotion.collectFlight;
      added[picked.id] = TileMotion(
        kind: TileMotionKind.collect,
        start: 0,
        duration: duration,
        from: picked.rect.topLeft + poseOf(picked.id) - landing.topLeft,
        height: geometry.tileHeight * 0.6,
      );
      added[partner.id] = const TileMotion(
        kind: TileMotionKind.pop,
        start: _trayFlight,
        duration: duration - _trayFlight,
      );
      closesAt = _trayFlight + (duration - _trayFlight) / 2;
    }
    for (final target in _targets.values) {
      final before = previous[target.id];
      if (before == null || before.rect == target.rect) continue;
      final from =
          before.rect.topLeft + poseOf(target.id) - target.rect.topLeft;
      added[target.id] = before.inTray
          ? TileMotion(
              kind: TileMotionKind.slide,
              start: closesAt,
              duration: _slideDuration,
              from: from,
            )
          : TileMotion(
              kind: TileMotionKind.fly,
              start: 0,
              duration: _trayFlight,
              from: from,
              height: geometry.tileHeight * 0.6,
            );
    }
    return added;
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
    final hint = _controller.hintedTiles;
    final tiles = <int, Widget>{};
    for (final (target, leaving) in _byDepth) {
      final id = target.id;
      final _TileLook look = (
        target: target,
        leaving: leaving,
        selected: !leaving && _controller.selected == id,
        dimmed: !leaving && !target.inTray && !state.isFree(id),
        // Matched tiles leave face up; the tray shows every face.
        faceDown: !leaving && !target.inTray && !_controller.isFaceUp(id),
        // The hint pulses, then stays softly lit until the next action.
        hinted: !leaving && hint.contains(id),
        motion: _motions[id],
      );
      final kept = _tileWidgets[id];
      if (kept != null && kept.$1 == look) {
        tiles[id] = kept.$2;
      } else {
        final tile = target.disc
            ? _disc(look, geometry, l10n)
            : _tile(look, geometry, l10n, animate: animate);
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
    final (:target, :leaving, :selected, :dimmed, :faceDown, :hinted, :motion) =
        look;
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
                          faceDown: faceDown,
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
                      label: faceDown
                          ? l10n.mahjongHiddenTile
                          : tileName(target.face, l10n),
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

  /// A disc: it never takes taps, and only moves.
  Widget _disc(
    _TileLook look,
    MahjongBoardGeometry geometry,
    AppLocalizations l10n,
  ) {
    final rect = look.target.rect;
    final margin = geometry.depth * 2;
    return Positioned(
      key: _TileKey(look.target.id),
      left: rect.left - margin,
      top: rect.top - margin,
      width: rect.width + 2 * margin,
      height: rect.height + 2 * margin,
      child: IgnorePointer(
        child: MovingTile(
          clock: _clock,
          motion: look.motion,
          faceRect: Offset(margin, margin) & rect.size,
          depth: geometry.depth,
          hinted: false,
          child: Semantics(
            label: l10n.mahjongDisc,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DiscPainter(depth: geometry.depth, margin: margin),
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

/// The frame of the tray and its empty places, under the tiles. Once the
/// tray is full ([lost]), it flashes red from [flashStart] on the board
/// timeline, then stays red.
class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.rect,
    required this.slots,
    required this.filled,
    required this.clock,
    required this.lost,
    required this.flashStart,
  });

  static const _flashDuration = _MahjongBoardState._flashDuration;

  final Rect rect;
  final List<Rect> slots;

  /// Places taken by a tile, from the left.
  final int filled;
  final ValueListenable<double> clock;
  final bool lost;
  final double? flashStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TrayPainter(
                  slots: [for (final slot in slots) slot.shift(-rect.topLeft)],
                  // Only a flash follows the timeline.
                  clock: lost ? clock : null,
                  flashStart: flashStart,
                  lost: lost,
                ),
              ),
            ),
          ),
          for (final (i, slot) in slots.indexed)
            Positioned.fromRect(
              rect: slot,
              child: Semantics(
                label: i < filled ? null : l10n.mahjongTrayEmptyPlace,
                child: SizedBox.expand(key: ValueKey('tray-slot-$i')),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrayPainter extends CustomPainter {
  _TrayPainter({
    required this.slots,
    required this.clock,
    required this.flashStart,
    required this.lost,
  }) : super(repaint: clock);

  static const _frame = Color(0xFF082020);
  static const _red = Color(0xFFE53935);

  final List<Rect> slots;
  final ValueListenable<double>? clock;
  final double? flashStart;
  final bool lost;

  /// How red the tray is: two flashes, then a steady glow.
  double get _red01 {
    if (!lost) return 0;
    final start = flashStart;
    final time = clock?.value;
    if (start == null || time == null) return 1;
    final t = (time - start) / _TrayPanel._flashDuration;
    if (t < 0) return 0;
    if (t >= 1) return 1;
    return (1 - cos(2 * pi * 2 * t)) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = slots.isEmpty ? 40.0 : slots.first.width;
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(unit * 0.22),
    );
    final red = _red01;
    canvas.drawRRect(
      frame,
      Paint()..color = Color.lerp(_frame, _red, red * 0.45)!,
    );
    canvas.drawRRect(
      frame.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, unit * 0.04 + red * unit * 0.04)
        ..color = Color.lerp(Colors.white24, _red, red)!,
    );
    for (final slot in slots) {
      final place = RRect.fromRectAndRadius(slot, Radius.circular(unit * 0.12));
      canvas.drawRRect(place, Paint()..color = Colors.black26);
      canvas.drawRRect(
        place,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, unit * 0.03)
          ..color = Colors.white24,
      );
    }
  }

  @override
  bool shouldRepaint(_TrayPainter old) =>
      old.lost != lost ||
      old.flashStart != flashStart ||
      old.clock != clock ||
      !listEquals(old.slots, slots);
}

/// A jade disc with a hole in its middle (a bi), lying flat: its shadow, its
/// thickness, then its top with a carved ring and grains.
class _DiscPainter extends CustomPainter {
  const _DiscPainter({required this.depth, required this.margin});

  final double depth;
  final double margin;

  static const _top = [Color(0xFF8ED8B4), Color(0xFF3E9B74), Color(0xFF1F6B4E)];
  static const _side = Color(0xFF15503A);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - margin;
    final c = size.center(Offset.zero);
    final hole = r * 0.3;
    final thick = max(1.5, depth * 0.45);
    Path ring(Offset at) => Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: at, radius: r))
      ..addOval(Rect.fromCircle(center: at, radius: hole));

    canvas.drawPath(
      ring(c + Offset(thick * 1.2, thick * 1.6)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth * 0.8 + 1),
    );
    canvas.drawPath(ring(c + Offset(thick, thick)), Paint()..color = _side);
    canvas.drawPath(
      ring(c),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: _top,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final carve = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * 0.035)
      ..color = const Color(0x99D8F5E6);
    canvas.drawCircle(c, r * 0.64, carve);
    canvas.drawCircle(c, hole, carve..color = const Color(0x8015503A));
    final grain = Paint()..color = const Color(0x66E6FFF3);
    for (final (radius, count) in [(0.47, 10), (0.82, 16)]) {
      for (var i = 0; i < count; i++) {
        final angle = 2 * pi * i / count;
        canvas.drawCircle(
          c + Offset(cos(angle), sin(angle)) * (r * radius),
          r * 0.045,
          grain,
        );
      }
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.9),
      pi * 1.05,
      pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x59FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.depth != depth || old.margin != margin;
}
