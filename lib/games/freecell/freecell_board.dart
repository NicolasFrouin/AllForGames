import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../cards/card_table.dart';
import '../../cards/card_view.dart';
import '../../cards/playing_card.dart';
import '../../cards/suit_icon.dart';
import '../../skins/card_backs.dart';
import 'freecell_controller.dart';
import 'freecell_state.dart';

const _foundations = [
  FreeCellPile.foundation(0),
  FreeCellPile.foundation(1),
  FreeCellPile.foundation(2),
  FreeCellPile.foundation(3),
];

/// Row by row from the first free cell, like a real deal.
const _dealStyle = MotionStyle(
  stagger: 22,
  duration: 280,
  curve: Curves.easeOutCubic,
  arc: 0.1,
  maxArc: 0.3,
);

/// The cards that go to the foundations by themselves once the move landed:
/// one after the other, so the eye can follow them.
const _autoStyle = MotionStyle(stagger: 70);
const _cascadeStyle = MotionStyle(
  stagger: 45,
  duration: 300,
  curve: Curves.easeInOutCubic,
);

/// The FreeCell table on a [CardTable]: the layout of the piles, what the
/// player can do with each card, and the rhythm of each action.
class FreeCellBoard extends StatelessWidget {
  const FreeCellBoard({
    super.key,
    required this.controller,
    required this.cardBack,
    this.onCelebrated,
  });

  final FreeCellController controller;

  /// The look of the cards while they are dealt.
  final CardBackSkin cardBack;

