import 'sudoku_grid.dart';
import 'sudoku_level.dart';

/// The steps a person takes to solve a Sudoku, from the simplest to the
/// hardest. The grader always takes the simplest step that makes progress.
enum SudokuTechnique {
  /// The last empty cell of a row, column or box.
  fullHouse,

  /// The only cell of a box where a digit can go.
  hiddenSingleBox,

  /// The only cell of a row or column where a digit can go.
  hiddenSingleLine,

  /// A cell where only one digit can go.
  nakedSingle,

  /// A digit of a box only in one row or column (pointing), or of a row or
  /// column only in one box (claiming).
  lockedCandidates,
  nakedPair,
  hiddenPair,
  nakedTriple,
  hiddenTriple,
  xWing,
  xyWing,
  swordfish,
  xyzWing,
  nakedQuad,
  hiddenQuad,
  jellyfish,

  /// Two conjugate pairs of a digit in parallel lines, joined at one end by
  /// a line across them.
  skyscraper,

  /// A conjugate pair of a digit in a row and one in a column, joined at one
  /// end by a box.
  twoStringKite,

  /// Two cells with the same two digits, joined by a conjugate pair of one
  /// of them.
  wWing,

  /// An alternating chain of conjugate pairs and peers on one digit (it
  /// covers the traps of simple coloring).
  xChain,

  /// A chain of cells with two digits each, every one forcing the next.
  xyChain,
}

/// The givens of the levels solved with singles only: they set the level.
const sudokuSinglesGivens = {
  SudokuLevel.level1: (min: 42, max: 46),
  SudokuLevel.level2: (min: 34, max: 38),
  SudokuLevel.level3: (min: 28, max: 32),
};

/// What [gradeSudoku] found: whether the techniques solve the puzzle, and how
/// many rounds of each one it took.
class SudokuGrade {
  const SudokuGrade({
    required this.solved,
    required this.uses,
    required this.givens,
  });

  /// The grader filled every cell.
  final bool solved;

  /// Rounds of each technique: the grader applies it until it finds nothing
  /// more, then goes back to the simplest one.
  final Map<SudokuTechnique, int> uses;

  /// Cells filled at the start.
  final int givens;

  SudokuTechnique? get hardest => uses.keys.fold<SudokuTechnique?>(
    null,
    (hardest, t) => hardest == null || t.index > hardest.index ? t : hardest,
  );

  SudokuLevel? get level => levelOf(this, givens);
}

/// The level of a puzzle with one solution, from its full [grade]:
/// - level 1: full houses and hidden singles in boxes only, 42 to 46 givens;
/// - level 2: the same with 34 to 38 givens;
/// - level 3: hidden singles in any unit (no naked single), 28 to 32 givens;
/// - level 4: needs naked singles, singles only;
/// - level 5: locked candidates in 1 or 2 rounds, nothing harder;
/// - level 6: locked candidates in 3 rounds or more, or naked or hidden pairs;
/// - level 7: naked or hidden triples;
/// - level 8: X-Wing;
/// - level 9: XY-Wing or Swordfish;
/// - level 10: XYZ-Wing, quads, Jellyfish, Skyscraper, 2-String Kite or
///   W-Wing;
/// - level 11: X-chains or XY-chains;
/// - level 12: the grader gets stuck: it needs trial or longer reasoning.
///
/// Each level names its hardest technique. Null when singles solve the
/// puzzle with a number of givens outside the ranges of levels 1 to 3.
SudokuLevel? levelOf(SudokuGrade grade, int givens) {
  if (!grade.solved) return SudokuLevel.level12;
  SudokuLevel? byGivens(Iterable<SudokuLevel> levels) {
    for (final level in levels) {
      final range = sudokuSinglesGivens[level]!;
      if (givens >= range.min && givens <= range.max) return level;
    }
    return null;
  }

  return switch (grade.hardest) {
    null ||
    SudokuTechnique.fullHouse ||
    SudokuTechnique.hiddenSingleBox => byGivens(sudokuSinglesGivens.keys),
    SudokuTechnique.hiddenSingleLine => byGivens([SudokuLevel.level3]),
    SudokuTechnique.nakedSingle => SudokuLevel.level4,
    SudokuTechnique.lockedCandidates =>
      grade.uses[SudokuTechnique.lockedCandidates]! <= 2
          ? SudokuLevel.level5
          : SudokuLevel.level6,
    SudokuTechnique.nakedPair ||
    SudokuTechnique.hiddenPair => SudokuLevel.level6,
    SudokuTechnique.nakedTriple ||
    SudokuTechnique.hiddenTriple => SudokuLevel.level7,
    SudokuTechnique.xWing => SudokuLevel.level8,
    SudokuTechnique.xyWing || SudokuTechnique.swordfish => SudokuLevel.level9,
    SudokuTechnique.xyzWing ||
    SudokuTechnique.nakedQuad ||
    SudokuTechnique.hiddenQuad ||
    SudokuTechnique.jellyfish ||
    SudokuTechnique.skyscraper ||
    SudokuTechnique.twoStringKite ||
    SudokuTechnique.wWing => SudokuLevel.level10,
    SudokuTechnique.xChain || SudokuTechnique.xyChain => SudokuLevel.level11,
  };
}

