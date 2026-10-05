import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/games/spider/spider_difficulty.dart';
import 'package:all_for_games/games/spider/spider_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spider_test_helpers.dart';

/// `SpiderState.deal(1, hard).encode()` on the Dart VM. The e2e tests check
/// the same deal in the web app: the seed lists hold only if the deals are
/// the same everywhere.
const seed1HardDeal =
    '9d1Ah03s05s04h03h0Kc08s05d03c14h1Jd1Qc0Tc16h05h05c09d06d06s1Qd0Kh1Qd1Td0'
    '3d0As0Ts16c05s14s0Qs02d1Ac0Qh02d0Kh0Ad02h08d1Ah1Jd0Js0Kc1Js1Kd19c08h17d1'
    '3h1As1,5h14d0Tc0Th03c0QC1,Ks05c17s19s0Th18C0,2c14s19c1Ac18h03S1,'
    '2s08s17c18d07h14C0,Td1Jh12s1Qh14D1,2c09s18c12h16D1,6s05d19h17h06C1,'
    '6h1Ks19h0Jh07D0,Jc14c17s03d1AD1,7c0Kd0Jc0Qs1TS0';

void main() {
  group('deal', () {
    test('gives the 104 cards of the level: 54 on the columns, 50 in the '
        'stock, only the top of each column face up', () {
      for (final level in SpiderDifficulty.values) {
        final state = SpiderState.deal(7, level);
        expect(
          [for (final column in state.columns) column.length],
          [6, 6, 6, 6, 5, 5, 5, 5, 5, 5],
        );
        expect(state.stock, hasLength(50));
        expect(state.dealsLeft, 5);
        expect(state.runs, isEmpty);
        expect(state.faceDownCount, 44);
        for (final column in state.columns) {
          expect(column.last.faceUp, isTrue);
        }
        expect(state.stock.any((card) => card.faceUp), isFalse);
        final cards = [...state.stock, ...state.columns.expand((c) => c)];
        expect(cards.map((card) => card.id).toSet(), hasLength(104));
        expect(
          cards.map((card) => card.suit).toSet(),
          SpiderState.suitsOf(level).toSet(),
          reason: level.name,
        );
      }
    });

    test('is the same for a seed on every platform', () {
      expect(
        SpiderState.deal(1, SpiderDifficulty.hard).encode(),
        seed1HardDeal,
      );
    });

    test('differs between seeds and between levels', () {
      final ranks = {
        for (final level in SpiderDifficulty.values)
          level: SpiderState.deal(
            3,
            level,
          ).columns.map((column) => column.last.rank).join(','),
      };
      expect(ranks.values.toSet(), hasLength(3));
      expect(
        SpiderState.deal(4, SpiderDifficulty.easy).encode(),
        isNot(SpiderState.deal(3, SpiderDifficulty.easy).encode()),
      );
    });

    test('of deck 0, card ids are the single-deck ones', () {
      final cards = SpiderState.cardsOf(SpiderDifficulty.hard);
      expect(cards.first.id, 'clubs-1');
      expect(cards[52].id, 'clubs-1-1');
      expect(SpiderState.cardsOf(SpiderDifficulty.easy).last.id, 'spades-13-7');
    });
  });

  group('encode and decode', () {
    test('give back the same board', () {
      var state = SpiderState.deal(5, SpiderDifficulty.medium);
      state = state.deal()!;
      expect(
        SpiderState.decode(state.encode(), SpiderDifficulty.medium).encode(),
        state.encode(),
      );
      final won = nearWon().move(1, 1, 0)!;
      final decoded = SpiderState.decode(won.encode(), SpiderDifficulty.easy);
      expect(decoded.runs, won.runs);
      expect(decoded.isWon, isTrue);
    });

    test('refuse boards that are not Spider boards', () {
      final good = SpiderState.deal(5, SpiderDifficulty.medium).encode();
      final columns = good.split(',');
      for (final text in [
        '',
        good.substring(3),
        // A spade where a heart was: one card twice.
        good.replaceFirst('h', 's'),
        // Every spade face up, in the stock too.
        good.replaceAll('s', 'S'),
        // A face-up card in the stock.
        '${columns[0].substring(0, 1)}${columns[0][1].toUpperCase()}'
            '${columns[0].substring(2)},${columns.skip(1).join(',')}',
        // A face-down card on top of a column.
        [columns[0], columns[1].toLowerCase(), ...columns.skip(2)].join(','),
      ]) {
        expect(
          () => SpiderState.decode(text, SpiderDifficulty.medium),
          throwsFormatException,
          reason: text,
        );
      }
      // Hearts in a 1-suit game.
      expect(
        () => SpiderState.decode(good, SpiderDifficulty.easy),
        throwsFormatException,
      );
    });
  });

  group('moves', () {
    final hearts = run(Suit.hearts, 9, 7);

    test('a run of one suit goes on a card one rank higher, any suit', () {
      final state = board(
        columns: [
          [card('3C', up: false), ...hearts],
          [card('10S')],
          [card('10H')],
          [card('9C')],
        ],
      );
      expect(state.canMove(0, 3, 1), isTrue);
      expect(state.canMove(0, 3, 2), isTrue);
      expect(state.canMove(0, 3, 3), isFalse, reason: 'a 9 on a 9');
      expect(state.canMove(0, 4, 1), isFalse, reason: 'a face-down card');
      expect(state.canMove(0, 2, 3), isTrue, reason: 'the 8 and the 7');
      expect(state.canMove(0, 3, 0), isFalse);
      expect(state.canMove(0, 3, 4), isTrue, reason: 'an empty column');

      final next = state.move(0, 3, 1)!;
      expect(next.columns[1], [card('10S'), ...hearts]);
      expect(next.columns[0], [card('3C')], reason: 'turned face up');
      expect(state.columns[0].first.faceUp, isFalse, reason: 'immutable');
    });

    test('cards of different suits do not move together', () {
      final state = board(
        columns: [
          [card('9H'), card('8S')],
          [card('10D')],
          [],
        ],
      );
      expect(state.canMove(0, 2, 1), isFalse);
      expect(state.canMove(0, 2, 2), isFalse);
      expect(state.canMove(0, 1, 2), isTrue);
      expect(state.move(0, 2, 1), isNull);
    });

    test('a completed run leaves the column at once', () {
      final state = board(
        columns: [
          [card('5D', up: false), ...run(Suit.spades, 13, 4)],
          [card('2H'), ...run(Suit.spades, 3, 1, deck: 1)],
        ],
      );
      final next = state.move(1, 3, 0)!;
      expect(next.columns[0], [card('5D')]);
      expect(next.columns[1], [card('2H')]);
      expect(next.runs, hasLength(1));
      expect(next.runs.single.first, card('AS', deck: 1), reason: 'ace first');
      expect(next.runs.single.last, card('KS'));
    });

    test('a king to ace of mixed suits is not a run', () {
      final mixed = [...run(Suit.spades, 13, 2), card('AH')];
      final state = board(
        columns: [
          mixed.sublist(0, 12),
          [card('AH')],
        ],
      );
      expect(state.move(1, 1, 0)!.columns[0], mixed);
    });
  });

  group('stock', () {
    final stock = [
      for (var i = 0; i < 20; i++) card('${i % 13 + 1}C', up: false, deck: i),
    ];
    final full = [
      for (var i = 0; i < 10; i++) [card('KH', deck: i)],
    ];

    test('deals one card face up on each column, from the top', () {
      final state = board(columns: full, stock: stock);
      expect(state.dealsLeft, 2);
      final next = state.deal()!;
      expect(next.stock, stock.sublist(0, 10));
      expect(next.dealsLeft, 1);
      for (var i = 0; i < 10; i++) {
        expect(next.columns[i].last, stock[19 - i].turned(faceUp: true));
      }
    });

    test('needs a card on every column', () {
      final state = board(columns: full.sublist(0, 9), stock: stock);
      expect(state.canDeal, isFalse);
      expect(state.deal(), isNull);
      expect(board(columns: full).deal(), isNull, reason: 'no stock');
    });

    test('a dealt card can complete a run', () {
      final state = board(
        columns: [run(Suit.spades, 13, 2), ...full.sublist(1)],
        stock: [
          for (var i = 0; i < 9; i++) card('KC', up: false, deck: i),
          card('AS', up: false),
        ],
      );
      final next = state.deal()!;
      expect(next.columns[0], isEmpty);
      expect(next.runs.single.first, card('AS'));
    });
  });

  test('the game is won when every card is in a run', () {
    final state = nearWon();
    expect(state.isWon, isFalse);
    final won = state.move(1, 1, 0)!;
    expect(won.isWon, isTrue);
    expect(won.runs, hasLength(8));
  });

  group('autoTarget', () {
    test('prefers a card of the same suit, the longest run first', () {
      final state = board(
        columns: [
          [card('6H')],
          [card('7S')],
          [card('9H'), card('8H'), card('7H', deck: 1)],
          [card('7H')],
          [],
        ],
      );
      expect(state.autoTarget(0, 1), 2);
    });

    test('then any card one rank higher, then an empty column', () {
      final state = board(
        columns: [
          [card('2C', up: false), card('6H')],
          [card('9D')],
          [],
          [card('7S')],
        ],
      );
      expect(state.autoTarget(0, 1), 3);
      expect(
        board(
          columns: [
            [card('2C', up: false), card('6H')],
            [card('9D')],
            [],
          ],
        ).autoTarget(0, 1),
        2,
      );
    });

    test('never moves a whole column to an empty one', () {
      final state = board(
        columns: [
          [card('6H')],
          [],
        ],
      );
      expect(state.autoTarget(0, 1), isNull);
      expect(state.autoTarget(1, 1), isNull);
    });
  });

  test('scoring: 500, a point per move, deal or undo, 100 per run', () {
    expect(SpiderScoring.score(moves: 0, undos: 0, runs: 0), 500);
    expect(SpiderScoring.score(moves: 12, undos: 3, runs: 2), 685);
    expect(SpiderScoring.score(moves: 600, undos: 0, runs: 0), 0);
  });
}
