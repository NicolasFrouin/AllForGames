import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'mahjong_motion.dart';
import 'mahjong_tile_view.dart';

/// Moves a tile of the board along [motion] at the time of [clock] (offset,
/// scale, opacity), and paints the glow of a hint around it.
///
/// A tick only repaints this tile (a repaint boundary): no widget rebuilds,
/// and the tile art keeps its own layer when it sits in a [RepaintBoundary].
/// Hit tests follow the tile where it is drawn.
class MovingTile extends SingleChildRenderObjectWidget {
  const MovingTile({
    super.key,
    required this.clock,
    required this.motion,
    required this.faceRect,
    required this.depth,
    this.hinted = false,
    super.child,
  });

  /// The board timeline, in milliseconds.
  final ValueListenable<double> clock;

  /// Null for a tile at rest.
  final TileMotion? motion;

  /// Where the face of the tile is in this box: a hint glows around it.
  final Rect faceRect;
  final double depth;

  /// Shown by the last hint: once its pulses are over, the tile stays softly
  /// lit.
  final bool hinted;

  @override
  RenderMovingTile createRenderObject(BuildContext context) =>
      RenderMovingTile(clock, motion, faceRect, depth, hinted);

  @override
  void updateRenderObject(BuildContext context, RenderMovingTile renderObject) {
    renderObject
      ..clock = clock
      ..motion = motion
      ..faceRect = faceRect
      ..depth = depth
      ..hinted = hinted;
  }
}

class RenderMovingTile extends RenderProxyBox {
  RenderMovingTile(
    this._clock,
    this._motion,
    this._faceRect,
    this._depth,
    this._hinted,
  );

  /// The glow of a hinted tile once its pulses are over.
  static const hintRest = 0.4;

  final _opacityLayer = LayerHandle<OpacityLayer>();
  final _transformLayer = LayerHandle<TransformLayer>();
  bool _listening = false;
  TilePose _pose = const TilePose();
  Matrix4? _transform;

  ValueListenable<double> _clock;
  set clock(ValueListenable<double> value) {
    if (value == _clock) return;
    if (_listening) {
      _clock.removeListener(_update);
      _listening = false;
    }
    _clock = value;
    _update();
  }

  TileMotion? _motion;
  set motion(TileMotion? value) {
    if (identical(value, _motion)) return;
    _motion = value;
    _update();
  }

  Rect _faceRect;
  set faceRect(Rect value) {
    if (value == _faceRect) return;
    _faceRect = value;
    markNeedsPaint();
  }

  double _depth;
  set depth(double value) {
    if (value == _depth) return;
    _depth = value;
    markNeedsPaint();
  }

  bool _hinted;
  set hinted(bool value) {
    if (value == _hinted) return;
    _hinted = value;
    markNeedsPaint();
  }

  /// The hint glow as painted now, from 0 to 1.
  double get glow =>
      _hinted ? hintRest + (1 - hintRest) * _pose.glow : _pose.glow;

  /// The opacity of the tile as painted now.
  double get opacity => _pose.opacity;

  bool get _moved => _pose.offset != Offset.zero || _pose.scale != 1;

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _update();
  }

  @override
  void detach() {
    super.detach();
    _syncListener();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  /// Only a tile whose motion has not ended follows the clock: the clock
  /// only goes forward.
  void _syncListener() {
    final motion = _motion;
    final listen = attached && motion != null && _clock.value < motion.end;
    if (listen == _listening) return;
    _listening = listen;
    if (listen) {
      _clock.addListener(_update);
    } else {
      _clock.removeListener(_update);
    }
  }

  void _update() {
    _syncListener();
    final pose = _motion?.poseAt(_clock.value) ?? const TilePose();
    if (pose.offset == _pose.offset &&
        pose.scale == _pose.scale &&
        pose.opacity == _pose.opacity &&
        pose.glow == _pose.glow) {
      return;
    }
    _pose = pose;
    _transform = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    super.performLayout();
    _transform = null;
  }

  /// The offset of the pose, and its scale around the middle of the tile.
  Matrix4 _transformOf(TilePose pose) {
    final center = size.center(Offset.zero);
    return Matrix4.translationValues(
        pose.offset.dx + center.dx,
        pose.offset.dy + center.dy,
        0,
      )
      ..scaleByDouble(pose.scale, pose.scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final alpha = Color.getAlphaFromOpacity(_pose.opacity.clamp(0.0, 1.0));
    if (alpha == 0) {
      _opacityLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    if (alpha == 255) {
      _opacityLayer.layer = null;
      _paintMoved(context, offset);
      return;
    }
    _opacityLayer.layer = context.pushOpacity(
      offset,
      alpha,
      _paintMoved,
      oldLayer: _opacityLayer.layer,
    );
  }

  void _paintMoved(PaintingContext context, Offset offset) {
    if (_pose.scale == 1) {
      _transformLayer.layer = null;
      _paintTile(context, offset + _pose.offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform ??= _transformOf(_pose),
      _paintTile,
      oldLayer: _transformLayer.layer,
    );
  }

  void _paintTile(PaintingContext context, Offset offset) {
    final glow = this.glow;
    // Fainter than this, every part of the glow rounds to transparent.
    final lit = glow * 255 >= 0.5;
    final face = _faceRect.shift(offset);
    if (lit) paintHintHalo(context.canvas, face, _depth, glow);
    context.paintChild(child!, offset);
    if (lit) paintHintRim(context.canvas, face, glow);
  }

  // A moving tile may be drawn outside its layout box: the child tests the
  // position, through the transform.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      hitTestChildren(result, position: position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_moved) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: _transform ??= _transformOf(_pose),
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_moved) transform.multiply(_transform ??= _transformOf(_pose));
  }

  // Like an [Opacity] of 0: a tile that waits for its drop is not read out.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_pose.opacity > 0) super.visitChildrenForSemantics(visitor);
  }
}