  /// Called once after a win, when the celebration has played (at once with
  /// reduced motion): time for the win dialog.
  final VoidCallback? onCelebrated;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;
          final layout = _BoardLayout(constraints.biggest);
          return Center(
            child: CardTable<FreeCellPile>(
              size: Size(layout.boardWidth, layout.height),
              cardWidth: layout.cardWidth,
              cardBack: cardBack,
              piles: [
                for (final ref in FreeCellPile.all) _pile(ref, state, layout),
              ],
              action: _action(state, layout),
              canDrag: _canDrag,
              canTap: (pile, _) => pile.type != FreeCellPileType.foundation,
              onTap: (pile, index) =>
                  controller.tap(pile, _countFrom(pile, index)),
              canDrop: (from, index, to) =>
                  controller.state.canMove(from, _countFrom(from, index), to),
              onDrop: (from, index, to) =>
                  controller.move(from, _countFrom(from, index), to),
              celebration: controller.result == null ? null : _foundations,
              onCelebrated: onCelebrated,
            ),
          );
        },
      ),
    );
  }

  int _countFrom(FreeCellPile pile, int index) =>
      controller.state.pile(pile).length - index;

  /// A free cell card, or a run that a move to another cascade could take.
  bool _canDrag(FreeCellPile pile, int index) {
    final state = controller.state;
    return switch (pile.type) {
      FreeCellPileType.foundation => false,
      FreeCellPileType.cell => true,
      FreeCellPileType.cascade =>
        index >= FreeCellState.runStart(state.cascades[pile.index]) &&
            _countFrom(pile, index) <=
                state.maxRunLength(toEmptyCascade: false),
    };
  }

  TableAction<FreeCellPile> _action(FreeCellState state, _BoardLayout layout) {
    final serial = controller.actionSerial;
    final moved = controller.lastMovedCardIds;
    return switch (controller.lastAction) {
      FreeCellAction.deal => TableAction(
        serial,
        cardIds: _dealOrder(state),
        style: _dealStyle,
        dealFrom: const FreeCellPile.cell(0),
      ),
      FreeCellAction.move when controller.lastLanding != null => _twoSteps(
        serial,
        moved,
        controller.lastLanding!,
        layout,
      ),
      FreeCellAction.finish => TableAction(
        serial,
        cardIds: moved,
        style: _cascadeStyle,
      ),
      FreeCellAction.none ||
      FreeCellAction.move ||
      FreeCellAction.undo => TableAction(serial, cardIds: moved),
    };
  }

  /// A move, then the automatic moves to the foundations once it landed. A
  /// moved card that goes on to a foundation first lands where the player
  /// put it, as [landing] shows.
  TableAction<FreeCellPile> _twoSteps(
    int serial,
    List<String> moved,
    FreeCellState landing,
    _BoardLayout layout,
  ) {
    final split = moved.length - controller.lastAutoMoveCount;
    final automatic = moved.sublist(split);
    final stops = <String, CardStop<FreeCellPile>>{};
    for (final ref in FreeCellPile.all) {
      final cards = landing.pile(ref);
      final offsets = layout.offsets(ref, cards);
      for (final (index, card) in cards.indexed) {
        if (automatic.contains(card.id) && moved.indexOf(card.id) < split) {
          stops[card.id] = CardStop(ref, index, offsets[index]);
        }
      }
    }
    return TableAction(
      serial,
      cardIds: moved.sublist(0, split),
      stops: stops,
      thenIds: automatic,
      thenStyle: _autoStyle,
    );
  }

  /// The cascade cards, row by row from the left.
  static List<String> _dealOrder(FreeCellState state) {
    final rows = state.cascades.fold(0, (rows, pile) => max(rows, pile.length));
    return [
      for (var row = 0; row < rows; row++)
        for (final pile in state.cascades)
          if (row < pile.length) pile[row].id,
    ];
  }

  TablePile<FreeCellPile> _pile(
    FreeCellPile ref,
    FreeCellState state,
    _BoardLayout layout,
  ) {
    final cards = state.pile(ref);
    final rect = layout.slotRect(ref);
    final gap = layout.gap / 2;
    final (key, hint) = switch (ref.type) {
      FreeCellPileType.cell => ('freecell-${ref.index}', null),
      FreeCellPileType.foundation => (
        'foundation-${ref.index}',
        SuitIcon(
          Suit.values[ref.index],
          size: layout.cardWidth * 0.45,
          color: Colors.white24,
        ),
      ),
      FreeCellPileType.cascade => ('cascade-${ref.index}', null),
    };
    return TablePile(
      id: ref,
      cards: cards,
      offsets: layout.offsets(ref, cards),
      rect: rect,
      slot: CardSlot(key: ValueKey(key), width: layout.cardWidth, child: hint),
      dropRect: switch (ref.type) {
        FreeCellPileType.cell ||
        FreeCellPileType.foundation => rect.inflate(gap),
        FreeCellPileType.cascade => Rect.fromLTRB(
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
  factory _BoardLayout(Size size) {
    final gap = (size.width * 0.012).clamp(3.0, 12.0);
    final cardWidth = [
      (size.width - gap * 9) / 8,
      // Room for the top row and a cascade of the deal: 1 + 1 + 6 × 0.27
      // card heights.
      (size.height - gap * 4) / (1.4 * 3.7),
      110.0,
    ].reduce(min);
    return _BoardLayout._(gap, cardWidth, size.height);
  }

  _BoardLayout._(this.gap, this.cardWidth, this.height);

  final double gap;
  final double cardWidth;
  final double height;

  double get cardHeight => cardWidth * 1.4;
  double get boardWidth => cardWidth * 8 + gap * 9;
  double get _cascadeTop => gap * 3 + cardHeight;

  /// The visible part of a card under the next one. Narrow cards (a phone,
  /// held upright) have room to show more: bigger targets for a finger.
  double get _step =>
      cardHeight * (cardWidth < CardView.compactWidth ? 0.42 : 0.27);

  double _columnX(int column) => gap + column * (cardWidth + gap);

  Offset slot(FreeCellPile ref) => switch (ref.type) {
    FreeCellPileType.cell => Offset(_columnX(ref.index), gap),
    FreeCellPileType.foundation => Offset(_columnX(4 + ref.index), gap),
    FreeCellPileType.cascade => Offset(_columnX(ref.index), _cascadeTop),
  };

  Rect slotRect(FreeCellPile ref) => slot(ref) & Size(cardWidth, cardHeight);

  List<Offset> offsets(FreeCellPile ref, List<PlayingCard> cards) {
    final origin = slot(ref);
    if (ref.type != FreeCellPileType.cascade || cards.length < 2) {
      return List.filled(cards.length, origin);
    }
    // A long cascade squeezes to stay on the table.
    final room = height - _cascadeTop - cardHeight - gap;
    final step = max(0.0, min(_step, room / (cards.length - 1)));
    return [
      for (var i = 0; i < cards.length; i++) origin.translate(0, i * step),
    ];
  }
}
