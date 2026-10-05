import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

import '../skins/card_backs.dart';
import 'card_motion.dart';
import 'card_view.dart';
import 'confetti.dart';
import 'moving_card.dart';
import 'playing_card.dart';

/// One pile of cards on a [CardTable], laid out by the game.
class TablePile<P> {
  TablePile({
    required this.id,
    required this.cards,
    required this.offsets,
    required this.rect,
    this.slot,
    this.dropRect,
  }) : assert(cards.length == offsets.length);

  final P id;

  /// Bottom card first.
  final List<PlayingCard> cards;

  /// Top-left corner of each card on the table.
  final List<Offset> offsets;

  /// The card-sized place of the pile: its [slot] is drawn there, a deal from
  /// the pile starts there and a celebration bursts from there.
  final Rect rect;

  /// Drawn at [rect] under the cards, for example a [CardSlot]. A tap on it
  /// calls [CardTable.onSlotTap].
  final Widget? slot;

  /// Where cards can be dropped on this pile; null when they cannot.
  final Rect? dropRect;
}

/// How the cards of one action move, so each game can give each kind of
/// action its own rhythm. Times are in milliseconds.
class MotionStyle {
  const MotionStyle({
    this.stagger = 28,
    this.duration,
    this.curve,
    this.reverse = false,
    this.arc = 0.14,
    this.maxArc = 0.4,
  });

  /// Time between the starts of two cards, in [TableAction.cardIds] order.
  final double stagger;

  /// Flight time; null for a time from the distance (200 to 420 ms).
  final double? duration;

  /// Null to ease in and out on long flights, and only out on short ones.
  final Curve? curve;

  /// The last card of the order starts first, as a pile turned over.
  final bool reverse;

  /// Height of the arc of a long flight: [arc] times its length, at most
  /// [maxArc] card heights.
  final double arc;
  final double maxArc;
}

/// The last change of the game, so that the table animates it. Each action
/// has a new [serial]: a rebuild with the same serial only changes the layout.
class TableAction<P> {
  const TableAction(
    this.serial, {
    this.cardIds = const [],
    this.style = const MotionStyle(),
    this.dealFrom,
    this.stops = const {},
    this.thenIds = const [],
    this.thenStyle = const MotionStyle(),
  });

  final int serial;

  /// The cards that the action moved, in the order they move.
  final List<String> cardIds;
  final MotionStyle style;

  /// Set for a new deal: the cards of [cardIds] fly in face down from this
  /// pile one after the other, and turn over where they land. The other
  /// cards are placed at once.
  final P? dealFrom;

  /// For an action in two steps, such as a Spider run that a move completes:
  /// it lands on its column, then leaves for the foundations. The cards of
  /// [stops] first go to their stop, with the other cards of [cardIds]; once
  /// these landed, the cards of [thenIds] go on to their places one after
  /// the other, with [thenStyle]. A card of [thenIds] without a stop waits
  /// where it was, and one that stays in place turns over then.
  final Map<String, CardStop<P>> stops;
  final List<String> thenIds;
  final MotionStyle thenStyle;
}

/// Where a card waits between the two steps of a [TableAction]: at [offset],
/// drawn as the card [index] of [pile].
class CardStop<P> {
  const CardStop(this.pile, this.index, this.offset);

  final P pile;
  final int index;
  final Offset offset;
}

/// A card table: draws piles of cards and moves every card on one timeline.
///
/// The game lays out the piles and decides what the player can do; on each
/// new [TableAction], the table compares the new places of the cards with the
/// old ones and plans a [CardMotion] for each card that changed (flights on an
/// arc, flips, a deal), so moves look fluid and follow each other without
/// jumps. Taps and drags go back to the game through the callbacks, where
/// `index` is the place of a card in its pile (the cards above it come along).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf`) moves the cards at once.
class CardTable<P extends Object> extends StatefulWidget {
  const CardTable({
    super.key,
    required this.size,
    required this.cardWidth,
    required this.cardBack,
    required this.piles,
    required this.action,
    this.canDrag,
    this.canTap,
    this.onTap,
    this.canDrop,
    this.onDrop,
    this.onSlotTap,
    this.celebration,
    this.onCelebrated,
  });

  final Size size;

  /// Cards are 1.4 times as tall as wide.
  final double cardWidth;

  /// The look of the face-down cards.
  final CardBackSkin cardBack;

