import 'dart:math';

import 'package:all_for_games/games/sudoku/sudoku_grader.dart';
import 'package:all_for_games/games/sudoku/sudoku_grid.dart';
import 'package:all_for_games/games/sudoku/sudoku_level.dart';
import 'package:all_for_games/games/sudoku/sudoku_solver.dart';
import 'package:flutter_test/flutter_test.dart';

int cell(int row, int column) => row * 9 + column;

/// Fails when [grader] holds a digit other than the [solution]'s, or took
/// the solution's digit out of a cell's candidates.
void expectSound(SudokuGrader grader, List<int> solution, String reason) {
  for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
    final value = grader.values[cell];
    if (value != 0 && value != solution[cell]) {
      fail('$reason: cell $cell holds $value, not ${solution[cell]}');
    }
    if (value == 0 && grader.candidates[cell] & 1 << solution[cell] == 0) {
      fail('$reason: cell $cell lost its digit ${solution[cell]}');
    }
  }
}

/// Grades [puzzle], checking every step against its solution.
SudokuGrade gradeChecked(String puzzle) {
  final grid = SudokuGrid.decode(puzzle);
  final solution = solveSudoku(grid).single;
  return gradeSudoku(
    grid,
    onStep: (technique, grader) =>
        expectSound(grader, solution, '$puzzle, ${technique.name}'),
  );
}

/// Every digit in every empty cell, but the digits of [marks] (`'38'`) in
/// their cells.
SudokuGrader pencilMarks([Map<int, String> marks = const {}]) {
  final candidates = List.filled(SudokuGrid.cellCount, 0x3FE);
  for (final MapEntry(key: cell, value: digits) in marks.entries) {
    candidates[cell] = digits
        .split('')
        .fold(0, (mask, digit) => mask | 1 << int.parse(digit));
  }
  return SudokuGrader.withCandidates(
    List.filled(SudokuGrid.cellCount, 0),
    candidates,
  );
}

void removeDigit(SudokuGrader grader, int digit, Iterable<int> cells) {
  for (final cell in cells) {
    grader.candidates[cell] &= ~(1 << digit);
  }
}

/// The cells that lost candidates when [grader] applied [technique], with
/// the digits they lost.
Map<int, String> applyAndDiff(SudokuGrader grader, SudokuTechnique technique) {
  final before = [...grader.candidates];
  expect(grader.apply(technique), isTrue);
  return {
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
      if (before[cell] != grader.candidates[cell])
        cell: [
          for (var digit = 1; digit <= 9; digit++)
            if (before[cell] & ~grader.candidates[cell] & 1 << digit != 0)
              digit,
        ].join(),
  };
}

/// A random puzzle with one solution: a full grid from the solver, then
/// givens taken away one by one while the solution stays unique.
(List<int> puzzle, List<int> solution) randomPuzzle(Random random) {
  final grid = List.filled(SudokuGrid.cellCount, 0);
  for (final box in [0, 4, 8]) {
    final digits = [for (var d = 1; d <= 9; d++) d]..shuffle(random);
    for (var i = 0; i < 9; i++) {
      grid[SudokuGrid.units[18 + box][i]] = digits[i];
    }
  }
  final solution = solveSudoku(grid).single;
  final puzzle = [...solution];
  for (final cell in [
    for (var c = 0; c < SudokuGrid.cellCount; c++) c,
  ]..shuffle(random)) {
    puzzle[cell] = 0;
    if (!hasOneSolution(puzzle)) puzzle[cell] = solution[cell];
  }
  return (puzzle, solution);
}

