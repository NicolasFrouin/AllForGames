import 'dart:math';

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'card_motion.dart';
import 'card_view.dart';
import 'confetti.dart';
import 'klondike_controller.dart';
import 'klondike_state.dart';
import 'playing_card.dart';
import 'suit_icon.dart';

const _allPiles = [
  PileRef.stock,
  PileRef.waste,
  PileRef.foundation(0),
  PileRef.foundation(1),
  PileRef.foundation(2),
  PileRef.foundation(3),
  PileRef.tableau(0),
  PileRef.tableau(1),
  PileRef.tableau(2),
  PileRef.tableau(3),
  PileRef.tableau(4),
  PileRef.tableau(5),
  PileRef.tableau(6),
];

/// Draws the whole Klondike table in one [Stack]. One timeline moves the
/// cards: each action plans a [CardMotion] for every card it changes (flights
/// on an arc, flips, a deal from the stock, a shake), so moves look fluid and
/// can follow each other without jumps.
class KlondikeBoard extends StatefulWidget {
  const KlondikeBoard({
    super.key,
    required this.controller,
    required this.cardBack,
    this.onCelebrated,
  });

  final KlondikeController controller;

  /// The look of the face-down cards.
  final CardBackSkin cardBack;

  /// Called once after a win, when the celebration has played (at once with
  /// reduced motion): time for the win dialog.
  final VoidCallback? onCelebrated;

  @override
  State<KlondikeBoard> createState() => _KlondikeBoardState();
}

class _DragData {
  _DragData(this.from, Iterable<PlayingCard> cards, this.relativeOffsets)
    : cardIds = [for (final card in cards) card.id];

  final PileRef from;
  final List<String> cardIds;

  /// Where each card is drawn in the drag feedback, from the first one.
  final List<Offset> relativeOffsets;

  int get count => cardIds.length;

  /// False when the pile changed during the drag (for example a second finger
  /// made another move): the drag must then do nothing.
  bool matches(KlondikeState state) {
    final pile = state.pile(from);
    if (pile.length < count) return false;
    for (var i = 0; i < count; i++) {
      if (pile[pile.length - count + i].id != cardIds[i]) return false;
    }
    return true;
  }
}

/// Where a card rests after the last action.
class _Target {
  const _Target(this.card, this.pile, this.index, this.offset);

  final PlayingCard card;
  final PileRef pile;
  final int index;
  final Offset offset;

  /// Paint order on the table: the pile, then the place in the pile.
  int get z => _allPiles.indexOf(pile) * 100 + index;
}