  /// In paint order: the cards of a later pile are drawn above. Card ids are
  /// unique on the table.
  final List<TablePile<P>> piles;
  final TableAction<P> action;

  /// Whether the player can pick up the card and the cards above it.
  final bool Function(P pile, int index)? canDrag;

  /// Whether a tap on the card goes to [onTap].
  final bool Function(P pile, int index)? canTap;

  /// Returns false when the tap could not move anything: the card and the
  /// cards above it then shake.
  final bool Function(P pile, int index)? onTap;

  /// Whether the dragged cards (from `index` of `from` up) can go on `to`.
  final bool Function(P from, int index, P to)? canDrop;
  final void Function(P from, int index, P to)? onDrop;
  final void Function(P pile)? onSlotTap;

  /// Set once the game is won: after the winning action, the top cards of
  /// these piles hop one after the other, each with a burst of confetti.
  final List<P>? celebration;

  /// Called once after the winning action, when the celebration has played
  /// (at once with reduced motion).
  final VoidCallback? onCelebrated;

  @override
  State<CardTable<P>> createState() => _CardTableState<P>();
}

/// The empty place of a pile: a dark card outline, with a hint inside.
class CardSlot extends StatelessWidget {
  const CardSlot({super.key, required this.width, this.child});

  final double width;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x1A000000),
        border: Border.all(color: Colors.white24, width: 1.5),
        borderRadius: BorderRadius.circular(width * 0.1),
      ),
      child: Center(child: child),
    );
  }
}

class _DragData<P> {
  _DragData(this.from, this.cardIds, this.relativeOffsets);

  final P from;
  final List<String> cardIds;

  /// Where each card is drawn in the drag feedback, from the first one.
  final List<Offset> relativeOffsets;

  int get count => cardIds.length;
}

/// Where a card rests after the last action.
class _Place<P> {
  const _Place(this.card, this.pile, this.index, this.offset, this.z);

  final PlayingCard card;
  final TablePile<P> pile;
  final int index;
  final Offset offset;

  /// Paint order on the table: the pile, then the place in the pile.
  final double z;
}

/// The key of a card in the paint order, apart from the `ValueKey(card.id)`
/// that tests find.
class _CardKey extends ValueKey<String> {
  const _CardKey(super.value);
}

/// The cards in paint order. It changes when a card takes off or lands, not
/// at every frame.
class _PaintOrder extends ChangeNotifier {
  List<String> ids = const [];

  void update(List<String> next) {
    if (listEquals(ids, next)) return;
    ids = next;
    notifyListeners();
  }
}

