import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/game_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game that ended on January [day].
GameRecord game(
  int day, {
  bool won = true,
  int minutes = 5,
  int moves = 100,
  int undos = 0,
  int score = 0,
  Map<String, int> details = const {},
}) => GameRecord(
  gameId: 'klondike',
  variant: 'draw1',
  seed: day,
  startedAt: DateTime.utc(2026, 1, day),
  endedAt: DateTime.utc(2026, 1, day, 1),
  playTime: Duration(minutes: minutes),
  outcome: won ? GameOutcome.won : GameOutcome.abandoned,
  moves: moves,
  undos: undos,
  score: score,
  details: details,
);

void main() {
  test('no games gives zero counts and no bests', () {
    final stats = GameStats.from([]);
    expect(stats.played, 0);
    expect(stats.winRate, 0);
    expect(stats.currentStreak, 0);
    expect(stats.bestTime, isNull);
    expect(stats.averageWinTime, isNull);
    expect(stats.fewestMoves, isNull);
    expect(stats.bestScore, isNull);
    expect(stats.lastPlayedAt, isNull);
    expect(stats.detailAverages, isEmpty);
  });

  test('counts games, wins and win rate', () {
    final stats = GameStats.from([
      game(1),
      game(2, won: false),
      game(3),
      game(4),
    ]);
    expect(stats.played, 4);
    expect(stats.won, 3);
    expect(stats.winRate, 0.75);
  });

  test('streaks follow the end date, not the list order', () {
    final results = [true, true, false, true, true, true, false, true];
    final stats = GameStats.from([
      for (var day = results.length; day >= 1; day--)
        game(day, won: results[day - 1]),
    ]);
    expect(stats.bestStreak, 3);
    expect(stats.currentStreak, 1);
  });

  test('a loss as the last game resets the current streak', () {
    final stats = GameStats.from([game(1), game(2), game(3, won: false)]);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 2);
  });

  test('best time, average time and fewest moves only count wins', () {
    final stats = GameStats.from([
      game(1, minutes: 5, moves: 120),
      game(2, minutes: 3, moves: 150),
      game(3, won: false, minutes: 1, moves: 10),
    ]);
    expect(stats.bestTime, const Duration(minutes: 3));
    expect(stats.averageWinTime, const Duration(minutes: 4));
    expect(stats.fewestMoves, 120);
  });

  test('best score counts every game', () {
    final stats = GameStats.from([
      game(1, score: 300),
      game(2, won: false, score: 500),
    ]);
    expect(stats.bestScore, 500);
  });

  test('sums totals and keeps the last end date', () {
    final stats = GameStats.from([
      game(3, minutes: 2, moves: 30, undos: 1),
      game(1, won: false, minutes: 4, moves: 50, undos: 2),
      game(2, minutes: 6, moves: 70),
    ]);
    expect(stats.totalPlayTime, const Duration(minutes: 12));
    expect(stats.totalMoves, 150);
    expect(stats.totalUndos, 3);
    expect(stats.lastPlayedAt, DateTime.utc(2026, 1, 3, 1));
  });

  test('detail averages divide each total by the games played', () {
    final stats = GameStats.from([
      game(1, details: {'stockDraws': 10, 'cardsRevealed': 4}),
      game(2, won: false, details: {'stockDraws': 20}),
      game(3),
      game(4, details: {'stockDraws': 30}),
    ]);
    expect(stats.detailAverages, {'stockDraws': 15.0, 'cardsRevealed': 1.0});
  });
}
