import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';

const _ranks = {'A': 1, 'J': 11, 'Q': 12, 'K': 13};
const _suits = {
  'C': Suit.clubs,
  'D': Suit.diamonds,
  'H': Suit.hearts,
  'S': Suit.spades,
};

/// A card from a short code such as `'KS'`, `'10H'` or `'AD'`.
PlayingCard card(String code, {bool faceUp = true}) {
  final rank = code.substring(0, code.length - 1);
  return PlayingCard(
    _suits[code[code.length - 1]]!,
    _ranks[rank] ?? int.parse(rank),
    faceUp: faceUp,
  );
}

List<PlayingCard> cards(String codes, {bool faceUp = true}) => [
  for (final code in codes.split(' '))
    if (code.isNotEmpty) card(code, faceUp: faceUp),
];

/// A board where only the places of [tableau] hold cards, face up when
/// uncovered. [stock] (face down) and [waste] list their cards bottom
/// first: `'2C 9D'` draws the 9♦ first.
TriPeaksState board({
  Map<int, String> tableau = const {},
  String stock = '',
  String waste = 'AS',
}) {
  final places = [
    for (var i = 0; i < TriPeaksState.positions; i++)
      tableau[i] == null ? null : card(tableau[i]!),
  ];
  return TriPeaksState(
    tableau: [
      for (var i = 0; i < TriPeaksState.positions; i++)
        places[i]?.turned(
          faceUp: TriPeaksState.coveredBy[i].every((j) => places[j] == null),
        ),
    ],
    stock: cards(stock, faceUp: false),
    waste: cards(waste),
  );
}
