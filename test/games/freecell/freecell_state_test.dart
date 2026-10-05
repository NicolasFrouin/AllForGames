import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/freecell/freecell_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freecell_test_helpers.dart';

const cell0 = FreeCellPile.cell(0);
const cell1 = FreeCellPile.cell(1);
FreeCellPile col(int index) => FreeCellPile.cascade(index);
FreeCellPile home(Suit suit) => FreeCellPile.foundation(suit.index);

/// The seed 1 deal, also checked on the web by the e2e tests: a seed must
/// give the same deal everywhere.
const seed1Deal =
    ',,,,,,,,KC7C8S5S8C2H4D,4C7SQD8D9CTC2S,AC7D8HJS9D3DTD,KS6SQHJH6C5CAS,'
    'JC6DQC3C4HJD,KDQS7H2CKH9S,3HAD9H4S6HTH,3S5H2D5DAHTS';

void main() {
  group('deal', () {
    test('deals the shuffled deck face up, row by row over 8 cascades', () {
      final state = FreeCellState.deal(42);
      final deck = shuffledDeck(42);
      expect(state.cascades.map((c) => c.length), [7, 7, 7, 7, 6, 6, 6, 6]);
      for (var i = 0; i < 52; i++) {
        expect(state.cascades[i % 8][i ~/ 8].id, deck[i].id);
      }
      final all = state.cascades.expand((c) => c).toList();
      expect(all.every((card) => card.faceUp), isTrue);
      expect(all.map((card) => card.id).toSet(), hasLength(52));
      expect(state.cells, [null, null, null, null]);
      expect(state.foundationCardCount, 0);
    });

    test('gives a fixed deal for a seed', () {
      expect(FreeCellState.deal(1).encode(), seed1Deal);
      expect(FreeCellState.deal(2).encode(), isNot(seed1Deal));
    });
  });

  group('encode and decode', () {
    test('a board survives a round trip', () {
      final state = fullBoard(
        cells: ['KH', null, 'QD'],
        cascades: ['KS QH', '', 'KC', 'KD QS'],
      );
      final text = state.encode();
      final decoded = FreeCellState.decode(text);
      expect(decoded.encode(), text);
      expect(decoded.cells[0], card('KH'));
      expect(decoded.cells[1], isNull);
      expect(decoded.cascades[3], cards('KD QS'));
      expect(decoded.foundations[Suit.hearts.index], hasLength(11));
    });

    test('rejects anything but a full, legal board', () {
      final deal = FreeCellState.deal(3).encode();
      final piles = deal.split(',');
      String withPiles(Map<int, String> changes) =>
          [for (final (i, pile) in piles.indexed) changes[i] ?? pile].join(',');
      final bad = {
        'missing pile': deal.substring(deal.indexOf(',') + 1),
        'missing card': withPiles({8: piles[8].substring(2)}),
        'duplicate card': withPiles({8: piles[8] + piles[9].substring(0, 2)}),
        'face-down card': withPiles({
          8:
              piles[8].substring(0, 1) +
              piles[8][1].toLowerCase() +
              piles[8].substring(2),
        }),
        'two cards in a cell': withPiles({
          0: piles[8].substring(0, 4),
          8: piles[8].substring(4),
        }),
        'not a card': withPiles({8: 'XX${piles[8].substring(2)}'}),
      };
      for (final MapEntry(:key, :value) in bad.entries) {
        expect(
          () => FreeCellState.decode(value),
          throwsFormatException,
          reason: key,
        );
      }
      // A foundation out of order: the 2 of clubs without the ace.
      final twoOfClubs = fullBoard(cascades: ['KC'])
          .encode()
          .replaceFirst('AC2C', '2CAC');
      expect(() => FreeCellState.decode(twoOfClubs), throwsFormatException);
    });
  });

  group('moves', () {
    test('a cascade takes one rank lower in the other colour', () {
      final state = board(cascades: ['9H', '10S', '10D', '8C']);
      expect(state.canMove(col(0), 1, col(1)), isTrue);
      expect(state.canMove(col(0), 1, col(2)), isFalse, reason: 'same colour');
      expect(state.canMove(col(3), 1, col(0)), isTrue);
      expect(state.canMove(col(3), 1, col(1)), isFalse, reason: 'two ranks');
      expect(state.canMove(col(0), 1, col(5)), isTrue, reason: 'empty');

      final next = state.move(col(0), 1, col(1))!;
      expect(next.cascades[1], cards('10S 9H'));
      expect(next.cascades[0], isEmpty);
      expect(state.cascades[0], cards('9H'), reason: 'immutable');
    });

    test('a free cell holds one card', () {
      final state = board(cells: [null, 'KD'], cascades: ['9H 8C']);
      expect(state.canMove(col(0), 1, cell0), isTrue);
      expect(state.canMove(col(0), 1, cell1), isFalse, reason: 'busy');
      expect(state.canMove(col(0), 2, cell0), isFalse, reason: 'two cards');
      expect(state.canMove(cell1, 1, col(2)), isTrue);
      expect(state.canMove(cell1, 1, cell0), isTrue);

      final next = state.move(col(0), 1, cell0)!;
      expect(next.cells, [card('8C'), card('KD'), null, null]);
      expect(next.usedCellCount, 2);
    });

    test('a foundation takes the next card of its suit, and never gives '
        'one back', () {
      final state = board(
        foundations: [1, 0, 0, 0],
        cascades: ['2C', 'AH', '3C'],
      );
      expect(state.canMove(col(0), 1, home(Suit.clubs)), isTrue);
      expect(state.canMove(col(2), 1, home(Suit.clubs)), isFalse);
      expect(state.canMove(col(1), 1, home(Suit.clubs)), isFalse);
      expect(state.canMove(col(1), 1, home(Suit.hearts)), isTrue);
      expect(state.canMove(home(Suit.clubs), 1, col(5)), isFalse);
    });

    test('only a run moves as a whole', () {
      final state = board(cascades: ['5S 9H 8C 7D', '10D', '9S 8D', '10C']);
      expect(FreeCellState.runStart(state.cascades[0]), 1);
      expect(state.canMove(col(0), 3, col(1)), isFalse, reason: 'red on red');
      expect(state.canMove(col(0), 3, col(3)), isTrue);
      expect(state.canMove(col(0), 3, col(5)), isTrue);
      expect(state.canMove(col(0), 4, col(5)), isFalse, reason: 'not a run');
      expect(state.canMove(col(2), 2, col(5)), isTrue);
      expect(state.canMove(col(0), 2, col(2)), isFalse);
      expect(state.canMove(col(0), 1, col(2)), isFalse);
    });

    test('runs are limited to (free cells + 1) × 2^(empty cascades), the '
        'target cascade apart', () {
      // 6 cards long; 2 empty cascades, 1 free cell.
      final state = board(
        cells: ['2C', '3C', '4C'],
        cascades: ['KS 10H 9C 8H 7C 6H 5C', 'JC', 'QD', 'KC', 'KD', 'QC'],
      );
      expect(state.freeCellCount, 1);
      expect(state.emptyCascadeCount, 2);
      expect(state.maxRunLength(toEmptyCascade: false), 8);
      expect(state.maxRunLength(toEmptyCascade: true), 4);
      expect(state.canMove(col(0), 6, col(1)), isTrue);
      expect(state.canMove(col(0), 4, col(6)), isTrue);
      expect(state.canMove(col(0), 5, col(6)), isFalse);

      final full = board(
        cells: ['2C', '3C', '4C', '5D'],
        cascades: ['KS 10H 9C', 'JC', 'QD', 'KC', 'KD', 'QC', 'QH', 'KH'],
      );
      expect(full.maxRunLength(toEmptyCascade: false), 1);
      expect(full.canMove(col(0), 2, col(1)), isFalse);
      expect(full.canMove(col(0), 1, col(1)), isFalse);
    });
  });

  group('tap target', () {
    test('a foundation first', () {
      final state = board(foundations: [1, 0, 0, 0], cascades: ['2C', '3D']);
      expect(state.tapTarget(col(0), 1), home(Suit.clubs));
    });

    test('then the cascade with the longest run', () {
      final state = board(cascades: ['8C', '9D', 'QS 10C 9H']);
      expect(state.tapTarget(col(0), 1), col(2));
    });

    test('then a free cell for one card, then an empty cascade', () {
      final state = board(cells: ['KD'], cascades: ['7C 3H', 'QS', 'QC']);
      expect(state.tapTarget(col(0), 1), cell1);
      expect(state.tapTarget(cell0, 1), col(3), reason: 'not cell to cell');

      final busy = board(
        cells: ['KD', 'KH', 'KC', 'KS'],
        cascades: ['7C 3H', 'QS'],
      );
      expect(busy.tapTarget(col(0), 1), col(2));
    });

    test('never a whole cascade into an empty one', () {
      final state = board(cascades: ['9H 8C', 'KS']);
      expect(state.tapTarget(col(0), 2), isNull);
      expect(state.tapTarget(col(0), 1), cell0);
      expect(state.tapTarget(col(1), 1), cell0);
      final noCell = board(
        cells: ['KD', 'KH', 'KC', 'QD'],
        cascades: ['9H 8C', 'KS'],
      );
      expect(noCell.tapTarget(col(1), 1), isNull);
      expect(noCell.tapTarget(col(0), 1), col(2));
    });

    test('null when the cards cannot move', () {
      final state = board(
        cells: ['KD', 'KH', 'KC', 'QD'],
        cascades: ['5S 9H 8C', 'JS', 'QS', 'JC', 'JH', 'JD', '10D', '10H'],
      );
      expect(state.tapTarget(col(0), 3), isNull, reason: 'not a run');
      expect(state.tapTarget(col(0), 2), isNull);
      expect(state.tapTarget(cell0, 1), isNull);
    });
  });

  group('safe moves to the foundations', () {
    test('aces and twos are always safe', () {
      final state = board(foundations: [1, 0, 0, 0]);
      expect(state.isSafeToFoundation(Suit.hearts, 1), isTrue);
      expect(state.isSafeToFoundation(Suit.clubs, 2), isTrue);
    });

    test('a card is safe when no card left could need it', () {
      // Clubs, diamonds, hearts, spades.
      final state = board(foundations: [4, 3, 3, 1]);
      // The red 4s are home: nothing can go on the 5♣.
      expect(state.isSafeToFoundation(Suit.clubs, 5), isFalse);
      final redsHome = board(foundations: [4, 4, 4, 1]);
      expect(redsHome.isSafeToFoundation(Suit.clubs, 5), isTrue);
      // The 4♦ could still take the 3♠ (spades at 1).
      expect(state.isSafeToFoundation(Suit.diamonds, 4), isFalse);
      // Red foundations at most 2 below and spades at most 3 below.
      final dominance = board(foundations: [4, 3, 3, 2]);
      expect(dominance.isSafeToFoundation(Suit.clubs, 5), isTrue);
    });

    test('the next safe move looks at the cells first', () {
      final state = board(
        cells: [null, 'AH'],
        foundations: [0, 0, 0, 0],
        cascades: ['AC', '5D'],
      );
      expect(state.nextSafeMove(), (from: cell1, to: home(Suit.hearts)));
      final next = state.move(cell1, 1, home(Suit.hearts))!;
      expect(next.nextSafeMove(), (from: col(0), to: home(Suit.clubs)));
      expect(board(cascades: ['5D']).nextSafeMove(), isNull);
    });
  });

  group('finish', () {
    test('a board whose cascades only go down can finish itself', () {
      final state = fullBoard(
        cells: ['QD'],
        cascades: ['KS QH', 'KH QS JC', 'KC KD QC'],
      );
      expect(state.canFinish, isTrue);
      var current = state;
      for (
        var step = current.nextFinishMove();
        step != null;
        step = current.nextFinishMove()
      ) {
        current = current.move(step.from, 1, step.to)!;
      }
      expect(current.isWon, isTrue);
    });

    test('not while a card sits on a lower one', () {
      final state = fullBoard(cascades: ['QH KS', 'KH']);
      expect(state.canFinish, isFalse);
      expect(fullBoard(cascades: []).canFinish, isFalse, reason: 'won');
    });

    test('the lowest free card goes first', () {
      final state = fullBoard(cascades: ['KS QH', 'KH QS', 'KC KD QC QD']);
      expect(state.nextFinishMove(), (from: col(0), to: home(Suit.hearts)));
    });
  });

  test('the win bonus rewards few moves', () {
    expect(FreeCellScoring.winBonus(0), 1000);
    expect(FreeCellScoring.winBonus(100), 500);
    expect(FreeCellScoring.winBonus(400), 0);
  });
}
