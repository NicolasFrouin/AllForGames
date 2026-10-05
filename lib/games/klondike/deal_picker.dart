import 'dart:math';

import 'klondike_deals.dart';
import 'klondike_difficulty.dart';

/// A random seed of `klondikeDeals[drawCount][difficulty]`, so the deal can be
/// won. Seeds in [played] are skipped while others are left; once every seed
/// of the list was played, any of them can come again.
int pickDealSeed({
  required int drawCount,
  required KlondikeDifficulty difficulty,
  required Set<int> played,
  required Random random,
}) {
  final seeds = klondikeDeals[drawCount]![difficulty.name]!;
  final fresh = [
    for (final seed in seeds)
      if (!played.contains(seed)) seed,
  ];
  final pool = fresh.isEmpty ? seeds : fresh;
  return pool[random.nextInt(pool.length)];
}

/// The difficulty list of [drawCount] that holds [seed], or null for a seed
/// in none of them (for example from a `/klondike?seed=42` link).
KlondikeDifficulty? difficultyOfSeed(int drawCount, int seed) {
  final lists = klondikeDeals[drawCount];
  if (lists == null) return null;
  for (final difficulty in KlondikeDifficulty.values) {
    if (lists[difficulty.name]?.contains(seed) ?? false) return difficulty;
  }
  return null;
}