/// Puzzles of public sources that need a technique: the grader solves them
/// with it as the hardest, and gets stuck without it.
const demos = [
  (
    SudokuTechnique.hiddenSingleBox,
    'Project Euler 96, grid 01',
    '003020600900305001001806400008102900700000008006708200002609500800203009005010300',
  ),
  (
    SudokuTechnique.hiddenSingleLine,
    'SudokuWiki, Getting Started, last number in a box',
    '200070038000006070300040600008020700100000006007030400004080009060400000910060002',
  ),
  (
    SudokuTechnique.nakedSingle,
    'Project Euler 96, grid 03',
    '000000907000420180000705026100904000050000040000507009920108000034059000507000000',
  ),
  (
    SudokuTechnique.lockedCandidates,
    'Project Euler 96, grid 25',
    '360020089000361000000000000803000602400603007607000108000000000000418000970030014',
  ),
  (
    SudokuTechnique.nakedPair,
    'SudokuWiki, Naked Candidates, naked pairs figure 2',
    '080090030030000000002060108020800500800907006004005070503040900000000010010050020',
  ),
  (
    SudokuTechnique.hiddenPair,
    'Project Euler 96, grid 50',
    '300200000000107000706030500070009080900020004010800050009040301000702000000008006',
  ),
  (
    // The two hidden triples leave naked triples in their units.
    SudokuTechnique.nakedTriple,
    'SudokuWiki, Hidden Candidates, two hidden triples',
    '000000000231090000065003100008924000100050006000136700009300570000010843000000000',
  ),
  (
    SudokuTechnique.xWing,
    'SudokuWiki, X-Wing example 1',
    '100000569402000008050009040000640801000010000208035000040500010900000402621000005',
  ),
  (
    SudokuTechnique.xyWing,
    'SudokuWiki, Y-Wing exemplar 1',
    '050000080000086000000201070009020601280000054703060900090605000000170000030000010',
  ),
  (
    SudokuTechnique.swordfish,
    'SudokuWiki, Swordfish exemplar 8',
    '300040000000007048000000907010003080400050020050008070500300000000000090609025300',
  ),
  (
    SudokuTechnique.xyzWing,
    'SudokuWiki, X-Wing exemplar 4',
    '900020000506000109007501000000008060601000507090400000000602700409000806000080004',
  ),
  (
    SudokuTechnique.skyscraper,
    'SudokuWiki, Singles Chains, rule 4',
    '000000050050409000008060400860010500001040700009050083006090300000108090040000000',
  ),
  (
    SudokuTechnique.twoStringKite,
    'SudokuWiki, X-Wing exemplar 1',
    '000001008700030009020000061080009003001040900900300020240000080600090005100600000',
  ),
  (
    SudokuTechnique.wWing,
    'SudokuWiki, Y-Wing exemplar 10',
    '400000006026000070080040090007800200100302007005004800070020080090000160600000003',
  ),
  (
    SudokuTechnique.xChain,
    'SudokuWiki, Singles Chains, simple colouring rule 2',
    '000000030002090500080706004900054006030000070600380009300601020007020600060000000',
  ),
  (
    SudokuTechnique.xyChain,
    'SudokuWiki, Y-Wing exemplar 9',
    '003608000207000000000700340000000019301209507490000000076005000000000208000806700',
  ),
];

/// Famous hard puzzles: one solution each, beyond every technique here.
const hardPuzzles = {
  'Arto Inkala, 2012': '800000000003600000070090200050007000000045700000100030001000068008500010090000400',
  'AI Escargot': '100007090030020008009600500005300900010080002600004000300000010040000007007000300',
  'Easter Monster': '100000002090400050006000700050903000000070000000850040700000600030009080002000001',
  'Golden Nugget': '000000039000001005003050800008090006070002000100400000009080050020000600400700000',
};

