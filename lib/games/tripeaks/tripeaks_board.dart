import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../cards/card_table.dart';
import '../../skins/card_backs.dart';
import 'tripeaks_controller.dart';
import 'tripeaks_state.dart';

/// Pile ids on the [CardTable]: the tableau places are `0` to `27`, in
/// paint order (a lower row covers the row above it), then the stock and the
/// waste.
const _stock = TriPeaksState.positions;
const _waste = TriPeaksState.positions + 1;

/// From the stock to the peaks, row by row from the top.
const _dealStyle = MotionStyle(
  stagger: 26,
  duration: 300,
  curve: Curves.easeOutCubic,
  arc: 0.1,
  maxArc: 0.3,
);

/// A card from the peaks flies onto the waste on a high arc.
const _playStyle = MotionStyle(arc: 0.2, maxArc: 0.6);
const _drawStyle = MotionStyle(
  duration: 300,
  curve: Curves.easeOutCubic,
  arc: 0.1,
);

/// The bonus of a win: the cards left in the stock turn onto the waste one
/// after the other.
const _bonusStyle = MotionStyle(
  stagger: 70,
  duration: 300,
  curve: Curves.easeInOutCubic,
  arc: 0.1,
);

/// The TriPeaks table on a [CardTable]: the layout of the three peaks, the
/// stock and the waste, what a tap does and the rhythm of each action.
class TriPeaksBoard extends StatelessWidget {
  const TriPeaksBoard({
    super.key,
    required this.controller,
    required this.cardBack,
    this.onCelebrated,
  });

  final TriPeaksController controller;

  /// The look of the face-down cards.
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
            child: CardTable<int>(
              size: layout.size,
              cardWidth: layout.cardWidth,
              cardBack: cardBack,
              piles: [
                for (var i = 0; i < TriPeaksState.positions; i++)
                  _peakPile(i, state, layout),
                _stockPile(state, layout),
                _wastePile(state, layout),
              ],
              action: _action(state),
              canTap: _canTap,
              onTap: _tap,
              onSlotTap: (pile) {
                if (pile == _stock) controller.draw();
              },
              celebration: controller.result == null ? null : const [_waste],
              onCelebrated: onCelebrated,
            ),
          );
        },
      ),
    );
  }

  /// A face-up card of the peaks plays, or shakes when it does not fit; the
  /// stock draws.
  bool _canTap(int pile, int index) => switch (pile) {
    _stock => true,
    _waste => false,
    _ => controller.state.tableau[pile]?.faceUp ?? false,
  };

  bool _tap(int pile, int index) {
    if (pile == _stock) {
      controller.draw();
      return true;
    }
    return controller.play(pile);
  }

  TableAction<int> _action(TriPeaksState state) {
    final serial = controller.actionSerial;
    final moved = controller.lastMovedCardIds;
    final bonus = controller.lastBonusCount;
    return switch (controller.lastAction) {
      TriPeaksAction.deal => TableAction(
        serial,
        cardIds: [
          for (final card in state.tableau) ?card?.id,
          state.wasteTop.id,
        ],
        style: _dealStyle,
        dealFrom: _stock,
      ),
      TriPeaksAction.play => TableAction(
        serial,
        cardIds: moved.sublist(0, moved.length - bonus),
        style: _playStyle,
        thenIds: moved.sublist(moved.length - bonus),
        thenStyle: _bonusStyle,
      ),
      TriPeaksAction.draw => TableAction(
        serial,
        cardIds: moved,
        style: _drawStyle,
      ),
      TriPeaksAction.none ||
      TriPeaksAction.undo => TableAction(serial, cardIds: moved),
    };
  }

  TablePile<int> _peakPile(int i, TriPeaksState state, _BoardLayout layout) {
    final rect = layout.peakRect(i);
    return TablePile(
      id: i,
      cards: [?state.tableau[i]],
      offsets: [if (state.tableau[i] != null) rect.topLeft],
      rect: rect,
    );
  }

  TablePile<int> _stockPile(TriPeaksState state, _BoardLayout layout) {
    return TablePile(
      id: _stock,
      cards: state.stock,
      offsets: layout.stockOffsets(state.stock.length),
      rect: layout.stockRect,
      slot: CardSlot(
        key: const ValueKey('stock'),
        width: layout.cardWidth,
        // No redeal: an empty stock is done.
        child: Icon(
          Icons.block,
          color: Colors.white38,
          size: layout.cardWidth * 0.45,
        ),
      ),
    );
  }

  /// Only the top cards of the waste and the cards of the last action are on
  /// the table: the others are hidden under them, and dozens of stacked
  /// shadows would darken the edges of the pile. Four cards, so quick taps
  /// never uncover the empty slot under cards still in the air.
  TablePile<int> _wastePile(TriPeaksState state, _BoardLayout layout) {
    final rect = layout.wasteRect;
    final moved = controller.lastMovedCardIds;
    final shown = [
      for (final (i, card) in state.waste.indexed)
        if (i >= state.waste.length - 4 || moved.contains(card.id)) card,
    ];
    return TablePile(
      id: _waste,
      cards: shown,
      offsets: List.filled(shown.length, rect.topLeft),
      rect: rect,
      slot: CardSlot(key: const ValueKey('waste'), width: layout.cardWidth),
    );
  }
}