class _CardTableState<P extends Object> extends State<CardTable<P>>
    with SingleTickerProviderStateMixin {
  static const _flip = 240.0;

  late final Ticker _ticker = createTicker(_onTick);
  final _tableKey = GlobalKey();

  /// Confetti is drawn on the page overlay, above the app bar.
  final _confettiLayer = OverlayPortalController()..show();

  /// Time on the timeline, in ms. It only goes forward: motions are planned
  /// at times on it, and a frame only moves the cards that listen to it.
  final _clock = ValueNotifier<double>(0);
  double _tickerStart = 0;
  double _end = 0;
  final _motions = <String, CardMotion>{};

  /// Paint order of a card that waits before its motion: its old pile.
  final _waitZ = <String, double>{};

  /// Paint order of a card that waits at a [CardStop] between two steps.
  final _stopZ = <String, double>{};
  final _paintOrder = _PaintOrder();

  /// The win celebration: its confetti, and when to call `onCelebrated`.
  Confetti? _confetti;
  double? _celebratedAt;
  Map<String, _Place<P>> _places = const {};
  int? _seenSerial;

  /// Top-left corners of dropped cards, so they glide from where the player
  /// let them go.
  Map<String, Offset>? _dropStarts;
  _DragData<P>? _dragging;

  double get _now => _clock.value;
  double get _cardHeight => widget.cardWidth * 1.4;

  bool get _isDragging => _dragging != null && _matches(_dragging!);

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _paintOrder.dispose();
    super.dispose();
  }

  TablePile<P>? _pile(P id) {
    for (final pile in widget.piles) {
      if (pile.id == id) return pile;
    }
    return null;
  }

  /// False when the pile changed during the drag (for example a second
  /// finger made another move): the drag must then do nothing.
  bool _matches(_DragData<P> data) {
    final cards = _pile(data.from)?.cards;
    if (cards == null || cards.length < data.count) return false;
    for (var i = 0; i < data.count; i++) {
      if (cards[cards.length - data.count + i].id != data.cardIds[i]) {
        return false;
      }
    }
    return true;
  }

  int _indexOf(_DragData<P> data) =>
      _pile(data.from)!.cards.length - data.count;

  /// Table taps wait for the end of a drag, so the dragged cards stay on top.
  void _unlessDragging(VoidCallback action) {
    if (!_isDragging) action();
  }

  void _onTick(Duration elapsed) {
    final now = _tickerStart + elapsed.inMicroseconds / 1000;
    _clock.value = now;
    _paintOrder.update(_orderAt(now));
    if (_celebratedAt case final at? when now >= at) {
      _celebratedAt = null;
      widget.onCelebrated?.call();
    }
    if (now >= _end) _stopTimeline();
  }

  /// The cards keep the motions they have: a motion ends at its target, so
  /// they are on their piles.
  void _stopTimeline() {
    _ticker.stop();
    _motions.clear();
    _waitZ.clear();
    _stopZ.clear();
    _confetti = null;
  }

  /// Adds motions (and a celebration) planned from now. Running motions go
  /// on from where they are.
  void _addMotions(
    Map<String, CardMotion> added, {
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
    _plan(animate: !MediaQuery.disableAnimationsOf(context));
    // The card layer is built below with this order.
    _paintOrder.ids = _orderAt(_now);
    final cards = {
      for (final place in _places.values) place.card.id: _card(place),
    };
    return SizedBox(
      key: _tableKey,
      width: widget.size.width,
      height: widget.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  for (final pile in widget.piles)
                    if (pile.slot case final slot?)
                      Positioned.fromRect(
                        rect: pile.rect,
                        child: GestureDetector(
                          onTap: () => _unlessDragging(
                            () => widget.onSlotTap?.call(pile.id),
                          ),
                          child: slot,
                        ),
                      ),
                ],
              ),
            ),
          ),
          // Changes of the paint order rebuild this layer only, with the same
          // card widgets.
          Positioned.fill(
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: _paintOrder,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [for (final id in _paintOrder.ids) cards[id]!],
                ),
              ),
            ),
          ),
          for (final pile in widget.piles)
            if (pile.dropRect case final rect?) _dropTarget(pile.id, rect),
          OverlayPortal(
            controller: _confettiLayer,
            overlayChildBuilder: (context) => _confettiOverlay(),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Compares the new places of the cards with the old ones and plans the
  /// motions of the last action. Runs on every build, so it only plans what
  /// changed.
  void _plan({required bool animate}) {
    final previous = _places;
    _places = {
      for (final (order, pile) in widget.piles.indexed)
        for (final (index, card) in pile.cards.indexed)
          card.id: _Place(
            card,
            pile,
            index,
            pile.offsets[index],
            order * 1000.0 + index,
          ),
    };
    assert(
      _places.length ==
          widget.piles.fold(0, (count, pile) => count + pile.cards.length),
      'Card ids must be unique on the table',
    );
    final action = widget.action.serial == _seenSerial ? null : widget.action;
    _seenSerial = widget.action.serial;
    final dropStarts = action == null ? null : _dropStarts;
    if (action != null) _dropStarts = null;

    final won = action != null && widget.celebration != null;
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
    if (action?.dealFrom case final from?) {
      _stopTimeline();
      _celebratedAt = null;
      _addMotions(_dealMotions(action!, from));
      return;
    }
    // A game that continues shows up as it is.
    if (previous.isEmpty) return;

    final moved = action?.cardIds ?? const <String>[];
    final stops = action?.stops ?? const {};
    final thenIds = action?.thenIds ?? const <String>[];
    final added = <String, CardMotion>{};
    // Where and how each card of the second step starts it.
    final origins = <String, (Offset, bool)>{};
    for (final MapEntry(key: id, value: place) in _places.entries) {
      final before = previous[id];
      if (before == null) continue;
      final moves = before.offset != place.offset;
      final flips = before.card.faceUp != place.card.faceUp;
      if (!moves && !flips) continue;
      final pose = _motions[id]?.poseAt(_now);
      _stopZ.remove(id);
      final from = dropStarts?[id] ?? pose?.position ?? before.offset;
      final faceFrom = pose?.faceUp ?? before.card.faceUp;
      final stop = stops[id];
      if (stop == null && thenIds.contains(id)) {
        // Waits for the second step.
        origins[id] = (from, faceFrom);
        continue;
      }
      final motion = _motionFor(
        action,
        from: from,
        to: stop?.offset ?? place.offset,
        faceFrom: faceFrom,
        faceTo: place.card.faceUp,
        order: max(0, moved.indexOf(id)),
        orderCount: moved.length,
        dropped: dropStarts?.containsKey(id) ?? false,
      );
      if (motion.start > 0) {
        _waitZ[id] = before.z;
      } else {
        _waitZ.remove(id);
      }
      added[id] = motion;
      if (stop != null) {
        origins[id] = (stop.offset, place.card.faceUp);
        final pile = _pile(stop.pile);
        if (pile != null) {
          _stopZ[id] = widget.piles.indexOf(pile) * 1000.0 + stop.index;
        }
      }
    }
    if (action != null && thenIds.isNotEmpty) {
      _planThen(action, origins, added, previous);
    }
    if (won) {
      _celebrate(added);
    } else {
      _addMotions(added);
    }
  }

  CardMotion _motionFor(
    TableAction<P>? action, {
    required Offset from,
    required Offset to,
    required bool faceFrom,
    required bool faceTo,
    required int order,
    required int orderCount,
    required bool dropped,
  }) {
    final style = action?.style ?? const MotionStyle();
    final distance = (to - from).distance;
    final long = distance > _cardHeight * 0.6;
    final arc = long
        ? min(distance * style.arc, _cardHeight * style.maxArc)
        : 0.0;
    final (start, duration, curve) = switch (action) {
      // Window resize or a pile that spreads: a quick glide.
      null => (0.0, 220.0, Curves.easeOutCubic),
      _ when dropped => (0.0, 160.0, Curves.easeOutCubic),
      _ => (
        (style.reverse ? orderCount - 1 - order : order) * style.stagger,
        style.duration ?? (170 + distance * 0.5).clamp(200.0, 420.0),
        style.curve ?? (long ? Curves.easeInOutCubic : Curves.easeOutCubic),
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

  /// The second step of [action]: after the first one landed, the cards of
  /// [TableAction.thenIds] leave their stop (or their old place) one after
  /// the other.
  void _planThen(
    TableAction<P> action,
    Map<String, (Offset, bool)> origins,
    Map<String, CardMotion> added,
    Map<String, _Place<P>> previous,
  ) {
    const pause = 80.0;
    final landed = added.values.fold(
      0.0,
      (end, motion) => max(end, motion.start + motion.duration),
    );
    final style = action.thenStyle;
    for (final (i, id) in action.thenIds.indexed) {
      final place = _places[id];
      final origin = origins[id];
      if (place == null || origin == null) continue;
      final (from, faceFrom) = origin;
      final start = landed + pause + i * style.stagger;
      final distance = (place.offset - from).distance;
      final moving = distance > 0;
      final duration = moving
          ? style.duration ?? (170 + distance * 0.5).clamp(200.0, 420.0)
          : 0.0;
      final motion = CardMotion(
        kind: CardMotionKind.fly,
        from: from,
        to: place.offset,
        start: start,
        duration: duration,
        height: distance > _cardHeight * 0.6
            ? min(distance * style.arc, _cardHeight * style.maxArc)
            : 0,
        curve: style.curve ?? Curves.easeInOutCubic,
        faceFrom: faceFrom,
        faceTo: place.card.faceUp,
        flipStart: start,
        flipDuration: moving ? max(duration, _flip) : _flip,
      );
      if (added[id] case final first?) {
        added[id] = first.followedBy(motion);
      } else {
        added[id] = motion;
        _waitZ[id] = previous[id]?.z ?? place.z;
      }
    }
  }

  /// The dealt cards fly from the pile one by one, in the order of the
  /// action, and turn over when they land.
  Map<String, CardMotion> _dealMotions(TableAction<P> action, P from) {
    final source = _pile(from);
    if (source == null) return const {};
    final origin = source.rect.topLeft;
    // Waiting cards sit on top of the pile they come from.
    final waitZ = widget.piles.indexOf(source) * 1000.0 + 500;
    final style = action.style;
    final duration = style.duration ?? 280;
    final motions = <String, CardMotion>{};
    for (final (i, id) in action.cardIds.indexed) {
      final place = _places[id];
      if (place == null) continue;
      final start = i * style.stagger;
      final distance = (place.offset - origin).distance;
      motions[id] = CardMotion(
        kind: CardMotionKind.fly,
        from: origin,
        to: place.offset,
        start: start,
        duration: duration,
        height: min(distance * style.arc, _cardHeight * style.maxArc),
        curve: style.curve ?? Curves.easeOutCubic,
        faceFrom: false,
        faceTo: place.card.faceUp,
        flipStart: start + duration,
        flipDuration: _flip,
      );
      _waitZ[id] = waitZ + i;
    }
    return motions;
  }

  /// After the last card lands, the top cards of the celebration piles hop
  /// one after the other, each with a burst of confetti from its pile.
  void _celebrate(Map<String, CardMotion> added) {
    const hop = 620.0;
    final landed = added.values.fold(
      0.0,
      (end, motion) => max(end, motion.end),
    );
    final origins = <Offset>[];
    final starts = <double>[];
    for (final id in widget.celebration!) {
      final pile = _pile(id);
      final top = pile?.cards.lastOrNull;
      if (pile == null || top == null) continue;
      final place = _places[top.id]!;
      final start = landed + 120 + starts.length * 110;
      origins.add(pile.rect.center);
      starts.add(start);
      final jump = CardMotion(
        kind: CardMotionKind.hop,
        from: place.offset,
        to: place.offset,
        start: start,
        duration: hop,
        // Low enough to stay below the app bar.
        height: _cardHeight * 0.3,
        faceFrom: top.faceUp,
        faceTo: top.faceUp,
      );
      added[top.id] =
          added[top.id]?.followedBy(jump) ??
          CardMotion(
            kind: CardMotionKind.fly,
            from: place.offset,
            to: place.offset,
            start: 0,
            duration: 0,
            faceFrom: top.faceUp,
            faceTo: top.faceUp,
            next: jump,
          );
    }
    _addMotions(
      added,
      confetti: starts.isEmpty
          ? null
          : Confetti(
              origins: origins,
              starts: starts,
              scale: widget.cardWidth / 80,
              seed: widget.action.serial,
            ),
      celebratedAt: (starts.isEmpty ? landed : starts.last + hop) + 450,
    );
  }

  /// A tap with no legal move: the cards shake their head.
  void _shake(P pileId, int index) {
    final pile = _pile(pileId);
    if (pile == null) return;
    setState(() {
      _addMotions({
        for (final card in pile.cards.skip(index))
          card.id: CardMotion(
            kind: CardMotionKind.shake,
            from: _places[card.id]!.offset,
            to: _places[card.id]!.offset,
            start: 0,
            duration: 380,
            height: widget.cardWidth * 0.07,
            faceFrom: card.faceUp,
            faceTo: card.faceUp,
          ),
      });
    });
  }

  /// Dropped where they cannot go: the cards fly back to their pile.
  void _snapBack(_DragData<P> data, Offset globalTopLeft) {
    if (!_matches(data)) return;
    final topLeft = _toLocal(globalTopLeft);
    setState(() {
      _addMotions({
        for (final (i, id) in data.cardIds.indexed)
          if (_places[id] case final place?)
            id: CardMotion(
              kind: CardMotionKind.fly,
              from: topLeft + data.relativeOffsets[i],
              to: place.offset,
              start: i * 18.0,
              duration: 320,
              curve: Curves.easeOutBack,
              faceFrom: place.card.faceUp,
              faceTo: place.card.faceUp,
            ),
      });
    });
  }

  void _drop(_DragData<P> data, P to, Offset globalTopLeft) {
    final topLeft = _toLocal(globalTopLeft);
    final index = _indexOf(data);
    setState(() {
      _dragging = null;
      _dropStarts = {
        for (final (i, id) in data.cardIds.indexed)
          id: topLeft + data.relativeOffsets[i],
      };
    });
    widget.onDrop?.call(data.from, index, to);
  }

  Offset _toLocal(Offset global) {
    final box = _tableKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  /// Cards on the table in pile order (a card that waits keeps the place of
  /// its old pile), then the cards in the air, the latest on top.
  List<String> _orderAt(double t) {
    (int, double, double) keyOf(_Place<P> place) {
      final id = place.card.id;
      final motion = _motions[id];
      if (motion != null && motion.isFlyingAt(t)) {
        return (1, motion.segmentAt(t).start, place.z);
      }
      if (motion != null && motion.isWaitingAt(t)) {
        return (0, _waitZ[id] ?? place.z, place.z);
      }
      if (_stopZ[id] case final z?
          when motion != null && t <= (motion.next?.start ?? 0)) {
        return (0, z, place.z);
      }
      return (0, place.z, place.z);
    }

    final keyed = [
      for (final place in _places.values) (place.card.id, keyOf(place)),
    ];
    keyed.sort((a, b) {
      final (groupA, orderA, zA) = a.$2;
      final (groupB, orderB, zB) = b.$2;
      if (groupA != groupB) return groupA.compareTo(groupB);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return zA.compareTo(zB);
    });
    return [for (final (id, _) in keyed) id];
  }

  /// Built once per action: a frame only moves it ([MovingCard]) and turns
  /// it over ([TurningCardView]).
  Widget _card(_Place<P> place) {
    final _Place(:card, :pile, :index, :offset) = place;
    final motion = _motions[card.id];
    final hidden = _isDragging && _dragging!.cardIds.contains(card.id);
    Widget child = RepaintBoundary(
      child: TurningCardView(
        card: card,
        motion: motion,
        clock: _clock,
        width: widget.cardWidth,
        cardBack: widget.cardBack,
      ),
    );
    if (widget.canTap?.call(pile.id, index) ?? false) {
      child = GestureDetector(
        onTap: () => _unlessDragging(() {
          if (!(widget.onTap?.call(pile.id, index) ?? true)) {
            _shake(pile.id, index);
          }
        }),
        child: child,
      );
    }
    if (widget.canDrag?.call(pile.id, index) ?? false) {
      final data = _DragData(
        pile.id,
        [for (final card in pile.cards.skip(index)) card.id],
        [for (final at in pile.offsets.skip(index)) at - offset],
      );
      child = Draggable<_DragData<P>>(
        data: data,
        feedback: _DragFeedback(
          cards: pile.cards.sublist(index),
          offsets: pile.offsets.sublist(index),
          cardWidth: widget.cardWidth,
          cardBack: widget.cardBack,
        ),
        onDragStarted: () => setState(() => _dragging = data),
        onDragEnd: (_) => setState(() => _dragging = null),
        onDraggableCanceled: (_, offset) => _snapBack(data, offset),
        child: child,
      );
    }
    return Positioned(
      key: _CardKey(card.id),
      left: offset.dx,
      top: offset.dy,
      width: widget.cardWidth,
      height: _cardHeight,
      child: MovingCard(
        clock: _clock,
        motion: motion,
        rest: offset,
        child: KeyedSubtree(
          key: ValueKey(card.id),
          child: Opacity(opacity: hidden ? 0 : 1, child: child),
        ),
      ),
    );
  }

  Widget _dropTarget(P target, Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: DragTarget<_DragData<P>>(
        onWillAcceptWithDetails: (details) =>
            _matches(details.data) &&
            (widget.canDrop?.call(
                  details.data.from,
                  _indexOf(details.data),
                  target,
                ) ??
                false),
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

  Widget _confettiOverlay() {
    final confetti = _confetti;
    final table = _tableKey.currentContext?.findRenderObject() as RenderBox?;
    if (confetti == null || table == null || !table.hasSize) {
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
              origin: table.localToGlobal(Offset.zero),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.cards,
    required this.offsets,
    required this.cardWidth,
    required this.cardBack,
  });

  final List<PlayingCard> cards;
  final List<Offset> offsets;
  final double cardWidth;
  final CardBackSkin cardBack;

  @override
  Widget build(BuildContext context) {
    final top = offsets.first.dy;
    // Picked up: a little bigger and tilted, with a deep shadow.
    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: Transform.rotate(
          angle: -0.025,
          alignment: Alignment.topCenter,
          child: Transform.scale(
            scale: 1.05,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardWidth,
              height: offsets.last.dy - top + cardWidth * 1.4,
              child: Stack(
                children: [
                  for (var i = 0; i < cards.length; i++)
                    Positioned(
                      top: offsets[i].dy - top,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cardWidth * 0.1),
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
                          width: cardWidth,
                          cardBack: cardBack,
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
}
