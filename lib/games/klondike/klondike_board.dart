import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'card_view.dart';
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

/// Draws the whole Klondike table in one [Stack]: every card is an
/// [AnimatedPositioned] keyed by card id, so each move animates by itself.
class KlondikeBoard extends StatefulWidget {
  const KlondikeBoard({
    super.key,
    required this.controller,
    required this.cardBack,
  });

  final KlondikeController controller;

  /// The look of the face-down cards.
  final CardBackSkin cardBack;

  @override
  State<KlondikeBoard> createState() => _KlondikeBoardState();
}

class _DragData {
  _DragData(this.from, Iterable<PlayingCard> cards)
    : cardIds = [for (final card in cards) card.id];

  final PileRef from;
  final List<String> cardIds;

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

class _KlondikeBoardState extends State<KlondikeBoard> {
  _DragData? _dragging;

  /// Cards that the player dropped: they are already at their target, so
  /// they must not animate from their old pile.
  Set<String> _droppedCardIds = const {};

  KlondikeController get _controller => widget.controller;

  bool get _isDragging => _dragging?.matches(_controller.state) ?? false;

  /// Board taps wait for the end of a drag, so the dragged cards stay on top.
  void _unlessDragging(VoidCallback action) {
    if (!_isDragging) action();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final state = _controller.state;
          final layout = _BoardLayout(constraints.biggest, state.drawCount);
          return Center(
            child: SizedBox(
              width: layout.boardWidth,
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._slots(state, layout),
                  ..._cards(state, layout),
                  ..._dropTargets(layout),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  List<Widget> _cards(KlondikeState state, _BoardLayout layout) {
    final moved = _controller.lastMovedCardIds;
    final resting = <Widget>[];
    final moving = <Widget>[];
    for (final ref in _allPiles) {
      final cards = state.pile(ref);
      final offsets = layout.offsets(ref, cards);
      for (var i = 0; i < cards.length; i++) {
        final widget = _card(cards, i, ref, offsets, layout);
        (moved.contains(cards[i].id) ? moving : resting).add(widget);
      }
    }
    // Cards that just moved are painted last, so they fly over the others.
    return [...resting, ...moving];
  }

  Widget _card(
    List<PlayingCard> cards,
    int index,
    PileRef pile,
    List<Offset> offsets,
    _BoardLayout layout,
  ) {
    final card = cards[index];
    final count = cards.length - index;
    final isTop = count == 1;
    final hidden = _isDragging && _dragging!.cardIds.contains(card.id);

    Widget child = CardView(
      card: card,
      width: layout.cardWidth,
      cardBack: widget.cardBack,
    );
    if (pile.type == PileType.stock) {
      child = GestureDetector(
        onTap: () => _unlessDragging(_controller.draw),
        child: child,
      );
    } else if (card.faceUp && (isTop || pile.type == PileType.tableau)) {
      final data = _DragData(pile, cards.skip(index));
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
        child: GestureDetector(
          // Taps on a foundation card would only move it back down.
          onTap: pile.type == PileType.foundation
              ? null
              : () => _unlessDragging(() => _controller.tap(pile, count)),
          child: child,
        ),
      );
    }

    final offset = offsets[index];
    return AnimatedPositioned(
      key: ValueKey(card.id),
      duration: _droppedCardIds.contains(card.id)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: offset.dx,
      top: offset.dy,
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
        onAcceptWithDetails: (details) => _drop(details.data, target),
        // The child never takes hits, so taps and drags reach the cards below.
        builder: (context, candidates, _) => IgnorePointer(
          child: candidates.isEmpty
              ? const SizedBox.expand()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
      ),
    );
  }

  void _drop(_DragData data, PileRef target) {
    setState(() {
      _dragging = null;
      _droppedCardIds = data.cardIds.toSet();
    });
    _controller.move(data.from, data.count, target);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _droppedCardIds = const {},
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
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: layout.cardWidth,
        height: offsets.last.dy - top + layout.cardHeight,
        child: Stack(
          children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                top: offsets[i].dy - top,
                child: CardView(
                  card: cards[i],
                  width: layout.cardWidth,
                  cardBack: cardBack,
                ),
              ),
          ],
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
