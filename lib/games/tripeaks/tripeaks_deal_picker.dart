import 'dart:math';

import 'tripeaks_deals.dart';
import 'tripeaks_difficulty.dart';

/// A random seed of `triPeaksDeals[difficulty]`, so the deal can be won.
/// Seeds in [played] are skipped while others are left; once every seed of
/// the list was played, any of them can come again.
int pickTriPeaksSeed({
  required TriPeaksDifficulty difficulty,
  required Set<int> played,
  required Random random,
}) {
  final seeds = triPeaksDeals[difficulty.name]!;
  final fresh = [
    for (final seed in seeds)
      if (!played.contains(seed)) seed,
  ];
  final pool = fresh.isEmpty ? seeds : fresh;
  return pool[random.nextInt(pool.length)];
}

/// The difficulty list that holds [seed], or null for a seed in none of
/// them (for example from a `/tripeaks?seed=42` link).
TriPeaksDifficulty? triPeaksDifficultyOfSeed(int seed) {
  for (final difficulty in TriPeaksDifficulty.values) {
    if (triPeaksDeals[difficulty.name]?.contains(seed) ?? false) {
      return difficulty;
    }
  }
  return null;
}
