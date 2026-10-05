import 'dart:math';

import 'freecell_deals.dart';
import 'freecell_difficulty.dart';

/// A random seed of `freecellDeals[difficulty]`, so the deal can be won.
/// Seeds in [played] are skipped while others are left; once every seed of
/// the list was played, any of them can come again.
int pickFreeCellSeed({
  required FreeCellDifficulty difficulty,
  required Set<int> played,
  required Random random,
}) {
  final seeds = freecellDeals[difficulty.name]!;
  final fresh = [
    for (final seed in seeds)
      if (!played.contains(seed)) seed,
  ];
  final pool = fresh.isEmpty ? seeds : fresh;
  return pool[random.nextInt(pool.length)];
}

/// The difficulty list that holds [seed], or null for a seed in none of
/// them (for example from a `/freecell?seed=42` link).
FreeCellDifficulty? freeCellDifficultyOfSeed(int seed) {
  for (final difficulty in FreeCellDifficulty.values) {
    if (freecellDeals[difficulty.name]?.contains(seed) ?? false) {
      return difficulty;
    }
  }
  return null;
}
