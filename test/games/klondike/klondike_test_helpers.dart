import 'dart:math';

import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/klondike/klondike_solver.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';

const _ranks = {'A': 1, 'J': 11, 'Q': 12, 'K': 13};
const _suits = {
  'C': Suit.clubs,
  'D': Suit.diamonds,
  'H': Suit.hearts,
  'S': Suit.spades,
};

/// A card from a short code such as `'KS'`, `'10H'` or `'AD'`.
PlayingCard card(String code, {bool up = true}) {
  final rank = code.substring(0, code.length - 1);
  return PlayingCard(
    _suits[code[code.length - 1]]!,
    _ranks[rank] ?? int.parse(rank),
    faceUp: up,
  );
}

/// Face-up foundations where foundation `i` holds ace to `upTo[i]`.
List<List<PlayingCard>> foundationsUpTo(List<int> upTo) => [
  for (var i = 0; i < 4; i++)
    [
      for (var rank = 1; rank <= upTo[i]; rank++)
        PlayingCard(Suit.values[i], rank, faceUp: true),
    ],
];

/// A board where missing foundations and tableau piles are empty.
KlondikeState board({
  List<PlayingCard> stock = const [],
  List<PlayingCard> waste = const [],
  List<List<PlayingCard>> foundations = const [],
  List<List<PlayingCard>> tableau = const [],
  int drawCount = 1,
}) => KlondikeState(
  stock: stock,
  waste: waste,
  foundations: [
    for (var i = 0; i < 4; i++) i < foundations.length ? foundations[i] : [],
  ],
  tableau: [for (var i = 0; i < 7; i++) i < tableau.length ? tableau[i] : []],
  drawCount: drawCount,
);

/// Random legal moves and draws from [state] (the same ones for the same
/// [seed]) until the solver finds no win: the last one lost the game. At
/// most [limit] of them.
List<KlondikeAction> actionsToLose(
  KlondikeState state, {
  int seed = 1,
  int limit = 300,
}) {
  const solver = KlondikeSolver();
  final random = Random(seed);
  final piles = [
    PileRef.waste,
    for (var i = 0; i < 4; i++) PileRef.foundation(i),
    for (var i = 0; i < 7; i++) PileRef.tableau(i),
  ];
  final actions = <KlondikeAction>[];
  while (actions.length < limit && solver.solve(state).isSolved) {
    final moves = [
      for (final from in piles)
        for (var count = 1; count <= state.pile(from).length; count++)
          for (final to in piles)
            if (state.canMove(from, count, to)) MoveAction(from, count, to),
    ];
    final action = moves.isNotEmpty && random.nextInt(3) > 0
        ? moves[random.nextInt(moves.length)]
        : const DrawAction();
    final next = action.applyTo(state);
    if (next == null) break;
    actions.add(action);
    state = next;
  }
  return actions;
}
