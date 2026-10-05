import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../skins/card_backs.dart';
import 'card_motion.dart';
import 'card_view.dart';
import 'playing_card.dart';

/// Moves its child, a card laid out at [rest], along [motion] at the time of
/// [clock]: lifted, turned or tilted, with a shadow under it in the air.
///
/// A tick only repaints this card (a repaint boundary): no widget rebuilds,
/// and the card content keeps its own layer when the child is a
/// [RepaintBoundary]. Hit tests follow the card where it is drawn.
class MovingCard extends SingleChildRenderObjectWidget {
  const MovingCard({
    super.key,
    required this.clock,
    required this.motion,
    required this.rest,
    super.child,
  });

  /// The table timeline, in milliseconds.
  final ValueListenable<double> clock;

  /// Null for a card at rest.
  final CardMotion? motion;

  /// Where the parent lays out the card, from the same origin as the
  /// positions of [motion].
  final Offset rest;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMovingCard(clock, motion, rest);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMovingCard)
      ..clock = clock
      ..motion = motion
      ..rest = rest;
  }
}

class _RenderMovingCard extends RenderProxyBox {
  _RenderMovingCard(this._clock, this._motion, this._rest);

  /// One blur that never changes, so the shadow stays cheap: only its
  /// offset and opacity follow the height of the card.
  static final _shadowBlur = MaskFilter.blur(
    BlurStyle.normal,
    Shadow.convertRadiusToSigma(12),
  );

  final _shadowPaint = Paint()..maskFilter = _shadowBlur;
  final _transformLayer = LayerHandle<TransformLayer>();
  bool _listening = false;

  /// Null at rest.
  CardPose? _pose;
  Matrix4? _transform;

  ValueListenable<double> _clock;
  set clock(ValueListenable<double> value) {
    if (value == _clock) return;
    if (_listening) {
      _clock.removeListener(_update);
      value.addListener(_update);
    }
    _clock = value;
    _update();
  }

  CardMotion? _motion;
  set motion(CardMotion? value) {
    if (identical(value, _motion)) return;
    _motion = value;
    _syncListener();
    _update();
  }

  Offset _rest;
  set rest(Offset value) {
    if (value == _rest) return;
    _rest = value;
    _transform = null;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncListener();
    _update();
  }

  @override
  void detach() {
    super.detach();
    _syncListener();
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  /// Only a card with a motion follows the clock.
  void _syncListener() {
    final listen = attached && _motion != null;
    if (listen == _listening) return;
    _listening = listen;
    if (listen) {
      _clock.addListener(_update);
    } else {
      _clock.removeListener(_update);
    }
  }

  void _update() {
    final pose = _motion?.poseAt(_clock.value);
    if (pose == _pose) return;
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

  Matrix4 _transformOf(CardPose pose) {
    final shift = pose.position - _rest;
    if (pose.scale == 1 && pose.rotation == 0 && pose.flipAngle == 0) {
      return Matrix4.translationValues(shift.dx, shift.dy, 0);
    }
    final center = size.center(Offset.zero);
    final turn = Matrix4.identity()
      // Perspective, so a flip looks like a card turning over.
      ..setEntry(3, 2, 0.0012)
      ..rotateY(pose.flipAngle)
      ..rotateZ(pose.rotation)
      ..scaleByDouble(pose.scale, pose.scale, 1, 1);
    return Matrix4.translationValues(
        shift.dx + center.dx,
        shift.dy + center.dy,
        0,
      )
      ..multiply(turn)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final pose = _pose;
    if (child == null) return;
    if (pose == null) {
      _transformLayer.layer = null;
      context.paintChild(child!, offset);
      return;
    }
    final transform = _transform ??= _transformOf(pose);
    if (MatrixUtils.getAsTranslation(transform) case final shift?) {
      _transformLayer.layer = null;
      _paintCard(context, offset + shift, pose.elevation);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => _paintCard(context, offset, pose.elevation),
      oldLayer: _transformLayer.layer,
    );
  }

  void _paintCard(PaintingContext context, Offset offset, double elevation) {
    if (elevation > 0) {
      _shadowPaint.color = Color.fromRGBO(0, 0, 0, 0.35 * elevation);
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          offset.translate(0, 2 + 10 * elevation) & size,
          Radius.circular(size.width * 0.1),
        ),
        _shadowPaint,
      );
    }
    context.paintChild(child!, offset);
  }

  // A moving card may be drawn outside its layout box: the child tests the
  // position, through the transform.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      hitTestChildren(result, position: position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final pose = _pose;
    if (pose == null) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: _transform ??= _transformOf(pose),
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_pose case final pose?) {
      transform.multiply(_transform ??= _transformOf(pose));
    }
  }
}

/// A [CardView] that shows the face of [motion] at the time of [clock]. It
/// rebuilds once, at the middle of a flip, and never for a motion without one.
class TurningCardView extends StatefulWidget {
  const TurningCardView({
    super.key,
    required this.card,
    required this.motion,
    required this.clock,
    required this.width,
    required this.cardBack,
  });

  /// The card with the face it has at the end of [motion].
  final PlayingCard card;
  final CardMotion? motion;
  final ValueListenable<double> clock;
  final double width;
  final CardBackSkin cardBack;

  @override
  State<TurningCardView> createState() => _TurningCardViewState();
}

class _TurningCardViewState extends State<TurningCardView> {
  late bool _faceUp;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _faceUp = _faceNow();
    _syncListener();
  }

  @override
  void didUpdateWidget(TurningCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listening && oldWidget.clock != widget.clock) {
      oldWidget.clock.removeListener(_onTick);
      _listening = false;
    }
    _syncListener();
    _faceUp = _faceNow();
  }

  @override
  void dispose() {
    if (_listening) widget.clock.removeListener(_onTick);
    super.dispose();
  }

  void _syncListener() {
    final listen = widget.motion?.flips ?? false;
    if (listen == _listening) return;
    _listening = listen;
    if (listen) {
      widget.clock.addListener(_onTick);
    } else {
      widget.clock.removeListener(_onTick);
    }
  }

  bool _faceNow() =>
      widget.motion?.faceAt(widget.clock.value) ?? widget.card.faceUp;

  void _onTick() {
    final faceUp = _faceNow();
    if (faceUp != _faceUp) setState(() => _faceUp = faceUp);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return CardView(
      card: card.faceUp == _faceUp ? card : card.turned(faceUp: _faceUp),
      width: widget.width,
      cardBack: widget.cardBack,
    );
  }
}