/// Solves [grid] (81 values, 0 for an empty cell) like a person, always with
/// the simplest technique up to [upTo] that places a digit or removes
/// candidates. [onStep] sees the grader after each step.
///
/// A round applies a technique until it finds nothing more, so that the
/// grade does not depend on the order the grader scans the grid in: a turned
/// or relabeled puzzle keeps its grade.
///
/// Every step holds for any solution of the grid, so a solved grade proves
/// that the solution is unique.
SudokuGrade gradeSudoku(
  List<int> grid, {
  SudokuTechnique upTo = SudokuTechnique.xyChain,
  void Function(SudokuTechnique technique, SudokuGrader grader)? onStep,
}) {
  final grader = SudokuGrader(grid);
  final uses = <SudokuTechnique, int>{};
  while (!grader.isSolved) {
    final technique = grader.step(upTo: upTo);
    if (technique == null) break;
    uses.update(technique, (count) => count + 1, ifAbsent: () => 1);
    onStep?.call(technique, grader);
    while (!grader.isSolved && grader.apply(technique)) {
      onStep?.call(technique, grader);
    }
  }
  return SudokuGrade(
    solved: grader.isSolved,
    uses: uses,
    givens: grid.where((value) => value != 0).length,
  );
}

/// The grid and pencil marks of a logical solve.
///
/// [candidates] holds a bit mask per cell: bit `d` set when digit `d` may
/// still go there; a filled cell has none.
class SudokuGrader {
  /// Starts from [grid] with every candidate its peers allow.
  SudokuGrader(List<int> grid)
    : values = List.filled(SudokuGrid.cellCount, 0),
      candidates = List.filled(SudokuGrid.cellCount, _allDigits) {
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
      if (grid[cell] != 0) _place(cell, grid[cell]);
    }
  }

  /// Starts from given values and pencil marks.
  SudokuGrader.withCandidates(List<int> values, List<int> candidates)
    : values = [...values],
      candidates = [...candidates];

  final List<int> values;
  final List<int> candidates;

  bool get isSolved => !values.contains(0);

  /// Applies the simplest technique up to [upTo] that makes progress, and
  /// returns it; null when none does.
  SudokuTechnique? step({SudokuTechnique upTo = SudokuTechnique.xyChain}) {
    for (final technique in SudokuTechnique.values) {
      if (technique.index > upTo.index) break;
      if (apply(technique)) return technique;
    }
    return null;
  }

  /// Takes one step with [technique]: one digit placed, or the candidates
  /// one pattern removes. False when it finds nothing to do.
  bool apply(SudokuTechnique technique) => switch (technique) {
    SudokuTechnique.fullHouse => _fullHouse(),
    SudokuTechnique.hiddenSingleBox => _hiddenSingle(18, 27),
    SudokuTechnique.hiddenSingleLine => _hiddenSingle(0, 18),
    SudokuTechnique.nakedSingle => _nakedSingle(),
    SudokuTechnique.lockedCandidates => _lockedCandidates(),
    SudokuTechnique.nakedPair => _nakedSubset(2),
    SudokuTechnique.hiddenPair => _hiddenSubset(2),
    SudokuTechnique.nakedTriple => _nakedSubset(3),
    SudokuTechnique.hiddenTriple => _hiddenSubset(3),
    SudokuTechnique.xWing => _fish(2),
    SudokuTechnique.xyWing => _xyWing(),
    SudokuTechnique.swordfish => _fish(3),
    SudokuTechnique.xyzWing => _xyzWing(),
    SudokuTechnique.nakedQuad => _nakedSubset(4),
    SudokuTechnique.hiddenQuad => _hiddenSubset(4),
    SudokuTechnique.jellyfish => _fish(4),
    SudokuTechnique.skyscraper => _twoLinks(kite: false),
    SudokuTechnique.twoStringKite => _twoLinks(kite: true),
    SudokuTechnique.wWing => _wWing(),
    SudokuTechnique.xChain => _xChain(),
    SudokuTechnique.xyChain => _xyChain(),
  };

  void _place(int cell, int digit) {
    values[cell] = digit;
    candidates[cell] = 0;
    final keep = ~(1 << digit);
    for (final peer in SudokuGrid.peers[cell]) {
      candidates[peer] &= keep;
    }
  }

  bool _eliminate(int cell, int mask) {
    if (candidates[cell] & mask == 0) return false;
    candidates[cell] &= ~mask;
    return true;
  }

  /// Removes [mask] from every cell that sees all of [cells].
  bool _eliminateSeenBy(List<int> cells, int mask) {
    var changed = false;
    for (final target in SudokuGrid.peers[cells.first]) {
      if (cells.every((cell) => sees(target, cell))) {
        changed = _eliminate(target, mask) || changed;
      }
    }
    return changed;
  }

  bool _fullHouse() {
    for (final unit in SudokuGrid.units) {
      var empty = -1;
      var emptyCount = 0;
      for (final cell in unit) {
        if (values[cell] == 0) {
          empty = cell;
          emptyCount++;
        }
      }
      if (emptyCount == 1 && _count(candidates[empty]) == 1) {
        _place(empty, _digitOf(candidates[empty]));
        return true;
      }
    }
    return false;
  }

  /// A digit with one place left in one of the units [from] to [to].
  bool _hiddenSingle(int from, int to) {
    for (var u = from; u < to; u++) {
      final unit = SudokuGrid.units[u];
      var once = 0;
      var twice = 0;
      for (final cell in unit) {
        twice |= once & candidates[cell];
        once |= candidates[cell];
      }
      final single = once & ~twice;
      if (single == 0) continue;
      final bit = single & -single;
      for (final cell in unit) {
        if (candidates[cell] & bit != 0) {
          _place(cell, _digitOf(bit));
          return true;
        }
      }
    }
    return false;
  }

  bool _nakedSingle() {
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
      if (values[cell] == 0 && _count(candidates[cell]) == 1) {
        _place(cell, _digitOf(candidates[cell]));
        return true;
      }
    }
    return false;
  }

  bool _lockedCandidates() {
    final units = SudokuGrid.units;
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      for (var box = 18; box < 27; box++) {
        var rows = 0;
        var columns = 0;
        for (final cell in units[box]) {
          if (candidates[cell] & bit == 0) continue;
          rows |= 1 << SudokuGrid.rowOf(cell);
          columns |= 1 << SudokuGrid.columnOf(cell);
        }
        for (final line in [
          if (_count(rows) == 1) units[_digitOf(rows)],
          if (_count(columns) == 1) units[9 + _digitOf(columns)],
        ]) {
          var changed = false;
          for (final cell in line) {
            if (SudokuGrid.boxOf(cell) != box - 18) {
              changed = _eliminate(cell, bit) || changed;
            }
          }
          if (changed) return true;
        }
      }
      for (var line = 0; line < 18; line++) {
        var boxes = 0;
        for (final cell in units[line]) {
          if (candidates[cell] & bit != 0) boxes |= 1 << SudokuGrid.boxOf(cell);
        }
        if (_count(boxes) != 1) continue;
        var changed = false;
        for (final cell in units[18 + _digitOf(boxes)]) {
          if (!units[line].contains(cell)) {
            changed = _eliminate(cell, bit) || changed;
          }
        }
        if (changed) return true;
      }
    }
    return false;
  }

  /// [size] cells of a unit holding [size] digits between them: no other
  /// cell of the unit can take these digits.
  bool _nakedSubset(int size) {
    for (final unit in SudokuGrid.units) {
      final places = <int>[];
      final masks = <int>[];
      var empty = 0;
      for (var i = 0; i < 9; i++) {
        final count = _count(candidates[unit[i]]);
        if (count > 0) empty++;
        if (count >= 2 && count <= size) {
          places.add(i);
          masks.add(candidates[unit[i]]);
        }
      }
      if (empty <= size) continue;
      final found = _subsets(places, masks, size, (chosen, digits) {
        var changed = false;
        for (var i = 0; i < 9; i++) {
          if (chosen & 1 << i == 0) {
            changed = _eliminate(unit[i], digits) || changed;
          }
        }
        return changed;
      });
      if (found) return true;
    }
    return false;
  }

  /// [size] digits of a unit with [size] places between them: these cells
  /// can take no other digit.
  bool _hiddenSubset(int size) {
    for (final unit in SudokuGrid.units) {
      final digits = <int>[];
      final masks = <int>[];
      var empty = 0;
      for (final cell in unit) {
        if (values[cell] == 0) empty++;
      }
      if (empty <= size) continue;
      for (var digit = 1; digit <= 9; digit++) {
        var places = 0;
        for (var i = 0; i < 9; i++) {
          if (candidates[unit[i]] & 1 << digit != 0) places |= 1 << i;
        }
        final count = _count(places);
        if (count >= 2 && count <= size) {
          digits.add(digit);
          masks.add(places);
        }
      }
      final found = _subsets(digits, masks, size, (chosen, places) {
        var changed = false;
        for (var i = 0; i < 9; i++) {
          if (places & 1 << i != 0) {
            changed = _eliminate(unit[i], _allDigits & ~chosen) || changed;
          }
        }
        return changed;
      });
      if (found) return true;
    }
    return false;
  }

  /// [size] rows (or columns) holding a digit in [size] columns (rows)
  /// between them: the rest of these columns (rows) cannot take it.
  bool _fish(int size) {
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      for (final byRows in [true, false]) {
        int cellAt(int line, int across) =>
            byRows ? line * 9 + across : across * 9 + line;
        final lines = <int>[];
        final masks = <int>[];
        for (var line = 0; line < 9; line++) {
          var places = 0;
          for (var across = 0; across < 9; across++) {
            if (candidates[cellAt(line, across)] & bit != 0) {
              places |= 1 << across;
            }
          }
          final count = _count(places);
          if (count >= 2 && count <= size) {
            lines.add(line);
            masks.add(places);
          }
        }
        final found = _subsets(lines, masks, size, (chosen, covers) {
          var changed = false;
          for (var line = 0; line < 9; line++) {
            if (chosen & 1 << line != 0) continue;
            for (var across = 0; across < 9; across++) {
              if (covers & 1 << across != 0) {
                changed = _eliminate(cellAt(line, across), bit) || changed;
              }
            }
          }
          return changed;
        });
        if (found) return true;
      }
    }
    return false;
  }

  /// Calls [found] with each choice of [size] of [items] whose [masks]
  /// cover [size] bits between them (`chosen`: a bit per item), until it
  /// returns true.
  static bool _subsets(
    List<int> items,
    List<int> masks,
    int size,
    bool Function(int chosen, int union) found,
  ) {
    bool search(int from, int picked, int chosen, int union) {
      if (picked == size) return _count(union) == size && found(chosen, union);
      for (var i = from; i < items.length; i++) {
        final next = union | masks[i];
        if (_count(next) > size) continue;
        if (search(i + 1, picked + 1, chosen | 1 << items[i], next)) {
          return true;
        }
      }
      return false;
    }

    return search(0, 0, 0, 0);
  }

  /// A pivot {x, y} sees wings {x, z} and {y, z}: one of the wings is z.
  bool _xyWing() {
    for (var pivot = 0; pivot < SudokuGrid.cellCount; pivot++) {
      final mask = candidates[pivot];
      if (_count(mask) != 2) continue;
      final wings = [
        for (final peer in SudokuGrid.peers[pivot])
          if (_count(candidates[peer]) == 2 &&
              _count(candidates[peer] & mask) == 1)
            peer,
      ];
      for (var i = 0; i < wings.length; i++) {
        for (var j = i + 1; j < wings.length; j++) {
          final a = candidates[wings[i]];
          final b = candidates[wings[j]];
          final z = a & ~mask;
          if (z != b & ~mask || a & mask == b & mask) continue;
          if (_eliminateSeenBy([wings[i], wings[j]], z)) return true;
        }
      }
    }
    return false;
  }

  /// A pivot {x, y, z} sees wings {x, z} and {y, z}: one of the three is z.
  bool _xyzWing() {
    for (var pivot = 0; pivot < SudokuGrid.cellCount; pivot++) {
      final mask = candidates[pivot];
      if (_count(mask) != 3) continue;
      final wings = [
        for (final peer in SudokuGrid.peers[pivot])
          if (_count(candidates[peer]) == 2 && candidates[peer] & ~mask == 0)
            peer,
      ];
      for (var i = 0; i < wings.length; i++) {
        for (var j = i + 1; j < wings.length; j++) {
          final a = candidates[wings[i]];
          final b = candidates[wings[j]];
          if (a | b != mask) continue;
          if (_eliminateSeenBy([pivot, wings[i], wings[j]], a & b)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// The pairs of cells that are the only two places of [bit] in a unit,
  /// with that unit, from units [from] to [to].
  List<(int, int, int)> _strongLinks(int bit, [int from = 0, int to = 27]) {
    final links = <(int, int, int)>[];
    for (var u = from; u < to; u++) {
      final places = [
        for (final cell in SudokuGrid.units[u])
          if (candidates[cell] & bit != 0) cell,
      ];
      if (places.length == 2) links.add((places[0], places[1], u));
    }
    return links;
  }

  /// Chains `p = q - r = s` on one digit, from a conjugate pair p, q and one
  /// r, s where q sees r: p or s holds the digit. A Skyscraper has both
  /// pairs in parallel lines and q, r in one line across; a 2-String Kite
  /// has a pair in a row, one in a column and q, r in one box.
  bool _twoLinks({required bool kite}) {
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      final links = _strongLinks(bit, 0, 18);
      for (var i = 0; i < links.length; i++) {
        for (var j = i + 1; j < links.length; j++) {
          final (a1, b1, u1) = links[i];
          final (a2, b2, u2) = links[j];
          if (((u1 < 9) == (u2 < 9)) == kite) continue;
          for (final (p, q) in [(a1, b1), (b1, a1)]) {
            for (final (r, s) in [(a2, b2), (b2, a2)]) {
              if ({p, q, r, s}.length < 4) continue;
              final joined = kite
                  ? SudokuGrid.boxOf(q) == SudokuGrid.boxOf(r) &&
                        SudokuGrid.boxOf(p) != SudokuGrid.boxOf(q) &&
                        SudokuGrid.boxOf(s) != SudokuGrid.boxOf(r)
                  : u1 < 9
                  ? SudokuGrid.columnOf(q) == SudokuGrid.columnOf(r) &&
                        SudokuGrid.columnOf(p) != SudokuGrid.columnOf(s)
                  : SudokuGrid.rowOf(q) == SudokuGrid.rowOf(r) &&
                        SudokuGrid.rowOf(p) != SudokuGrid.rowOf(s);
              if (joined && _eliminateSeenBy([p, s], bit)) return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Two cells {x, y} apart, each seeing one end of a conjugate pair of x:
  /// one of them is y.
  bool _wWing() {
    final pairs = [
      for (var cell = 0; cell < SudokuGrid.cellCount; cell++)
        if (_count(candidates[cell]) == 2) cell,
    ];
    final links = <int, List<(int, int, int)>>{};
    for (var i = 0; i < pairs.length; i++) {
      for (var j = i + 1; j < pairs.length; j++) {
        final a = pairs[i];
        final b = pairs[j];
        final mask = candidates[a];
        if (candidates[b] != mask || sees(a, b)) continue;
        for (var digit = 1; digit <= 9; digit++) {
          final bit = 1 << digit;
          if (mask & bit == 0) continue;
          for (final (p, q, _) in links[bit] ??= _strongLinks(bit)) {
            if (p == a || p == b || q == a || q == b) continue;
            if (!(sees(p, a) && sees(q, b) || sees(p, b) && sees(q, a))) {
              continue;
            }
            if (_eliminateSeenBy([a, b], mask & ~bit)) return true;
          }
        }
      }
    }
    return false;
  }

  /// From a start cell that does not hold a digit, conjugate pairs force it
  /// in and peers force it out, alternately: each cell forced in this way
  /// holds the digit when the start does not, so their common peers cannot.
  bool _xChain() {
    for (var digit = 1; digit <= 9; digit++) {
      final bit = 1 << digit;
      final partners = List.generate(SudokuGrid.cellCount, (_) => <int>[]);
      for (final (p, q, _) in _strongLinks(bit)) {
        partners[p].add(q);
        partners[q].add(p);
      }
      for (var start = 0; start < SudokuGrid.cellCount; start++) {
        if (partners[start].isEmpty) continue;
        final isIn = List.filled(SudokuGrid.cellCount, false);
        final isOut = List.filled(SudokuGrid.cellCount, false)..[start] = true;
        final queue = [start];
        // Cells out of the digit at even places of the queue, in at odd ones:
        // a cell forced out is followed by its partners, in by its peers.
        final forcedIn = <bool>[false];
        for (var next = 0; next < queue.length; next++) {
          final cell = queue[next];
          if (!forcedIn[next]) {
            for (final partner in partners[cell]) {
              if (isIn[partner]) continue;
              isIn[partner] = true;
              if (partner != start && _eliminateSeenBy([start, partner], bit)) {
                return true;
              }
              queue.add(partner);
              forcedIn.add(true);
            }
          } else {
            for (final peer in SudokuGrid.peers[cell]) {
              if (candidates[peer] & bit == 0 || isOut[peer]) continue;
              isOut[peer] = true;
              queue.add(peer);
              forcedIn.add(false);
            }
          }
        }
      }
    }
    return false;
  }

  /// From a start cell {z, a} that is not z, each cell with two digits that
  /// sees the last one and shares its digit takes its other digit: a cell
  /// forced to z this way and the start cannot both miss z.
  bool _xyChain() {
    for (var start = 0; start < SudokuGrid.cellCount; start++) {
      final mask = candidates[start];
      if (_count(mask) != 2) continue;
      for (final z in [mask & -mask, mask & (mask - 1)]) {
        final seen = <int>{};
        final queue = [(start, mask & ~z)];
        for (var next = 0; next < queue.length; next++) {
          final (cell, bit) = queue[next];
          for (final peer in SudokuGrid.peers[cell]) {
            final peerMask = candidates[peer];
            if (_count(peerMask) != 2 || peerMask & bit == 0) continue;
            final forced = peerMask & ~bit;
            if (!seen.add(peer * 1024 + forced)) continue;
            if (forced == z &&
                peer != start &&
                _eliminateSeenBy([start, peer], z)) {
              return true;
            }
            queue.add((peer, forced));
          }
        }
      }
    }
    return false;
  }

  /// Whether [a] and [b] are different cells of one row, column or box.
  static bool sees(int a, int b) => _sees[a * SudokuGrid.cellCount + b];

  static final _sees = () {
    final table = List.filled(
      SudokuGrid.cellCount * SudokuGrid.cellCount,
      false,
    );
    for (var cell = 0; cell < SudokuGrid.cellCount; cell++) {
      for (final peer in SudokuGrid.peers[cell]) {
        table[cell * SudokuGrid.cellCount + peer] = true;
      }
    }
    return table;
  }();
}

const _allDigits = 0x3FE;

final _bitCounts = [
  for (var mask = 0; mask < 1024; mask++)
    [for (var bit = 0; bit < 10; bit++) mask >> bit & 1]
        .reduce((a, b) => a + b),
];

int _count(int mask) => _bitCounts[mask];

/// The highest bit of [mask]: its digit when it has one bit.
int _digitOf(int mask) => mask.bitLength - 1;