void main() {
  group('solveSudoku', () {
    test('finds the one solution of a puzzle', () {
      final grid = SudokuGrid.decode(demos.first.$3);
      final solutions = solveSudoku(grid, limit: 2);
      expect(solutions, hasLength(1));
      final solution = solutions.single;
      for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
        if (grid[cell] != 0) expect(solution[cell], grid[cell]);
      }
      for (final unit in SudokuGrid.units) {
        expect(
          {for (final cell in unit) solution[cell]},
          {for (var d = 1; d <= 9; d++) d},
        );
      }
      expect(hasOneSolution(grid), isTrue);
    });

    test('stops at the limit for a puzzle with many solutions', () {
      final empty = List.filled(SudokuGrid.cellCount, 0);
      final solutions = solveSudoku(empty, limit: 2);
      expect(solutions, hasLength(2));
      expect(solutions.first, isNot(solutions.last));
      expect(hasOneSolution(empty), isFalse);
    });

    test('finds none for an inconsistent grid', () {
      final clash = List.filled(SudokuGrid.cellCount, 0)
        ..[cell(0, 0)] = 5
        ..[cell(0, 8)] = 5;
      expect(solveSudoku(clash), isEmpty);
      // 1 to 8 in the first row and 9 in the last column: no digit is left
      // for the top right cell.
      final stuck = List.filled(SudokuGrid.cellCount, 0);
      for (var column = 0; column < 8; column++) {
        stuck[cell(0, column)] = column + 1;
      }
      stuck[cell(5, 8)] = 9;
      expect(solveSudoku(stuck), isEmpty);
      expect(hasOneSolution(stuck), isFalse);
    });
  });

  group('techniques', () {
    test('locked candidates: a box points its digit along a row', () {
      // In box 0, 7 can only go in row 1: the rest of row 1 cannot hold it.
      final grader = pencilMarks();
      removeDigit(grader, 7, [
        for (final c in [0, 1, 2]) ...[cell(0, c), cell(2, c)],
      ]);
      expect(applyAndDiff(grader, SudokuTechnique.lockedCandidates), {
        for (var c = 3; c < 9; c++) cell(1, c): '7',
      });
    });

    test('naked pair: two cells of a row with the same two digits', () {
      final grader = pencilMarks({cell(4, 1): '38', cell(4, 6): '38'});
      expect(applyAndDiff(grader, SudokuTechnique.nakedPair), {
        for (final c in [0, 2, 3, 4, 5, 7, 8]) cell(4, c): '38',
      });
    });

    test('X-Wing: two rows with a digit in the same two columns', () {
      final grader = pencilMarks();
      for (final row in [1, 6]) {
        removeDigit(grader, 5, [
          for (final c in [0, 1, 3, 4, 5, 7, 8]) cell(row, c),
        ]);
      }
      expect(applyAndDiff(grader, SudokuTechnique.xWing), {
        for (final row in [0, 2, 3, 4, 5, 7, 8])
          for (final c in [2, 6]) cell(row, c): '5',
      });
    });

    test('XY-Wing: one of the wings holds the digit they share', () {
      // Pivot {1, 2}, wings {1, 3} in its row and {2, 3} in its column.
      final grader = pencilMarks({
        cell(0, 0): '12',
        cell(0, 5): '13',
        cell(4, 0): '23',
      });
      expect(applyAndDiff(grader, SudokuTechnique.xyWing), {cell(4, 5): '3'});
    });

    test('Skyscraper: two rows joined by a column', () {
      // 4 goes in rows 1 and 5 only in column 0 and one other column each:
      // r1c4 or r5c5 holds it.
      final grader = pencilMarks();
      removeDigit(grader, 4, [
        for (var c = 0; c < 9; c++) ...[
          if (c != 0 && c != 4) cell(1, c),
          if (c != 0 && c != 5) cell(5, c),
        ],
      ]);
      expect(grader.apply(SudokuTechnique.xWing), isFalse);
      expect(applyAndDiff(grader, SudokuTechnique.skyscraper), {
        cell(0, 5): '4',
        cell(2, 5): '4',
        cell(3, 4): '4',
        cell(4, 4): '4',
      });
    });

    test('X-chain: the same Skyscraper as a chain', () {
      final grader = pencilMarks();
      removeDigit(grader, 4, [
        for (var c = 0; c < 9; c++) ...[
          if (c != 0 && c != 4) cell(1, c),
          if (c != 0 && c != 5) cell(5, c),
        ],
      ]);
      // r1c4 = r1c0 - r5c0 = r5c5.
      expect(applyAndDiff(grader, SudokuTechnique.xChain), {
        cell(0, 5): '4',
        cell(2, 5): '4',
        cell(3, 4): '4',
        cell(4, 4): '4',
      });
    });

    for (final (technique, source, puzzle) in demos) {
      test('${technique.name} solves $source', () {
        expect(hasOneSolution(SudokuGrid.decode(puzzle)), isTrue);
        final grade = gradeChecked(puzzle);
        expect(grade.solved, isTrue);
        expect(grade.hardest, technique);
        final simpler = SudokuTechnique.values[technique.index - 1];
        expect(
          gradeSudoku(SudokuGrid.decode(puzzle), upTo: simpler).solved,
          isFalse,
        );
      });
    }

    test('famous hard puzzles get the grader stuck', () {
      for (final MapEntry(key: name, value: puzzle) in hardPuzzles.entries) {
        expect(hasOneSolution(SudokuGrid.decode(puzzle)), isTrue, reason: name);
        final grade = gradeChecked(puzzle);
        expect(grade.solved, isFalse, reason: name);
        expect(grade.level, SudokuLevel.level12, reason: name);
      }
    });
  });

  group('levelOf', () {
    SudokuLevel? levelOf(
      Map<SudokuTechnique, int> uses,
      int givens, {
      bool solved = true,
    }) => SudokuGrade(solved: solved, uses: uses, givens: givens).level;

    test('levels of singles go by givens', () {
      const box = {SudokuTechnique.hiddenSingleBox: 30};
      expect(levelOf(box, 46), SudokuLevel.level1);
      expect(levelOf(box, 42), SudokuLevel.level1);
      expect(levelOf(box, 40), isNull);
      expect(levelOf(box, 36), SudokuLevel.level2);
      expect(levelOf(box, 30), SudokuLevel.level3);
      expect(levelOf(box, 26), isNull);
      const line = {...box, SudokuTechnique.hiddenSingleLine: 2};
      expect(levelOf(line, 30), SudokuLevel.level3);
      expect(levelOf(line, 36), isNull);
      expect(
        levelOf({...line, SudokuTechnique.nakedSingle: 1}, 24),
        SudokuLevel.level4,
      );
    });

    test('rounds of locked candidates split levels 5 and 6', () {
      const singles = {SudokuTechnique.nakedSingle: 3};
      expect(
        levelOf({...singles, SudokuTechnique.lockedCandidates: 2}, 26),
        SudokuLevel.level5,
      );
      expect(
        levelOf({...singles, SudokuTechnique.lockedCandidates: 3}, 26),
        SudokuLevel.level6,
      );
    });

    test('the hardest technique sets the higher levels', () {
      const expected = {
        SudokuTechnique.hiddenPair: SudokuLevel.level6,
        SudokuTechnique.hiddenTriple: SudokuLevel.level7,
        SudokuTechnique.xWing: SudokuLevel.level8,
        SudokuTechnique.swordfish: SudokuLevel.level9,
        SudokuTechnique.jellyfish: SudokuLevel.level10,
        SudokuTechnique.wWing: SudokuLevel.level10,
        SudokuTechnique.xyChain: SudokuLevel.level11,
      };
      for (final MapEntry(key: technique, value: level) in expected.entries) {
        final uses = {
          SudokuTechnique.lockedCandidates: 1,
          technique: 1,
          SudokuTechnique.nakedPair: 1,
        };
        expect(levelOf(uses, 25), level, reason: technique.name);
      }
      expect(levelOf(const {}, 25, solved: false), SudokuLevel.level12);
    });
  });

  test('no step of random puzzles takes out a digit of the solution', () {
    // Every technique also runs on every state of the solve, even where a
    // simpler one applies, to reach patterns the solve itself skips.
    final random = Random(2024);
    final applied = <SudokuTechnique>{};
    for (var i = 0; i < 300; i++) {
      final (puzzle, solution) = randomPuzzle(random);
      void check(SudokuTechnique technique, SudokuGrader grader) {
        expectSound(grader, solution, 'puzzle $i, ${technique.name}');
        for (final other in SudokuTechnique.values) {
          final copy = SudokuGrader.withCandidates(
            grader.values,
            grader.candidates,
          );
          if (!copy.apply(other)) continue;
          applied.add(other);
          expectSound(copy, solution, 'puzzle $i, ${other.name} on its own');
        }
      }

      gradeSudoku(puzzle, onStep: check);
    }
    expect(applied, containsAll(SudokuTechnique.values));
  });
}
