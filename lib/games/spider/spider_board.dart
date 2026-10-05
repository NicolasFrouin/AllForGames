import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../cards/card_table.dart';
import '../../cards/card_view.dart';
import '../../cards/playing_card.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'spider_controller.dart';
import 'spider_state.dart';

enum SpiderPileKind { stock, foundation, column }

/// A pile of the Spider table: the stock, foundation `i` (completed run `i`)
/// or column `i`.
typedef SpiderPile = ({SpiderPileKind kind, int index});

const _stock = (kind: SpiderPileKind.stock, index: 0);
SpiderPile _foundation(int index) =>
    (kind: SpiderPileKind.foundation, index: index);
SpiderPile _column(int index) => (kind: SpiderPileKind.column, index: index);

/// Row by row from the stock, like a real deal.
const _dealStyle = MotionStyle(
  stagger: 22,
  duration: 280,
  curve: Curves.easeOutCubic,
  arc: 0.1,
  maxArc: 0.3,
);

/// One card for each column, from left to right.
const _stockDealStyle = MotionStyle(
  stagger: 55,
  duration: 300,
  curve: Curves.easeOutCubic,
);

/// A completed run leaves card after card, the ace first.
const _runStyle = MotionStyle(
  stagger: 45,
  duration: 320,
  curve: Curves.easeInOutCubic,
);

/// The Spider table on a [CardTable]: the layout of the piles, what the
/// player can do with each card, and the rhythm of each action.
class SpiderBoard extends StatelessWidget {
  const SpiderBoard({
    super.key,
    required this.controller,
    required this.cardBack,
    this.onCelebrated,
  });

  final SpiderController controller;

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
          final layout = _SpiderLayout(constraints.biggest);
          final stockTop = state.stock.isEmpty
              ? null
              : layout.stockOffsets(state.stock.length).last;
          return Center(
            child: SizedBox(
              width: layout.boardWidth,
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CardTable<SpiderPile>(
                    size: Size(layout.boardWidth, layout.height),
                    cardWidth: layout.cardWidth,
                    cardBack: cardBack,
                    piles: [
                      for (var i = 0; i < SpiderState.runCount; i++)
                        _foundationPile(i, state, layout),
                      for (var i = 0; i < SpiderState.columnCount; i++)
                        _columnPile(i, state, layout),
                      _stockPile(state, layout),
                    ],
                    action: _action(state, layout),
                    canDrag: _canDrag,
                    canTap: _canTap,
                    onTap: (pile, index) => _tap(context, pile, index),
                    canDrop: (from, index, to) =>
                        to.kind == SpiderPileKind.column &&
                        controller.state.canMove(
                          from.index,
                          _countFrom(from, index),
                          to.index,
                        ),
                    onDrop: (from, index, to) => controller.move(
                      from.index,
                      _countFrom(from, index),
                      to.index,
                    ),
                    celebration: controller.result == null
                        ? null
                        : [
                            for (var i = 0; i < SpiderState.runCount; i++)
                              _foundation(i),
                          ],
                    onCelebrated: onCelebrated,
                  ),
                  if (stockTop != null)
                    Positioned(
                      left: stockTop.dx + layout.cardWidth - layout.badge * 0.6,
                      top: stockTop.dy + layout.cardHeight - layout.badge * 0.6,
                      child: IgnorePointer(
                        child: _DealsBadge(
                          count: state.dealsLeft,
                          size: layout.badge,
                          label: l10n.spiderDealsLeft(state.dealsLeft),
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

  int _countFrom(SpiderPile pile, int index) =>
      controller.state.columns[pile.index].length - index;

  bool _canDrag(SpiderPile pile, int index) =>
      pile.kind == SpiderPileKind.column &&
      controller.state.canPick(pile.index, _countFrom(pile, index));

  /// The stock deals; a face-up card of a column moves, or shakes when it
  /// cannot.
  bool _canTap(SpiderPile pile, int index) => switch (pile.kind) {
    SpiderPileKind.stock => true,
    SpiderPileKind.foundation => false,
    SpiderPileKind.column => controller.state.columns[pile.index][index].faceUp,
  };

  bool _tap(BuildContext context, SpiderPile pile, int index) {
    if (pile.kind == SpiderPileKind.stock) {
      if (controller.dealStock()) return true;
      if (controller.result == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).spiderDealNeedsCards),
            ),
          );
      }
      return false;
    }
    return controller.tap(pile.index, _countFrom(pile, index));
  }

  TableAction<SpiderPile> _action(SpiderState state, _SpiderLayout layout) {
    final serial = controller.actionSerial;
    final moved = controller.lastMovedCardIds;
    final (stops, thenIds) = _runSteps(state, layout);
    return switch (controller.lastAction) {
      SpiderAction.deal => TableAction(
        serial,
        cardIds: _dealOrder(state),
        style: _dealStyle,
        dealFrom: _stock,
      ),
      SpiderAction.stockDeal => TableAction(
        serial,
        cardIds: moved,
        style: _stockDealStyle,
        stops: stops,
        thenIds: thenIds,
        thenStyle: _runStyle,
      ),
      SpiderAction.move => TableAction(
        serial,
        cardIds: moved,
        stops: stops,
        thenIds: thenIds,
        thenStyle: _runStyle,
      ),
      SpiderAction.none ||
      SpiderAction.undo => TableAction(serial, cardIds: moved),
    };
  }

  /// The runs that the last action completed first land on their column,
  /// then leave for the foundations, the ace first; the card they uncover
  /// turns over after them.
  (Map<String, CardStop<SpiderPile>>, List<String>) _runSteps(
    SpiderState state,
    _SpiderLayout layout,
  ) {
    final stops = <String, CardStop<SpiderPile>>{};
    final thenIds = <String>[];
    for (final run in controller.lastCompletedRuns) {
      final below = [...state.columns[run.column]];
      if (run.revealedId != null && below.isNotEmpty) {
        below.last = below.last.turned(faceUp: false);
      }
      final column = [...below, ...run.cards];
      final offsets = layout.columnOffsets(column, column: run.column);
      for (var i = below.length; i < column.length; i++) {
        stops[column[i].id] = CardStop(_column(run.column), i, offsets[i]);
      }
      thenIds.addAll(run.cards.reversed.map((card) => card.id));
      if (run.revealedId case final id?) thenIds.add(id);
    }
    return (stops, thenIds);
  }

  /// The column cards, row by row from the left.
  static List<String> _dealOrder(SpiderState state) {
    final rows = state.columns.fold(
      0,
      (rows, column) => max(rows, column.length),
    );
    return [
      for (var row = 0; row < rows; row++)
        for (final column in state.columns)
          if (row < column.length) column[row].id,
    ];
  }

  TablePile<SpiderPile> _stockPile(SpiderState state, _SpiderLayout layout) {
    return TablePile(
      id: _stock,
      cards: state.stock,
      offsets: layout.stockOffsets(state.stock.length),
      rect: layout.stockRect,
      slot: CardSlot(
        key: const ValueKey('stock'),
        width: layout.cardWidth,
        child: Icon(
          Icons.block,
          color: Colors.white38,
          size: layout.cardWidth * 0.45,
        ),
      ),
    );
  }

  TablePile<SpiderPile> _foundationPile(
    int index,
    SpiderState state,
    _SpiderLayout layout,
  ) {
    final rect = layout.foundationRect(index);
    final cards = index < state.runs.length
        ? state.runs[index]
        : const <PlayingCard>[];
    return TablePile(
      id: _foundation(index),
      cards: cards,
      offsets: List.filled(cards.length, rect.topLeft),
      rect: rect,
      slot: CardSlot(
        key: ValueKey('foundation-$index'),
        width: layout.cardWidth,
      ),
    );
  }

  TablePile<SpiderPile> _columnPile(
    int index,
    SpiderState state,
    _SpiderLayout layout,
  ) {
    final rect = layout.columnRect(index);
    final gap = layout.gap / 2;
    final cards = state.columns[index];
    return TablePile(
      id: _column(index),
      cards: cards,
      offsets: layout.columnOffsets(cards, column: index),
      rect: rect,
      slot: CardSlot(key: ValueKey('column-$index'), width: layout.cardWidth),
      dropRect: Rect.fromLTRB(
        rect.left - gap,
        rect.top - gap,
        rect.right + gap,
        layout.height,
      ),
    );
  }
}

/// How many deals the stock has left, on its top card.
class _DealsBadge extends StatelessWidget {
  const _DealsBadge({
    required this.count,
    required this.size,
    required this.label,
  });

