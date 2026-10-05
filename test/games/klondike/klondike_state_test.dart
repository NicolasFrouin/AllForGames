import 'dart:math';

import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/games/klondike/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'klondike_test_helpers.dart';

PileRef tab(int index) => PileRef.tableau(index);
PileRef fnd(Suit suit) => PileRef.foundation(suit.index);

List<PlayingCard> allCards(KlondikeState state) => [
  ...state.stock,
  ...state.waste,
  for (final pile in state.foundations) ...pile,
  for (final pile in state.tableau) ...pile,
];

void main() {
  test('turned keeps the card id and only changes the face', () {
    final down = card('QH', up: false);
    final up = down.turned(faceUp: true);
    expect(up.id, down.id);
    expect(up, card('QH'));
    expect(up, isNot(down));
  });

  group('card codes', () {
    test('every card reads back from its code, face up or down', () {
      for (final suit in Suit.values) {
        for (var rank = 1; rank <= 13; rank++) {
          for (final faceUp in [true, false]) {
            final card = PlayingCard(suit, rank, faceUp: faceUp);
            expect(PlayingCard.fromCode(card.code), card, reason: card.code);
          }
        }
      }
    });

    test('rank then suit, an uppercase suit for a face-up card', () {
      expect(PlayingCard.fromCode('TH'), card('10H'));
      expect(PlayingCard.fromCode('Kc'), card('KC', up: false));
      expect(card('AS').code, 'AS');
      expect(card('9D', up: false).code, '9d');
    });

    test('anything else is a FormatException', () {
      for (final code in ['', 'T', 'THH', '1H', '10', 'Tx', 'th', 'TX']) {
        expect(
          () => PlayingCard.fromCode(code),
          throwsFormatException,
          reason: code,
        );
      }
    });
  });

  group('encode', () {
    // A deal after some draws and moves: cards in every kind of pile.
    KlondikeState played() {
      var state = KlondikeState.deal(Random(7), drawCount: 3);
      for (var i = 0; i < 30; i++) {
        state = state.draw()!.state;
        if (state.nextFoundationMove() case (:final from, :final to)) {
          state = state.move(from, 1, to)!.state;
        }
      }
      return state;
    }

    test('decode gives back the same board', () {
      for (final state in [
        KlondikeState.deal(Random(1)),
        played(),
        board(foundations: foundationsUpTo([13, 13, 13, 13])),
      ]) {
        final decoded = KlondikeState.decode(
          state.encode(),
          drawCount: state.drawCount,
        );
        expect(decoded.stock, state.stock);
        expect(decoded.waste, state.waste);
        expect(decoded.foundations, state.foundations);
        expect(decoded.tableau, state.tableau);
        expect(decoded.drawCount, state.drawCount);
      }
      expect(played().foundationCardCount, greaterThan(0));
      expect(played().waste, isNotEmpty);
    });

    /// [state] with [cards] taken from their piles and put on foundation [index].
    KlondikeState withFoundation(
      KlondikeState state,
      int index,
      List<PlayingCard> cards,
    ) {
      final ids = {for (final c in cards) c.id};
      List<PlayingCard> rest(List<PlayingCard> pile) => [
        for (final c in pile)
          if (!ids.contains(c.id)) c,
      ];
      return KlondikeState(
        stock: rest(state.stock),
        waste: rest(state.waste),
        foundations: [
          for (var i = 0; i < 4; i++)
            i == index ? cards : rest(state.foundations[i]),
        ],
        tableau: [for (final pile in state.tableau) rest(pile)],
      );
    }

    test('decode rejects text that is not a full valid board', () {
      final deal = KlondikeState.deal(Random(1));
      final good = deal.encode();
      final piles = good.split(',');
      String withPile(int index, String pile) =>
          ([...piles]..[index] = pile).join(',');
      String foundation(List<PlayingCard> cards) =>
          withFoundation(deal, 0, cards).encode();

      expect(
        KlondikeState.decode(
          foundation([card('AC'), card('2C')]),
          drawCount: 1,
        ).foundations[0],
        [card('AC'), card('2C')],
      );
      final invalid = {
        '12 piles': piles.skip(1).join(','),
        '14 piles': '$good,',
        'a missing card': withPile(0, piles[0].substring(2)),
        'a card twice': withPile(1, piles[0].substring(0, 2)),
        'half a card': withPile(0, '${piles[0]}A'),
        'not a card': withPile(0, 'Zz${piles[0].substring(2)}'),
        'a foundation of another suit': foundation([card('AD')]),
        'a foundation out of order': foundation([card('2C'), card('AC')]),
        'a face-down foundation card': foundation([card('AC', up: false)]),
        'empty text': '',
      };
      for (final MapEntry(:key, :value) in invalid.entries) {
        expect(
          () => KlondikeState.decode(value, drawCount: 1),
          throwsFormatException,
          reason: key,
        );
      }
      expect(
        () => KlondikeState.decode(good, drawCount: 2),
        throwsFormatException,
        reason: 'draw 2',
      );
    });
  });

  group('deal', () {
    final state = KlondikeState.deal(Random(42), drawCount: 3);

    test('uses each of the 52 cards once', () {
      expect(allCards(state), hasLength(52));
      expect(allCards(state).map((c) => c.id).toSet(), hasLength(52));
    });

    test('column i has i + 1 cards with only the top one face up', () {
      for (var i = 0; i < 7; i++) {
        final pile = state.tableau[i];
        expect(pile, hasLength(i + 1));
        expect(pile.last.faceUp, isTrue);
        expect(pile.take(i).where((c) => c.faceUp), isEmpty);
      }
    });

    test('puts the other 24 cards face down in the stock', () {
      expect(state.stock, hasLength(24));
      expect(state.stock.where((c) => c.faceUp), isEmpty);
      expect(state.waste, isEmpty);
      expect(state.foundations.expand((pile) => pile), isEmpty);
      expect(state.drawCount, 3);
    });

    test('same seed gives the same deal', () {
      final again = KlondikeState.deal(Random(42), drawCount: 3);
      expect(again.stock, state.stock);
      expect(again.tableau, state.tableau);
      expect(allCards(KlondikeState.deal(Random(43))), isNot(allCards(state)));
    });
  });

  group('canMove', () {
    test('tableau needs the other color', () {
      final s = board(
        tableau: [
          [card('9H')],
          [card('10S')],
          [card('10D')],
        ],
      );
      expect(s.canMove(tab(0), 1, tab(1)), isTrue);
      expect(s.canMove(tab(0), 1, tab(2)), isFalse);
    });

    test('tableau needs exactly one rank higher', () {
      final s = board(
        tableau: [
          [card('9H')],
          [card('JS')],
          [card('8C')],
        ],
      );
      expect(s.canMove(tab(0), 1, tab(1)), isFalse);
      expect(s.canMove(tab(0), 1, tab(2)), isFalse);
    });

    test('only a king goes on an empty tableau pile', () {
      final s = board(
        tableau: [
          [card('KS')],
          [card('QH')],
          [],
        ],
      );
      expect(s.canMove(tab(0), 1, tab(2)), isTrue);
      expect(s.canMove(tab(1), 1, tab(2)), isFalse);
    });

    test('no card goes on a face-down card', () {
      final s = board(
        tableau: [
          [card('9H')],
          [card('10S', up: false)],
        ],
      );
      expect(s.canMove(tab(0), 1, tab(1)), isFalse);
    });

    test('an empty foundation only takes the ace of its suit', () {
      final s = board(
        tableau: [
          [card('AS')],
          [card('2S')],
        ],
      );
      expect(s.canMove(tab(0), 1, fnd(Suit.spades)), isTrue);
      expect(s.canMove(tab(0), 1, fnd(Suit.hearts)), isFalse);
      expect(s.canMove(tab(1), 1, fnd(Suit.spades)), isFalse);
    });

    test('a foundation takes the next rank of its suit only', () {
      final s = board(
        foundations: foundationsUpTo([0, 0, 1, 1]),
        tableau: [
          [card('2S')],
          [card('3S')],
          [card('2H')],
        ],
      );
      expect(s.canMove(tab(0), 1, fnd(Suit.spades)), isTrue);
      expect(s.canMove(tab(1), 1, fnd(Suit.spades)), isFalse);
      expect(s.canMove(tab(2), 1, fnd(Suit.spades)), isFalse);
    });

    test('moves a face-up stack but not a face-down card', () {
      final s = board(
        tableau: [
          [card('KC', up: false), card('9H'), card('8S')],
          [card('10C')],
        ],
      );
      expect(s.canMove(tab(0), 2, tab(1)), isTrue);
      expect(s.canMove(tab(0), 3, tab(1)), isFalse);
    });

    test('waste, foundations and foundation targets take one card', () {
      final s = board(
        waste: [card('9H'), card('8S')],
        foundations: foundationsUpTo([0, 0, 0, 9]),
        tableau: [
          [card('10C')],
          [card('9D')],
          [card('2S'), card('AH')],
        ],
      );
      // Each move would be legal if only the lowest moved card counted.
      expect(s.canMove(PileRef.waste, 2, tab(0)), isFalse);
      expect(s.canMove(fnd(Suit.spades), 2, tab(1)), isFalse);
      final aceOfSpadesOnly = board(
        foundations: foundationsUpTo([0, 0, 0, 1]),
        tableau: [
          [card('2S'), card('AH')],
        ],
      );
      expect(aceOfSpadesOnly.canMove(tab(0), 2, fnd(Suit.spades)), isFalse);
    });

    test('stock is never a source, stock and waste are never targets', () {
      final s = board(
        stock: [card('KS')],
        tableau: [
          [],
          [card('QH')],
        ],
      );
      expect(s.canMove(PileRef.stock, 1, tab(0)), isFalse);
      expect(s.canMove(tab(1), 1, PileRef.stock), isFalse);
      expect(s.canMove(tab(1), 1, PileRef.waste), isFalse);
    });

    test('rejects the same pile, zero cards and too many cards', () {
      final s = board(
        tableau: [
          [card('KS')],
          [],
        ],
      );
      expect(s.canMove(tab(0), 1, tab(0)), isFalse);
      expect(s.canMove(tab(0), 0, tab(1)), isFalse);
      expect(s.canMove(tab(0), 2, tab(1)), isFalse);
    });
  });

  group('move', () {
    test('flips the newly exposed card and adds the reveal bonus', () {
      final s = board(
        tableau: [
          [card('5D', up: false), card('9H')],
          [card('10S')],
        ],
      );
      final result = s.move(tab(0), 1, tab(1))!;
      expect(result.revealed, isTrue);
      expect(result.scoreDelta, KlondikeScoring.revealCard);
      expect(result.state.tableau[0], [card('5D')]);
      expect(result.state.tableau[1], [card('10S'), card('9H')]);
    });

    test('adds the reveal bonus to the foundation score', () {
      final s = board(
        tableau: [
          [card('5D', up: false), card('AS')],
        ],
      );
      final result = s.move(tab(0), 1, fnd(Suit.spades))!;
      expect(result.scoreDelta, 15);
      expect(result.state.foundations[Suit.spades.index], [card('AS')]);
    });

    test('moves a stack in order', () {
      final s = board(
        tableau: [
          [card('9H'), card('8S'), card('7D')],
          [card('10C')],
        ],
      );
      final result = s.move(tab(0), 3, tab(1))!;
      expect(result.revealed, isFalse);
      expect(result.state.tableau[0], isEmpty);
      expect(result.state.tableau[1], [
        card('10C'),
        card('9H'),
        card('8S'),
        card('7D'),
      ]);
    });

    test('returns null for an illegal move and never changes the state', () {
      final s = board(
        tableau: [
          [card('9H')],
          [card('10S')],
        ],
      );
      expect(s.move(tab(1), 1, tab(0)), isNull);
      expect(s.move(tab(0), 1, tab(1)), isNotNull);
      expect(s.tableau[0], [card('9H')]);
      expect(s.tableau[1], [card('10S')]);
    });

    test('scores moves like Windows Solitaire', () {
      final s = board(
        waste: [card('2C')],
        foundations: foundationsUpTo([1, 0, 0, 5]),
        tableau: [
          [card('6H')],
          [card('3D')],
          [card('6S')],
          [card('7C')],
        ],
      );
      final cases = <String, (PileRef, PileRef, int)>{
        'waste to tableau': (PileRef.waste, tab(1), 5),
        'waste to foundation': (PileRef.waste, fnd(Suit.clubs), 10),
        'tableau to foundation': (tab(2), fnd(Suit.spades), 10),
        'foundation to tableau': (fnd(Suit.spades), tab(0), -15),
        'tableau to tableau': (tab(0), tab(3), 0),
      };
      for (final MapEntry(key: name, value: (from, to, score))
          in cases.entries) {
        expect(s.move(from, 1, to)?.scoreDelta, score, reason: name);
      }
    });
  });

  group('draw', () {
    final stock = [
      for (final code in ['AC', '2C', '3C', '4C', '5C']) card(code, up: false),
    ];

    test('draw 1 turns the top stock card onto the waste', () {
      final result = board(stock: stock).draw()!;
      expect(result.recycled, isFalse);
      expect(result.scoreDelta, 0);
      expect(result.state.waste, [card('5C')]);
      expect(result.state.stock, stock.take(4));
    });

    test('draw 3 puts the last drawn card on top of the waste', () {
      final result = board(
        stock: stock,
        waste: [card('KD')],
        drawCount: 3,
      ).draw()!;
      expect(result.state.waste, [
        card('KD'),
        card('5C'),
        card('4C'),
        card('3C'),
      ]);
      expect(result.state.stock, stock.take(2));
    });

    test('draw 3 takes what is left when fewer than 3 cards remain', () {
      final result = board(stock: stock.take(2).toList(), drawCount: 3).draw()!;
      expect(result.state.waste, [card('2C'), card('AC')]);
      expect(result.state.stock, isEmpty);
    });

    for (final (drawCount, penalty) in [(1, -100), (3, -20)]) {
      test('recycle in draw $drawCount turns the waste back face down '
          'and costs ${-penalty} points', () {
        final result = board(
          waste: [card('AC'), card('2C'), card('3C')],
          drawCount: drawCount,
        ).draw()!;
        expect(result.recycled, isTrue);
        expect(result.scoreDelta, penalty);
        expect(result.state.waste, isEmpty);
        expect(result.state.stock, [
          card('3C', up: false),
          card('2C', up: false),
          card('AC', up: false),
        ]);
      });
    }

    test('going through the stock and recycling restores it', () {
      var s = board(stock: stock, drawCount: 3);
      while (s.stock.isNotEmpty) {
        s = s.draw()!.state;
      }
      expect(s.draw()!.state.stock, stock);
    });

    test('returns null when stock and waste are empty', () {
      expect(board().draw(), isNull);
    });
  });

  group('autoTarget', () {
    test('prefers a foundation over any tableau pile', () {
      final s = board(
        foundations: foundationsUpTo([0, 0, 1, 12]),
        tableau: [
          [card('2H')],
          [card('3S')],
          [card('5D', up: false), card('KS')],
          [],
        ],
      );
      expect(s.autoTarget(tab(0), 1), fnd(Suit.hearts));
      expect(s.autoTarget(tab(2), 1), fnd(Suit.spades));
    });

    test('skips piles where the cards do not fit', () {
      final s = board(
        waste: [card('QH')],
        tableau: [
          [],
          [card('KH')],
          [card('KS')],
        ],
      );
      expect(s.autoTarget(PileRef.waste, 1), tab(2));
    });

    test('sends a king to the first empty pile', () {
      final s = board(
        tableau: [
          [card('5D', up: false), card('KS'), card('QH')],
          [card('9C')],
          [],
          [],
        ],
      );
      expect(s.autoTarget(tab(0), 2), tab(2));
    });

    test('keeps a king that is a whole pile where it is', () {
      final s = board(
        tableau: [
          [card('KS'), card('QH')],
          [],
        ],
      );
      expect(s.autoTarget(tab(0), 2), isNull);
    });

    test('returns null without a legal target or without cards', () {
      final s = board(
        tableau: [
          [card('9H')],
          [card('9S')],
        ],
      );
      expect(s.autoTarget(tab(0), 1), isNull);
      expect(s.autoTarget(tab(2), 1), isNull);
    });
  });

  group('nextFoundationMove', () {
    test('picks the lowest card that can move', () {
      final s = board(
        waste: [card('4H')],
        foundations: foundationsUpTo([4, 0, 3, 2]),
        tableau: [
          [card('5C')],
          [card('2D')],
          [card('3S')],
        ],
      );
      expect(s.nextFoundationMove(), (from: tab(2), to: fnd(Suit.spades)));
    });

    test('returns null when no card can go to a foundation', () {
      final s = board(
        tableau: [
          [card('2D')],
        ],
      );
      expect(s.nextFoundationMove(), isNull);
    });
  });

  group('end of game', () {
    final nearlyWon = foundationsUpTo([13, 13, 13, 11]);
    final lastCards = [
      [card('KS')],
      [card('QS')],
    ];

    test('canAutoComplete when only face-up tableau cards are left', () {
      expect(
        board(foundations: nearlyWon, tableau: lastCards).canAutoComplete,
        isTrue,
      );
    });

    test('canAutoComplete is false with a face-down card, stock or waste', () {
      final faceDown = [
        [card('KS')],
        [card('QS', up: false)],
      ];
      expect(
        board(foundations: nearlyWon, tableau: faceDown).canAutoComplete,
        isFalse,
      );
      final withStock = board(
        stock: [card('QS', up: false)],
        foundations: nearlyWon,
        tableau: lastCards.take(1).toList(),
      );
      expect(withStock.canAutoComplete, isFalse);
      final withWaste = board(
        waste: [card('QS')],
        foundations: nearlyWon,
        tableau: lastCards.take(1).toList(),
      );
      expect(withWaste.canAutoComplete, isFalse);
    });

    test('isWon only with all 52 cards on the foundations', () {
      final won = board(foundations: foundationsUpTo([13, 13, 13, 13]));
      expect(won.isWon, isTrue);
      expect(won.canAutoComplete, isFalse);
      expect(board(foundations: nearlyWon, tableau: lastCards).isWon, isFalse);
    });
  });
}
