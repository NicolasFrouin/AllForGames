import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';

const _ranks = {'A': 1, 'J': 11, 'Q': 12, 'K': 13};
const _suits = {
  'C': Suit.clubs,
  'D': Suit.diamonds,
  'H': Suit.hearts,
  'S': Suit.spades,
};

/// A face-up card from a short code such as `'KS'`, `'10H'` or `'AD'`.
PlayingCard card(String code) {
  final rank = code.substring(0, code.length - 1);
  return PlayingCard(
    _suits[code[code.length - 1]]!,
    _ranks[rank] ?? int.parse(rank),
    faceUp: true,
  );
}

List<PlayingCard> cards(String codes) =>
    codes.split(' ').where((code) => code.isNotEmpty).map(card).toList();

/// Foundations where foundation `i` holds ace to `upTo[i]`.
List<List<PlayingCard>> foundationsUpTo(List<int> upTo) => [
  for (var i = 0; i < 4; i++)
    [
      for (var rank = 1; rank <= upTo[i]; rank++)
        PlayingCard(Suit.values[i], rank, faceUp: true),
    ],
];

/// A board where missing cells, foundations and cascades are empty. Each
/// cascade is a string of card codes, bottom first: `'KS QH'`.
FreeCellState board({
  List<String?> cells = const [],
  List<int> foundations = const [0, 0, 0, 0],
  List<String> cascades = const [],
}) => FreeCellState(
  cells: [
    for (var i = 0; i < 4; i++)
      i < cells.length && cells[i] != null ? card(cells[i]!) : null,
  ],
  foundations: foundationsUpTo(foundations),
  cascades: [
    for (var i = 0; i < 8; i++) i < cascades.length ? cards(cascades[i]) : [],
  ],
);

/// A board with the 52 cards: the cards of [cells] and [cascades], and on
/// the foundations every card below them in their suit. The cards out must
/// be the highest ones of their suit.
FreeCellState fullBoard({
  List<String?> cells = const [],
  List<String> cascades = const [],
}) {
  final out = [
    for (final cell in cells) ?cell,
    for (final cascade in cascades) cascade,
  ].expand((codes) => cards(codes)).toList();
  final heights = [
    for (final suit in Suit.values)
      out
          .where((card) => card.suit == suit)
          .fold(13, (low, card) => card.rank - 1 < low ? card.rank - 1 : low),
  ];
  final state = board(cells: cells, foundations: heights, cascades: cascades);
  assert(state.foundationCardCount + out.length == 52, 'missing cards');
  return state;
}
