import 'dart:math';

import 'klondike_deals.dart';

/// A random seed of [klondikeDeals] for [drawCount] (every difficulty), so
/// the deal can be won. Seeds in [played] are skipped while others are left;
/// once every seed was played, any of them can come again.
int pickDealSeed({
  required int drawCount,
  required Set<int> played,
  required Random random,
}) {
  final seeds = [...klondikeDeals[drawCount]!.values.expand((seeds) => seeds)];
  final fresh = [
    for (final seed in seeds)
      if (!played.contains(seed)) seed,
  ];
  final pool = fresh.isEmpty ? seeds : fresh;
  return pool[random.nextInt(pool.length)];
}