/// Card size and card positions for a given board size: the three peaks,
/// then the stock fanned on the left and the waste in the middle below them.
///
/// The bottom row is ten cards wide: on a narrow screen the cards of a row
/// overlap, each leaving its corner index visible.
class _BoardLayout {
  factory _BoardLayout(Size size) {
    final gap = (size.width * 0.012).clamp(3.0, 10.0);
    final cardWidth = [
      (size.width - gap * 2) / (_minStep * 9 + 1),
      // The peaks (three half-card steps and a card), the space below them
      // and the stock row.
      (size.height - gap * 2) / (1.4 * (1.5 + 1 + _rowGap + 1)),
      120.0,
    ].reduce(min);
    final step = min(cardWidth + gap, (size.width - gap * 2 - cardWidth) / 9);
    return _BoardLayout._(gap, max(cardWidth, 10), max(step, 1));
  }

  _BoardLayout._(this.gap, this.cardWidth, this.step);

  /// The least distance between two cards of a row, in card widths: enough
  /// for the compact corner index.
  static const _minStep = 0.66;

  /// Between the peaks and the stock row, in card heights.
  static const _rowGap = 0.3;

  final double gap;
  final double cardWidth;

  /// Distance between two cards of the bottom row.
  final double step;

  double get cardHeight => cardWidth * 1.4;
  Size get cardSize => Size(cardWidth, cardHeight);
  double get _rowStep => cardHeight * 0.5;
  double get _stockTop => gap + _rowStep * 3 + cardHeight * (1 + _rowGap);

  Size get size =>
      Size(gap * 2 + step * 9 + cardWidth, _stockTop + cardHeight + gap);

  /// Place [i] of the tableau, in steps of the bottom row from its left.
  static double _column(int i) => switch (i) {
    < 3 => 3.0 * i + 1.5,
    < 9 => 3.0 * ((i - 3) ~/ 2) + 1 + (i - 3) % 2,
    < 18 => i - 9 + 0.5,
    _ => i - 18.0,
  };

  static int _row(int i) => switch (i) {
    < 3 => 0,
    < 9 => 1,
    < 18 => 2,
    _ => 3,
  };

  Rect peakRect(int i) =>
      Offset(gap + _column(i) * step, gap + _row(i) * _rowStep) & cardSize;

  Rect get wasteRect =>
      Offset((size.width - cardWidth) / 2, _stockTop) & cardSize;

  Rect get stockRect => Offset(gap, _stockTop) & cardSize;

  /// The stock fanned to the right from its bottom card, so the player sees
  /// how many cards are left: the top card is the rightmost.
  List<Offset> stockOffsets(int count) {
    const most = 22;
    final room = wasteRect.left - gap * 2 - cardWidth - stockRect.left;
    final fan = max(0.0, min(cardWidth * 0.12, room / most));
    return [
      for (var i = 0; i < count; i++) stockRect.topLeft.translate(i * fan, 0),
    ];
  }
}
