import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/games/klondike/playing_card.dart';

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
