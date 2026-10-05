import 'package:all_for_games/cards/deal_random.dart';
import 'package:all_for_games/games/klondike/klondike_deals.dart';
import 'package:all_for_games/games/klondike/klondike_difficulty.dart';
import 'package:all_for_games/games/klondike/klondike_solver.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'klondike_test_helpers.dart';

const solver = KlondikeSolver();

bool replaysToWin(KlondikeState state, List<KlondikeAction> actions) =>
    replayActions(state, actions)?.isWon ?? false;

/// Wins by Q♦ onto K♣, a draw for Q♣, then K♦ into the emptied column.
KlondikeState nearWon({int drawCount = 1}) => board(
  stock: [card('QC', up: false)],
  foundations: foundationsUpTo([10, 10, 13, 13]),
  tableau: [
    [card('JC', up: false), card('QD')],
    [card('KC')],
    [card('JD', up: false), card('KD')],
  ],
  drawCount: drawCount,
);

void main() {
  group('deal random', () {
    List<int> firstNumbers(int seed) {
      final random = DealRandom(seed);
      return [for (var i = 0; i < 5; i++) random.nextUint32()];
    }

    // Also computed by an independent implementation: a different value on
    // the web (dart2js, dart2wasm) or after a change breaks the seed lists.
    test('gives a fixed sequence for a seed', () {
      expect(firstNumbers(1), [
        524866043,
        2877414208,
        2380002740,
        2664205378,
        3890067424,
      ]);
      expect(firstNumbers(0xFFFFFFFF), [
        785727346,
        2925282831,
        4113243489,
        1181332066,
        1956414576,
      ]);
      // Seed 0 hashes to 0, the state xorshift never leaves.
      expect(firstNumbers(0), [
        1085196063,
        2447379481,
        2618286376,
        1701901981,
        265159372,
      ]);
    });

    test('shuffledDeck gives the 52 cards face down in a fixed order', () {
      final deck = shuffledDeck(42);
      expect(deck.map((c) => c.id).toSet(), hasLength(52));
      expect(deck.every((c) => !c.faceUp), isTrue);
      expect(deck.take(10).map((c) => c.id), [
        'diamonds-2',
        'spades-4',
        'spades-2',
        'hearts-6',
        'spades-1',
        'clubs-3',
        'spades-10',
        'clubs-9',
        'diamonds-12',
        'diamonds-11',
      ]);
      expect(shuffledDeck(43), isNot(deck));
    });
  });

  group('solver', () {
    for (final drawCount in [1, 3]) {
      test('solves a near-won state, draw $drawCount', () {
        final state = nearWon(drawCount: drawCount);
        final result = solver.solve(state);
        expect(result.status, SolveStatus.solved);
        expect(result.solution, contains(const DrawAction()));
        expect(replaysToWin(state, result.solution), isTrue);
      });
    }

    for (final drawCount in [1, 3]) {
      test('solutions of real deals replay to a win, draw $drawCount', () {
        for (final seed in [1, 2, 3]) {
          final state = KlondikeState.deal(seed, drawCount: drawCount);
          final result = solver.solve(state);
          expect(result.status, SolveStatus.solved, reason: 'seed $seed');
          expect(replaysToWin(state, result.solution), isTrue);
        }
      });
    }

    test('reports unsolvable when A♥ and 2♥ can never be freed', () {
      // Only a black 4 or 5 could take the 3♥ or 4♥ above them. Those are
      // deep in the foundations, and the single empty column lets one king
      // leave a foundation, far too few to dig them out.
      final state = board(
        stock: [
          for (final code in ['10H', 'JH', 'QH', 'KH']) card(code, up: false),
        ],
        foundations: foundationsUpTo([13, 13, 0, 13]),
        tableau: [
          [card('AH', up: false), card('3H')],
          [card('2H', up: false), card('4H')],
          [card('9H', up: false), card('5H')],
          [card('6H')],
          [card('7H')],
          [card('8H')],
        ],
      );
      final result = solver.solve(state);
      expect(result.status, SolveStatus.unsolvable);
      expect(result.nodes, greaterThan(1));
      expect(solver.playGreedy(state), isNull);
    });

    test('stops at maxNodes', () {
      final state = KlondikeState.deal(klondikeDeals[1]!['hard']!.first);
      final result = solver.solve(state, maxNodes: 50);
      expect(result.status, SolveStatus.unknown);
      expect(result.nodes, 50);
      expect(result.solution, isEmpty);
    });

    test('the greedy player wins an easy state with real actions', () {
      final state = nearWon();
      final actions = solver.playGreedy(state);
      expect(actions, isNotNull);
      expect(replaysToWin(state, actions!), isTrue);
    });
  });

  group('generated deals', () {
    test('have 300 to 500 distinct seeds per draw count and difficulty', () {
      expect(klondikeDeals.keys, unorderedEquals([1, 3]));
      for (final buckets in klondikeDeals.values) {
        expect(
          buckets.keys,
          unorderedEquals(KlondikeDifficulty.values.map((d) => d.name)),
        );
        for (final seeds in buckets.values) {
          expect(seeds.length, inInclusiveRange(300, 500));
          expect(seeds.toSet(), hasLength(seeds.length));
        }
      }
      for (final drawCount in [1, 3]) {
        final all = klondikeDeals[drawCount]!.values.expand((s) => s).toList();
        expect(all.toSet(), hasLength(all.length));
      }
    });

    for (final drawCount in [1, 3]) {
      for (final difficulty in KlondikeDifficulty.values) {
        test('${difficulty.name} draw $drawCount seeds still win and grade '
            'the same', () {
          for (final seed in klondikeDeals[drawCount]![difficulty.name]!.take(
            3,
          )) {
            final grade = solver.grade(seed, drawCount);
            expect(grade.difficulty, difficulty, reason: 'seed $seed');
            final state = KlondikeState.deal(seed, drawCount: drawCount);
            expect(replaysToWin(state, grade.result.solution), isTrue);
          }
        });
      }
    }
  });
}
