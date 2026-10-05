import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';

const _ranks = {'A': 1, 'J': 11, 'Q': 12, 'K': 13};
const _suits = {
  'C': Suit.clubs,
  'D': Suit.diamonds,
  'H': Suit.hearts,
  'S': Suit.spades,
};

/// A card from a short code such as `'KS'`, `'10H'` or `'AD'`.
PlayingCard card(String code, {bool up = true, int deck = 0}) {
  final rank = code.substring(0, code.length - 1);
  return PlayingCard(
    _suits[code[code.length - 1]]!,
    _ranks[rank] ?? int.parse(rank),
    faceUp: up,
    deck: deck,
  );
}

/// Face-up cards of [suit] from rank [high] down to [low].
List<PlayingCard> run(Suit suit, int high, int low, {int deck = 0}) => [
  for (var rank = high; rank >= low; rank--)
    PlayingCard(suit, rank, faceUp: true, deck: deck),
];

/// A completed run as the foundations keep it: the ace first.
List<PlayingCard> completed(Suit suit, {int deck = 0}) =>
    run(suit, 13, 1, deck: deck).reversed.toList();

/// A board where missing columns are empty.
SpiderState board({
  List<List<PlayingCard>> columns = const [],
  List<PlayingCard> stock = const [],
  List<List<PlayingCard>> runs = const [],
  SpiderDifficulty difficulty = SpiderDifficulty.easy,
}) => SpiderState(
  columns: [
    for (var i = 0; i < SpiderState.columnCount; i++)
      i < columns.length ? columns[i] : const [],
  ],
  stock: stock,
  runs: runs,
  difficulty: difficulty,
);

/// A 1-suit board one move from the win, with all 104 cards: seven runs
/// done, the king to the 2 of spades of deck 7 in the first column and its
/// ace alone in the second.
SpiderState nearWon() => board(
  runs: [
    for (var deck = 0; deck < 7; deck++) completed(Suit.spades, deck: deck),
  ],
  columns: [
    run(Suit.spades, 13, 2, deck: 7),
    [card('AS', deck: 7)],
  ],
);
