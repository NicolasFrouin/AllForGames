import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decks', () {
    test('a card of deck 0 keeps the single-deck id', () {
      expect(const PlayingCard(Suit.hearts, 12).id, 'hearts-12');
      expect(const PlayingCard(Suit.hearts, 12, deck: 3).id, 'hearts-12-3');
    });

    test('copies of a card from two decks are different cards', () {
      const first = PlayingCard(Suit.spades, 1, faceUp: true);
      const second = PlayingCard(Suit.spades, 1, faceUp: true, deck: 1);
      expect(first, isNot(second));
      expect({first, second}, hasLength(2));
      expect(second, const PlayingCard(Suit.spades, 1, faceUp: true, deck: 1));
      expect(second.turned(faceUp: false).deck, 1);
      expect(second.turned(faceUp: false).id, second.id);
    });
  });

  group('shuffledCards', () {
    final deck = [
      for (final suit in Suit.values)
        for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank),
    ];

    test('shuffles like shuffledDeck', () {
      expect(shuffledCards(42, deck), shuffledDeck(42));
      expect(shuffledCards(7, deck), shuffledDeck(7));
    });

    test('keeps every item, in a fixed order for a seed', () {
      final items = List.generate(104, (i) => i);
      final shuffled = shuffledCards(3, items);
      expect(shuffled.toSet(), items.toSet());
      expect(shuffled, shuffledCards(3, items));
      expect(shuffled, isNot(items));
      expect(shuffled, isNot(shuffledCards(4, items)));
      expect(items, List.generate(104, (i) => i), reason: 'a copy');
    });
  });
}
