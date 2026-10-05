import 'dart:math';

import 'spider_deals.dart';
import 'spider_difficulty.dart';

/// A random seed of `spiderDeals[difficulty]`, so the deal can be won. Seeds
/// in [played] are skipped while others are left; once every seed of the
/// list was played, any of them can come again.
int pickSpiderSeed({
  required SpiderDifficulty difficulty,
  required Set<int> played,
  required Random random,
}) {
  final seeds = spiderDeals[difficulty.name]!;
  final fresh = [
    for (final seed in seeds)
      if (!played.contains(seed)) seed,
  ];
  final pool = fresh.isEmpty ? seeds : fresh;
  return pool[random.nextInt(pool.length)];
}