class _KlondikeBoardState extends State<KlondikeBoard>
    with SingleTickerProviderStateMixin {
  // Durations in milliseconds.
  static const _dealStagger = 32.0;
  static const _dealFlight = 280.0;
  static const _cascadeStagger = 45.0;
  static const _cascadeFlight = 300.0;
  static const _drawStagger = 70.0;
  static const _stackStagger = 28.0;
  static const _flip = 240.0;

  late final Ticker _ticker = createTicker(_onTick);
  final _stackKey = GlobalKey();

  /// Confetti is drawn on the page overlay, above the app bar.
  final _confettiLayer = OverlayPortalController()..show();

  /// Time on the timeline, in ms. A new batch of motions restarts it at 0.
  double _now = 0;
  double _end = 0;
  final _motions = <String, CardMotion>{};

  /// Paint order of a card that waits before its motion: its old pile.
  final _waitZ = <String, int>{};

  /// The win celebration: its confetti, and when to call `onCelebrated`.
  Confetti? _confetti;
  double? _celebratedAt;
  Map<String, _Target> _targets = const {};
  int? _seenSerial;

  /// Top-left corners of dropped cards, so they glide from where the player
  /// let them go.
  Map<String, Offset>? _dropStarts;
  _DragData? _dragging;

  KlondikeController get _controller => widget.controller;

  bool get _isDragging => _dragging?.matches(_controller.state) ?? false;

  /// Board taps wait for the end of a drag, so the dragged cards stay on top.
  void _unlessDragging(VoidCallback action) {
    if (!_isDragging) action();
  }

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
    _waitZ.clear();
    _confetti = null;
  }

  /// Adds motions (and a celebration) to the timeline, with times from now.
  /// Running motions go on from where they are.
  void _addMotions(
    Map<String, CardMotion> added, {
    Confetti? confetti,
    double? celebratedAt,
  }) {
    if (added.isEmpty && confetti == null) return;
    if (_ticker.isActive) {
      _ticker.stop();
      _motions.updateAll((_, motion) => motion.shifted(_now));
      _confetti = _confetti?.shifted(_now);
      if (_celebratedAt case final at?) _celebratedAt = at - _now;
    }
    _now = 0;
    _motions.addAll(added);
    if (confetti != null) _confetti = confetti;
    if (celebratedAt != null) _celebratedAt = celebratedAt;
    _end = [
      for (final motion in _motions.values) motion.end,
      ?_confetti?.end,
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
          final layout = _BoardLayout(constraints.biggest, state.drawCount);
          final pileOffsets = {
            for (final ref in _allPiles)
              ref: layout.offsets(ref, state.pile(ref)),
          };
          _plan(state, layout, pileOffsets, animate: animate);
          return Center(
            child: SizedBox(
              key: _stackKey,
              width: layout.boardWidth,
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._slots(state, layout),
                  ..._cards(state, layout, pileOffsets),
                  ..._dropTargets(layout),
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

  /// Compares the new places of the cards with the old ones and plans the
  /// motions of the last action. Runs on every build, so it only plans what
  /// changed.
  void _plan(
    KlondikeState state,
    _BoardLayout layout,
    Map<PileRef, List<Offset>> pileOffsets, {
    required bool animate,
  }) {
    final previous = _targets;
    _targets = {
      for (final ref in _allPiles)
        for (final (index, card) in state.pile(ref).indexed)
          card.id: _Target(card, ref, index, pileOffsets[ref]![index]),
    };
    final serial = _controller.actionSerial;
    final action = serial == _seenSerial ? null : _controller.lastAction;
    _seenSerial = serial;
    final dropStarts = action == null ? null : _dropStarts;
    if (action != null) _dropStarts = null;

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
    if (action == KlondikeAction.deal) {
      _stopTimeline();
      _celebratedAt = null;
      _addMotions(_dealMotions(state, layout));
      return;
    }
    // A game that continues shows up as it is.
    if (previous.isEmpty) return;

    final moved = action == null
        ? const <String>[]
        : _controller.lastMovedCardIds.toList();
    final added = <String, CardMotion>{};
    for (final MapEntry(key: id, value: target) in _targets.entries) {
      final before = previous[id];
      if (before == null) continue;
      final moves = before.offset != target.offset;
      final flips = before.card.faceUp != target.card.faceUp;
      if (!moves && !flips) continue;
      final pose = _motions[id]?.poseAt(_now);
      final from = dropStarts?[id] ?? pose?.position ?? before.offset;
      final faceFrom = pose?.faceUp ?? before.card.faceUp;
      final order = moved.indexOf(id);
      final motion = _motionFor(
        action,
        layout,
        from: from,
        to: target.offset,
        faceFrom: faceFrom,
        faceTo: target.card.faceUp,
        order: max(0, order),
        orderCount: moved.length,
        dropped: dropStarts?.containsKey(id) ?? false,
      );
      if (motion.start > 0) _waitZ[id] = before.z;
      added[id] = motion;
    }
    if (won) {
      _celebrate(added, layout);
    } else {
      _addMotions(added);
    }
  }

  /// After the last card lands, the four kings hop one after the other, each
  /// with a burst of confetti from its foundation.
  void _celebrate(Map<String, CardMotion> added, _BoardLayout layout) {
    const hop = 620.0;
    final landed = added.values.fold(
      0.0,
      (end, motion) => max(end, motion.end),
    );
    final starts = <double>[];
    for (var i = 0; i < 4; i++) {
      final king = _targets[_controller.state.foundations[i].last.id]!;
      final start = landed + 120 + i * 110;
      starts.add(start);
      final jump = CardMotion(
        kind: CardMotionKind.hop,
        from: king.offset,
        to: king.offset,
        start: start,
        duration: hop,
        // Low enough to stay below the app bar.
        height: layout.cardHeight * 0.3,
        faceFrom: true,
        faceTo: true,
      );
      added[king.card.id] =
          added[king.card.id]?.followedBy(jump) ??
          CardMotion(
            kind: CardMotionKind.fly,
            from: king.offset,
            to: king.offset,
            start: 0,
            duration: 0,
            faceFrom: true,
            faceTo: true,
            next: jump,
          );
    }
    _addMotions(
      added,
      confetti: Confetti(
        origins: [
          for (var i = 0; i < 4; i++)
            layout.slotRect(PileRef.foundation(i)).center,
        ],
        starts: starts,
        scale: layout.cardWidth / 80,
        seed: _controller.seed,
      ),
      celebratedAt: starts.last + hop + 450,
    );
  }

  CardMotion _motionFor(
    KlondikeAction? action,
    _BoardLayout layout, {
    required Offset from,
    required Offset to,
    required bool faceFrom,
    required bool faceTo,
    required int order,
    required int orderCount,
    required bool dropped,
  }) {
    final distance = (to - from).distance;
    final long = distance > layout.cardHeight * 0.6;
    final arc = long ? min(distance * 0.14, layout.cardHeight * 0.4) : 0.0;
    final (start, duration, curve) = switch (action) {
      // Window resize or a pile that spreads: a quick glide.
      null => (0.0, 220.0, Curves.easeOutCubic),
      _ when dropped => (0.0, 160.0, Curves.easeOutCubic),
      KlondikeAction.autoComplete => (
        order * _cascadeStagger,
        _cascadeFlight,
        Curves.easeInOutCubic,
      ),
      KlondikeAction.draw => (order * _drawStagger, 280.0, Curves.easeOutCubic),
      // The whole waste turns back over, like a riffle.
      KlondikeAction.recycle => (
        (orderCount - 1 - order) * 6.0,
        260.0,
        Curves.easeInOutCubic,
      ),
      _ => (
        order * _stackStagger,
        (170 + distance * 0.5).clamp(200.0, 420.0),
        long ? Curves.easeInOutCubic : Curves.easeOutCubic,
      ),
    };
    final moving = distance > 0;
    return CardMotion(
      kind: CardMotionKind.fly,
      from: from,
      to: to,
      start: moving ? start : 0,
      duration: moving ? duration : 0,
      height: dropped ? 0 : arc,
      curve: curve,
      faceFrom: faceFrom,
      faceTo: faceTo,
      // A card that turns in place waits until the card above lifts off.
      flipStart: moving ? start : 110,
      flipDuration: moving ? max(duration, _flip) : _flip,
    );
  }

  /// Cards fly from the stock to the columns one by one, row by row like a
  /// real deal, and turn over when they land.
  Map<String, CardMotion> _dealMotions(
    KlondikeState state,
    _BoardLayout layout,
  ) {
    final stock = layout.slot(PileRef.stock);
    final motions = <String, CardMotion>{};
    final rows = state.tableau.fold(0, (rows, pile) => max(rows, pile.length));
    var dealt = 0;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < 7; column++) {
        final card = state.tableau[column].elementAtOrNull(row);
        if (card == null) continue;
        final start = dealt++ * _dealStagger;
        final distance = (_targets[card.id]!.offset - stock).distance;
        motions[card.id] = CardMotion(
          kind: CardMotionKind.fly,
          from: stock,
          to: _targets[card.id]!.offset,
          start: start,
          duration: _dealFlight,
          height: min(distance * 0.1, layout.cardHeight * 0.3),
          faceFrom: false,
          faceTo: card.faceUp,
          flipStart: start + _dealFlight,
          flipDuration: _flip,
        );
        // Waiting cards sit on top of the stock.
        _waitZ[card.id] = 50 + dealt;
      }
    }
    return motions;
  }

  /// A tap with no legal move: the cards shake their head.
  void _shake(Iterable<PlayingCard> cards, _BoardLayout layout) {
    setState(() {
      _addMotions({
        for (final card in cards)
          card.id: CardMotion(
            kind: CardMotionKind.shake,
            from: _targets[card.id]!.offset,
            to: _targets[card.id]!.offset,
            start: 0,
            duration: 380,
            height: layout.cardWidth * 0.07,
            faceFrom: card.faceUp,
            faceTo: card.faceUp,
          ),
      });
    });
  }

  /// Dropped where they cannot go: the cards fly back to their pile.
  void _snapBack(_DragData data, Offset globalTopLeft) {
    if (!data.matches(_controller.state)) return;
    final topLeft = _toLocal(globalTopLeft);
    setState(() {
      _addMotions({
        for (final (i, id) in data.cardIds.indexed)
          if (_targets[id] case final target?)
            id: CardMotion(
              kind: CardMotionKind.fly,
              from: topLeft + data.relativeOffsets[i],
              to: target.offset,
              start: i * 18.0,
              duration: 320,
              curve: Curves.easeOutBack,
              faceFrom: target.card.faceUp,
              faceTo: target.card.faceUp,
            ),
      });
    });
  }

  Widget _confettiOverlay() {
    final confetti = _confetti;
    final board = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (confetti == null || board == null || !board.hasSize) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ConfettiPainter(
            confetti,
            _now,
            origin: board.localToGlobal(Offset.zero),
          ),
        ),
      ),
    );
  }

  Offset _toLocal(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  Iterable<Widget> _slots(KlondikeState state, _BoardLayout layout) sync* {
    yield _Slot(
      key: const ValueKey('stock'),
      offset: layout.slot(PileRef.stock),
      layout: layout,
      onTap: () => _unlessDragging(_controller.draw),
      child: Icon(
        state.waste.isEmpty ? Icons.block : Icons.refresh,
        color: Colors.white54,
        size: layout.cardWidth * 0.5,
      ),
    );
    yield _Slot(
      key: const ValueKey('waste'),
      offset: layout.slot(PileRef.waste),
      layout: layout,
    );
    for (final suit in Suit.values) {
      yield _Slot(
        key: ValueKey('foundation-${suit.index}'),
        offset: layout.slot(PileRef.foundation(suit.index)),
        layout: layout,
        child: SuitIcon(
          suit,
          size: layout.cardWidth * 0.45,
          color: Colors.white24,
        ),
      );
    }
    for (var i = 0; i < 7; i++) {
      yield _Slot(
        key: ValueKey('tableau-$i'),
        offset: layout.slot(PileRef.tableau(i)),
        layout: layout,
        child: Text(
          // Only a king can go on an empty column.
          rankIndex(13, AppLocalizations.of(context)),
          style: TextStyle(
            color: Colors.white24,
            fontSize: layout.cardWidth * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
  }

  /// Cards on the table in pile order (a card that waits keeps the place of
  /// its old pile), then the cards in the air, the latest on top.
  List<Widget> _cards(
    KlondikeState state,
    _BoardLayout layout,
    Map<PileRef, List<Offset>> pileOffsets,
  ) {
    (int, double) paintOrder(_Target target) {
      final motion = _motions[target.card.id];
      if (motion == null) return (0, target.z.toDouble());
      if (motion.isFlyingAt(_now)) return (1, motion.segmentAt(_now).start);
      if (motion.isWaitingAt(_now)) {
        return (0, (_waitZ[target.card.id] ?? target.z).toDouble());
      }
      return (0, target.z.toDouble());
    }

    final ordered =
        [for (final target in _targets.values) (target, paintOrder(target))]
          ..sort((a, b) {
            final byGroup = a.$2.$1.compareTo(b.$2.$1);
            return byGroup != 0 ? byGroup : a.$2.$2.compareTo(b.$2.$2);
          });
    return [
      for (final (target, _) in ordered)
        _card(state, target, layout, pileOffsets[target.pile]!),
    ];
  }

  Widget _card(
    KlondikeState state,
    _Target target,
    _BoardLayout layout,
    List<Offset> offsets,
  ) {
    final card = target.card;
    final pile = target.pile;
    final cards = state.pile(pile);
    final index = target.index;
    final count = cards.length - index;
    final isTop = count == 1;
    final hidden = _isDragging && _dragging!.cardIds.contains(card.id);
    final pose = _motions[card.id]?.poseAt(_now);

    Widget child = CardView(
      card: pose == null || pose.faceUp == card.faceUp
          ? card
          : card.turned(faceUp: pose.faceUp),
      width: layout.cardWidth,
      cardBack: widget.cardBack,
    );
    if (pose != null) child = _Posed(pose: pose, layout: layout, child: child);
    if (pile.type == PileType.stock) {
      child = GestureDetector(
        onTap: () => _unlessDragging(_controller.draw),
        child: child,
      );
    } else if (card.faceUp && (isTop || pile.type == PileType.tableau)) {
      final data = _DragData(pile, cards.skip(index), [
        for (var i = index; i < cards.length; i++) offsets[i] - offsets[index],
      ]);
      child = Draggable<_DragData>(
        data: data,
        feedback: _DragFeedback(
          cards: cards.sublist(index),
          offsets: offsets.sublist(index),
          layout: layout,
          cardBack: widget.cardBack,
        ),
        onDragStarted: () => setState(() => _dragging = data),
        onDragEnd: (_) => setState(() => _dragging = null),
        onDraggableCanceled: (_, offset) => _snapBack(data, offset),
        child: GestureDetector(
          // Taps on a foundation card would only move it back down.
          onTap: pile.type == PileType.foundation
              ? null
              : () => _unlessDragging(() {
                  if (!_controller.tap(pile, count)) {
                    _shake(cards.skip(index), layout);
                  }
                }),
          child: child,
        ),
      );
    }

    final position = pose?.position ?? target.offset;
    return Positioned(
      key: ValueKey(card.id),
      left: position.dx,
      top: position.dy,
      width: layout.cardWidth,
      height: layout.cardHeight,
      child: Opacity(opacity: hidden ? 0 : 1, child: child),
    );
  }

  Iterable<Widget> _dropTargets(_BoardLayout layout) sync* {
    for (var i = 0; i < 4; i++) {
      final target = PileRef.foundation(i);
      yield _dropTarget(
        target,
        layout.slotRect(target).inflate(layout.gap / 2),
      );
    }
    for (var i = 0; i < 7; i++) {
      final target = PileRef.tableau(i);
      final slot = layout.slotRect(target);
      yield _dropTarget(
        target,
        Rect.fromLTRB(
          slot.left - layout.gap / 2,
          slot.top - layout.gap / 2,
          slot.right + layout.gap / 2,
          layout.height,
        ),
      );
    }
  }

  Widget _dropTarget(PileRef target, Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) =>
            details.data.matches(_controller.state) &&
            _controller.state.canMove(
              details.data.from,
              details.data.count,
              target,
            ),
        onAcceptWithDetails: (details) =>
            _drop(details.data, target, details.offset),
        // The child never takes hits, so taps and drags reach the cards below.
        builder: (context, candidates, _) => IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? Colors.transparent
                  : const Color(0x22FFFFFF),
              border: Border.all(
                color: candidates.isEmpty ? Colors.transparent : Colors.white70,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  void _drop(_DragData data, PileRef target, Offset globalTopLeft) {
    final topLeft = _toLocal(globalTopLeft);
    setState(() {
      _dragging = null;
      _dropStarts = {
        for (final (i, id) in data.cardIds.indexed)
          id: topLeft + data.relativeOffsets[i],
      };
    });
    _controller.move(data.from, data.count, target);
  }
}

/// Draws a card in the air: lifted, turned or tilted, with a shadow that
/// grows with the height.
class _Posed extends StatelessWidget {
  const _Posed({required this.pose, required this.layout, required this.child});

  final CardPose pose;
  final _BoardLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var card = child;
    if (pose.elevation > 0) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.cardWidth * 0.1),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.35 * pose.elevation),
              blurRadius: 4 + 14 * pose.elevation,
              offset: Offset(0, 2 + 10 * pose.elevation),
            ),
          ],
        ),
        child: card,
      );
    }
    if (pose.scale == 1 && pose.rotation == 0 && pose.flipAngle == 0) {
      return card;
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        // Perspective, so a flip looks like a card turning over.
        ..setEntry(3, 2, 0.0012)
        ..rotateY(pose.flipAngle)
        ..rotateZ(pose.rotation)
        ..scaleByDouble(pose.scale, pose.scale, 1, 1),
      child: card,
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.offset,
    required this.layout,
    this.onTap,
    this.child,
  });

  final Offset offset;
  final _BoardLayout layout;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: layout.cardWidth,
      height: layout.cardHeight,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x1A000000),
            border: Border.all(color: Colors.white24, width: 1.5),
            borderRadius: BorderRadius.circular(layout.cardWidth * 0.1),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.cards,
    required this.offsets,
    required this.layout,
    required this.cardBack,
  });

  final List<PlayingCard> cards;
  final List<Offset> offsets;
  final _BoardLayout layout;
  final CardBackSkin cardBack;

  @override
  Widget build(BuildContext context) {
    final top = offsets.first.dy;
    // Picked up: a little bigger and tilted, with a deep shadow.
    return Material(
      type: MaterialType.transparency,
      child: Transform.rotate(
        angle: -0.025,
        alignment: Alignment.topCenter,
        child: Transform.scale(
          scale: 1.05,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: layout.cardWidth,
            height: offsets.last.dy - top + layout.cardHeight,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    top: offsets[i].dy - top,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          layout.cardWidth * 0.1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CardView(
                        card: cards[i],
                        width: layout.cardWidth,
                        cardBack: cardBack,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card size and card positions for a given board size.
class _BoardLayout {
  factory _BoardLayout(Size size, int drawCount) {
    final gap = (size.width * 0.012).clamp(4.0, 12.0);
    final cardWidth = [
      (size.width - gap * 8) / 7,
      // Keep room for the top row and a tall tableau pile.
      (size.height - gap * 3) / (1.4 * 3.2),
      120.0,
    ].reduce(min);
    return _BoardLayout._(gap, cardWidth, size.height, drawCount);
  }

  _BoardLayout._(this.gap, this.cardWidth, this.height, this.drawCount);

  final double gap;
  final double cardWidth;
  final double height;
  final int drawCount;

  double get cardHeight => cardWidth * 1.4;
  double get boardWidth => cardWidth * 7 + gap * 8;
  double get _tableauTop => gap * 2 + cardHeight;

  double _columnX(int column) => gap + column * (cardWidth + gap);

  Offset slot(PileRef ref) => switch (ref.type) {
    PileType.stock => Offset(_columnX(0), gap),
    PileType.waste => Offset(_columnX(1), gap),
    PileType.foundation => Offset(_columnX(3 + ref.index), gap),
    PileType.tableau => Offset(_columnX(ref.index), _tableauTop),
  };

  Rect slotRect(PileRef ref) => slot(ref) & Size(cardWidth, cardHeight);

  List<Offset> offsets(PileRef ref, List<PlayingCard> cards) {
    final origin = slot(ref);
    switch (ref.type) {
      case PileType.stock || PileType.foundation:
        return List.filled(cards.length, origin);
      case PileType.waste:
        // Draw 3 shows the last three cards fanned to the right.
        final fanned = drawCount == 3 ? min(3, cards.length) : 1;
        final firstFanned = cards.length - fanned;
        return [
          for (var i = 0; i < cards.length; i++)
            origin.translate(max(0, i - firstFanned) * cardWidth * 0.4, 0),
        ];
      case PileType.tableau:
        final steps = [
          for (var i = 0; i < cards.length - 1; i++)
            cardHeight * (cards[i].faceUp ? 0.3 : 0.14),
        ];
        final total = steps.fold(0.0, (sum, step) => sum + step);
        final room = height - _tableauTop - cardHeight - gap;
        final scale = total > room && total > 0 ? max(0.0, room / total) : 1.0;
        final result = <Offset>[];
        var y = origin.dy;
        for (var i = 0; i < cards.length; i++) {
          result.add(Offset(origin.dx, y));
          if (i < steps.length) y += steps[i] * scale;
        }
        return result;
    }
  }
}
