import 'dart:math';

import 'game_record.dart';

/// Aggregated statistics computed from a list of [GameRecord].
class GameStats {
  const GameStats({
    required this.played,
    required this.won,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalPlayTime,
    required this.totalMoves,
    required this.totalUndos,
    required this.detailAverages,
    this.bestTime,
    this.averageWinTime,
    this.fewestMoves,
    this.bestScore,
    this.lastPlayedAt,
  });

  factory GameStats.from(Iterable<GameRecord> records) {
    final sorted = records.toList()
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
    final wins = sorted.where((r) => r.won).toList();

    var currentStreak = 0;
    var bestStreak = 0;
    for (final record in sorted) {
      currentStreak = record.won ? currentStreak + 1 : 0;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
    }

    final detailTotals = <String, int>{};
    for (final record in sorted) {
      for (final MapEntry(:key, :value) in record.details.entries) {
        detailTotals[key] = (detailTotals[key] ?? 0) + value;
      }
    }

    return GameStats(
      played: sorted.length,
      won: wins.length,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalPlayTime: sorted.fold(Duration.zero, (sum, r) => sum + r.playTime),
      totalMoves: sorted.fold(0, (sum, r) => sum + r.moves),
      totalUndos: sorted.fold(0, (sum, r) => sum + r.undos),
      detailAverages: {
        for (final MapEntry(:key, :value) in detailTotals.entries)
          key: value / sorted.length,
      },
      bestTime: wins.isEmpty
          ? null
          : wins.map((r) => r.playTime).reduce((a, b) => a < b ? a : b),
      averageWinTime: wins.isEmpty
          ? null
          : wins.fold(Duration.zero, (sum, r) => sum + r.playTime) ~/
                wins.length,
      fewestMoves: wins.isEmpty ? null : wins.map((r) => r.moves).reduce(min),
      bestScore: sorted.isEmpty ? null : sorted.map((r) => r.score).reduce(max),
      lastPlayedAt: sorted.lastOrNull?.endedAt,
    );
  }

  final int played;
  final int won;

  /// Wins in a row up to the most recent game.
  final int currentStreak;
  final int bestStreak;
  final Duration totalPlayTime;
  final int totalMoves;
  final int totalUndos;

  /// Average of each detail counter per game played.
  final Map<String, double> detailAverages;

  /// Fastest won game.
  final Duration? bestTime;
  final Duration? averageWinTime;

  /// Fewest moves in a won game.
  final int? fewestMoves;
  final int? bestScore;
  final DateTime? lastPlayedAt;

  double get winRate => played == 0 ? 0 : won / played;
}
