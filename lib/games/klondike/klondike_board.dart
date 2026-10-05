import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../cards/card_table.dart';
import '../../cards/card_view.dart';
import '../../cards/playing_card.dart';
import '../../cards/suit_icon.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'klondike_controller.dart';
import 'klondike_state.dart';

/// In paint order.
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

const _foundations = [
  PileRef.foundation(0),
  PileRef.foundation(1),
  PileRef.foundation(2),
  PileRef.foundation(3),
];

/// Row by row from the stock, like a real deal.
const _dealStyle = MotionStyle(
  stagger: 32,
  duration: 280,
  curve: Curves.easeOutCubic,
  arc: 0.1,
  maxArc: 0.3,
);
const _drawStyle = MotionStyle(
  stagger: 70,
  duration: 280,
  curve: Curves.easeOutCubic,
);

/// The whole waste turns back over, like a riffle.
const _recycleStyle = MotionStyle(
  stagger: 6,
  duration: 260,
  curve: Curves.easeInOutCubic,
  reverse: true,
);
const _cascadeStyle = MotionStyle(
  stagger: 45,
  duration: 300,
  curve: Curves.easeInOutCubic,
);

/// The Klondike table on a [CardTable]: the layout of the piles, what the
/// player can do with each card, and the rhythm of each action.
class KlondikeBoard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;
          final layout = _BoardLayout(constraints.biggest, state.drawCount);
          return Center(
            child: CardTable<PileRef>(
              size: Size(layout.boardWidth, layout.height),
              cardWidth: layout.cardWidth,
              cardBack: cardBack,
              piles: [
                for (final ref in _allPiles) _pile(ref, state, layout, l10n),
              ],
              action: _action(state),
              canDrag: _canDrag,
              canTap: _canTap,
              onTap: _tap,
              canDrop: (from, index, to) =>
                  controller.state.canMove(from, _countFrom(from, index), to),
              onDrop: (from, index, to) =>
                  controller.move(from, _countFrom(from, index), to),
              onSlotTap: (pile) {
                if (pile == PileRef.stock) controller.draw();
              },
              celebration: controller.result == null ? null : _foundations,
              onCelebrated: onCelebrated,
            ),
          );
        },
      ),
    );
  }

  int _countFrom(PileRef pile, int index) =>
      controller.state.pile(pile).length - index;

  bool _canDrag(PileRef pile, int index) {
    final cards = controller.state.pile(pile);
    return pile != PileRef.stock &&
        cards[index].faceUp &&
        (index == cards.length - 1 || pile.type == PileType.tableau);
  }

  /// The stock draws; a foundation card would only move back down.
  bool _canTap(PileRef pile, int index) =>
      pile == PileRef.stock ||
      (pile.type != PileType.foundation && _canDrag(pile, index));

  bool _tap(PileRef pile, int index) {
    if (pile == PileRef.stock) {
      controller.draw();
      return true;
    }
    return controller.tap(pile, _countFrom(pile, index));
  }

  TableAction<PileRef> _action(KlondikeState state) {
    final serial = controller.actionSerial;
    final moved = controller.lastMovedCardIds.toList();
    return switch (controller.lastAction) {
      KlondikeAction.deal => TableAction(
        serial,
        cardIds: _dealOrder(state),
        style: _dealStyle,
        dealFrom: PileRef.stock,
      ),
      KlondikeAction.draw => TableAction(
        serial,
        cardIds: moved,
        style: _drawStyle,
      ),
      KlondikeAction.recycle => TableAction(
        serial,
        cardIds: moved,
        style: _recycleStyle,
      ),
      KlondikeAction.autoComplete => TableAction(
        serial,
        cardIds: moved,
        style: _cascadeStyle,
      ),
      KlondikeAction.none ||
      KlondikeAction.move ||
      KlondikeAction.undo => TableAction(serial, cardIds: moved),
    };
  }

  /// The tableau cards, row by row from the left.
  static List<String> _dealOrder(KlondikeState state) {
    final rows = state.tableau.fold(0, (rows, pile) => max(rows, pile.length));
    return [
      for (var row = 0; row < rows; row++)
        for (final pile in state.tableau)
          if (row < pile.length) pile[row].id,
    ];
  }

  TablePile<PileRef> _pile(
    PileRef ref,
    KlondikeState state,
    _BoardLayout layout,
    AppLocalizations l10n,
  ) {
    final cards = state.pile(ref);
    final rect = layout.slotRect(ref);
    final gap = layout.gap / 2;
    final (key, hint) = switch (ref.type) {
      PileType.stock => (
        'stock',
        Icon(
          state.waste.isEmpty ? Icons.block : Icons.refresh,
          color: Colors.white54,
          size: layout.cardWidth * 0.5,
        ),
      ),
      PileType.waste => ('waste', null),
      PileType.foundation => (
        'foundation-${ref.index}',
        SuitIcon(
          Suit.values[ref.index],
          size: layout.cardWidth * 0.45,
          color: Colors.white24,
        ),
      ),
      PileType.tableau => (
        'tableau-${ref.index}',
        Text(
          // Only a king can go on an empty column.
          rankIndex(13, l10n),
          style: TextStyle(
            color: Colors.white24,
            fontSize: layout.cardWidth * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    };
    return TablePile(
      id: ref,
      cards: cards,
      offsets: layout.offsets(ref, cards),
      rect: rect,
      slot: CardSlot(key: ValueKey(key), width: layout.cardWidth, child: hint),
      dropRect: switch (ref.type) {
        PileType.stock || PileType.waste => null,
        PileType.foundation => rect.inflate(gap),
        PileType.tableau => Rect.fromLTRB(
          rect.left - gap,
          rect.top - gap,
          rect.right + gap,
          layout.height,
        ),
      },
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