  final int count;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3A2A00), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$count',
          key: const ValueKey('deals-left'),
          style: TextStyle(
            color: const Color(0xFF3A2A00),
            fontSize: size * 0.6,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Card size and card positions for a given board size: the stock and the
/// eight foundations on the top row, the ten columns below.
class _SpiderLayout {
  factory _SpiderLayout(Size size) {
    final gap = (size.width * 0.01).clamp(3.0, 10.0);
    final cardWidth = [
      (size.width - gap * 11) / 10,
      // Room for the top row and columns of a dozen cards.
      (size.height - gap * 3) / (1.4 * 4),
      100.0,
    ].reduce(min);
    return _SpiderLayout._(gap, max(cardWidth, 10), size.height);
  }

  _SpiderLayout._(this.gap, this.cardWidth, this.height);

  final double gap;
  final double cardWidth;
  final double height;

  double get cardHeight => cardWidth * 1.4;
  Size get cardSize => Size(cardWidth, cardHeight);
  double get boardWidth => cardWidth * 10 + gap * 11;
  double get _columnsTop => gap * 2 + cardHeight;

  /// Diameter of the badge of deals left.
  double get badge => max(16, cardWidth * 0.36);

  double _x(int column) => gap + column * (cardWidth + gap);

  Rect get stockRect => Offset(_x(0), gap) & cardSize;
  Rect foundationRect(int index) => Offset(_x(2 + index), gap) & cardSize;
  Rect columnRect(int index) => Offset(_x(index), _columnsTop) & cardSize;

  /// One stack per deal left, fanned to the right: the top deal is the
  /// rightmost.
  List<Offset> stockOffsets(int count) => [
    for (var i = 0; i < count; i++)
      Offset(_x(0) + (i ~/ SpiderState.columnCount) * cardWidth * 0.18, gap),
  ];

  /// Cards fanned down the column, face-down ones closer; a long column
  /// closes up to fit the board.
  List<Offset> columnOffsets(List<PlayingCard> cards, {int column = 0}) {
    final compact = cardWidth < CardView.compactWidth;
    final up = cardHeight * (compact ? 0.3 : 0.25);
    final down = cardHeight * (compact ? 0.12 : 0.1);
    final steps = [
      for (var i = 0; i < cards.length - 1; i++) cards[i].faceUp ? up : down,
    ];
    final total = steps.fold(0.0, (sum, step) => sum + step);
    final room = height - _columnsTop - cardHeight - gap;
    final scale = total > room && total > 0 ? max(0.0, room / total) : 1.0;
    final origin = columnRect(column).topLeft;
    final offsets = <Offset>[];
    var y = origin.dy;
    for (var i = 0; i < cards.length; i++) {
      offsets.add(Offset(origin.dx, y));
      if (i < steps.length) y += steps[i] * scale;
    }
    return offsets;
  }
}
