import 'package:all_for_games/games/tripeaks/tripeaks_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tripeaks_test_helpers.dart';

/// [TriPeaksState.deal] of seed 1, encoded. `deals_on_web_test.dart` checks
/// that the web gives the same deal.
const seed1Deal =
    'Kc4cAcKsJcKd3h3s7c7s7d6s6dQsAd5h8sQd8HQHQC7H9H2D5S8DJSJH,'
    '2c4s5d8c9c9d6c4hKh6hAh2hTc3d5cJd9sThTs4d2sTdAs,3C';

void main() {
  group('deal', () {
    test('28 cards in the peaks, the bottom row face up, one card on the '
        'waste and 23 in the stock', () {
      final state = TriPeaksState.deal(7);
      expect(state.tableau.nonNulls, hasLength(28));
      for (var i = 0; i < 28; i++) {
        expect(state.tableau[i]!.faceUp, i >= 18, reason: 'place $i');
      }
      expect(state.waste.single.faceUp, isTrue);
      expect(state.stock, hasLength(23));
      expect(state.stock.any((card) => card.faceUp), isFalse);
      final ids = {
        for (final card in [
          ...state.tableau.nonNulls,
          ...state.stock,
          ...state.waste,
        ])
          card.id,
      };
      expect(ids, hasLength(52));
    });

    test('is the same for a seed and differs between seeds', () {
      expect(TriPeaksState.deal(1).encode(), seed1Deal);
      expect(TriPeaksState.deal(1).encode(), TriPeaksState.deal(1).encode());
      expect(
        TriPeaksState.deal(1).encode(),
        isNot(TriPeaksState.deal(2).encode()),
      );
    });
  });

  test('each card above the bottom row is covered by the two cards below '
      'it', () {
    final coveredBy = TriPeaksState.coveredBy;
    expect(coveredBy.take(3), [
      [3, 4],
      [5, 6],
      [7, 8],
    ]);
    expect(coveredBy[3], [9, 10]);
    expect(coveredBy[4], [10, 11]);
    expect(coveredBy[5], [12, 13]);
    expect(coveredBy[8], [16, 17]);
    expect(coveredBy[9], [18, 19]);
    expect(coveredBy[17], [26, 27]);
    expect(coveredBy.skip(18), everyElement(isEmpty));
    // The three peaks only meet in the two lowest rows.
    expect(TriPeaksState.covers[11], [4]);
    expect(TriPeaksState.covers[12], [5]);
    expect(TriPeaksState.covers[18], [9]);
    expect(TriPeaksState.covers[19], [9, 10]);
  });

  test('a card fits one rank above or below, the King and the Ace next to '
      'each other', () {
    expect(TriPeaksState.fits(5, 4), isTrue);
    expect(TriPeaksState.fits(5, 6), isTrue);
    expect(TriPeaksState.fits(1, 13), isTrue);
    expect(TriPeaksState.fits(13, 1), isTrue);
    expect(TriPeaksState.fits(12, 13), isTrue);
    expect(TriPeaksState.fits(5, 5), isFalse);
    expect(TriPeaksState.fits(5, 7), isFalse);
    expect(TriPeaksState.fits(2, 13), isFalse);
  });

  group('play', () {
    // The 9♥ at place 9 sits on the 8♣ and the 10♦.
    final state = board(
      tableau: {9: '9H', 18: '8C', 19: '10D', 20: 'KS'},
      waste: '9S',
    );

    test('moves an uncovered card that fits onto the waste', () {
      final next = state.play(18)!;
      expect(next.tableau[18], isNull);
      expect(next.wasteTop, card('8C'));
      expect(next.waste, hasLength(2));
    });

    test('refuses a card that does not fit, a covered card and an empty '
        'place', () {
      expect(state.play(20), isNull, reason: 'K on 9');
      expect(state.play(9), isNull, reason: 'covered');
      expect(state.play(0), isNull, reason: 'empty');
      expect(state.canPlay(9), isFalse);
      expect(state.playable, [18, 19]);
    });

    test('turns a card over once both cards below it are gone', () {
      final half = state.play(18)!;
      expect(half.tableau[9]!.faceUp, isFalse);
      expect(half.isUncovered(9), isFalse);
      // The 9♥ cannot follow the 8♣ while the 10♦ covers it.
      final both = board(
        tableau: {9: '9H', 18: '8C', 19: '7D'},
        waste: '9S',
      ).play(18)!.play(19)!;
      expect(both.tableau[9], card('9H'));
      expect(both.canPlay(9), isFalse, reason: '9 on 7');
      expect(both.isUncovered(9), isTrue);
    });
  });

  test('draw turns the top stock card onto the waste; an empty stock '
      'cannot draw', () {
    final state = board(tableau: {18: '5C'}, stock: '2C 9D', waste: 'KS');
    final next = state.draw()!;
    expect(next.wasteTop, card('9D'));
    expect(next.stock, cards('2C', faceUp: false));
    expect(next.draw()!.draw(), isNull);
  });

  test('won once the peaks are empty; stuck when nothing fits and the '
      'stock is empty', () {
    final last = board(tableau: {18: '5C'}, waste: '4S');
    expect(last.isWon, isFalse);
    expect(last.isStuck, isFalse);
    expect(last.play(18)!.isWon, isTrue);
    expect(last.play(18)!.isStuck, isFalse);

    expect(board(tableau: {18: '5C'}, waste: 'KS').isStuck, isTrue);
    expect(
      board(tableau: {18: '5C'}, stock: '2C', waste: 'KS').isStuck,
      isFalse,
    );
  });

  test('counts the peaks whose top card is gone', () {
    final state = TriPeaksState.deal(3);
    expect(state.peaksCleared, 0);
    expect(board(tableau: {1: 'KS'}).peaksCleared, 2);
  });

  test('collectStock turns the stock onto the waste, top card first', () {
    final state = board(stock: '2C 9D', waste: 'KS').collectStock();
    expect(state.stock, isEmpty);
    expect(state.waste, cards('KS 9D 2C'));
  });

  group('encode', () {
    test('decode gives the same board back', () {
      var state = TriPeaksState.deal(5);
      for (final position in [18, 19, 20, 21, 22, 23, 24, 25, 26, 27]) {
        state = state.play(position) ?? state.draw()!;
      }
      final decoded = TriPeaksState.decode(state.encode());
      expect(decoded.encode(), state.encode());
      expect(decoded.tableau, state.tableau);
      expect(decoded.stock, state.stock);
      expect(decoded.waste, state.waste);
    });

    test('decode throws a FormatException for a bad board', () {
      final good = TriPeaksState.deal(1).encode();
      final [tableau, stock, waste] = good.split(',');
      final invalid = {
        'no commas': tableau,
        'a short tableau': '${tableau.substring(2)},$stock,$waste',
        'a missing card': '$tableau,${stock.substring(2)},$waste',
        'a card twice': '$tableau,${stock.substring(2)}3c,$waste',
        'an empty waste': '$tableau,${stock}3c,',
        'a face-up stock card': '$tableau,${stock.toUpperCase()},$waste',
        'a face-down covered card turned up':
            '${tableau.toUpperCase()},'
            '$stock,$waste',
        'a face-down bottom card': '${tableau.toLowerCase()},$stock,$waste',
        'not a card': '$tableau,${stock}X?,$waste',
      };
      for (final MapEntry(:key, :value) in invalid.entries) {
        expect(
          () => TriPeaksState.decode(value),
          throwsFormatException,
          reason: key,
        );
      }
    });
  });
}
