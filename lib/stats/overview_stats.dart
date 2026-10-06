import 'game_record.dart';
import 'game_stats.dart';

/// The finished games of one local calendar day.
class DayActivity {
  const DayActivity(this.day, {this.won = 0, this.notWon = 0});

  /// Local midnight.
  final DateTime day;
  final int won;

  /// Lost or abandoned.
  final int notWon;

  int get played => won + notWon;
}

/// Statistics across every game, for the overview page.
class OverviewStats {
  const OverviewStats({
    required this.overall,
    required this.perGame,
    required this.daysPlayed,
    required this.currentDayStreak,
    required this.bestDayStreak,
    required this.lastDays,
    required this.byHour,
    required this.byWeekday,
    required this.recent,
    this.averageGameTime,
    this.fastestWin,
    this.longestGame,
    this.mostMovesWin,
    this.mostPlayed,
    this.mostTime,
  });

  /// [now] sets today, for the day streak and the last days.
  factory OverviewStats.from(Iterable<GameRecord> records, {DateTime? now}) {
    final sorted = records.toList()
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
    final today = _dayIndex(now ?? DateTime.now());

    final byGame = <String, List<GameRecord>>{};
    for (final record in sorted) {
      (byGame[record.gameId] ??= []).add(record);
    }
    final perGame = {
      for (final MapEntry(:key, :value) in byGame.entries)
        key: GameStats.from(value),
    };

    final days = {
      for (final record in sorted) _dayIndex(record.endedAt),
    }.toList()..sort();
    var run = 0;
    var bestDayStreak = 0;
    for (var i = 0; i < days.length; i++) {
      run = i > 0 && days[i] == days[i - 1] + 1 ? run + 1 : 1;
      if (run > bestDayStreak) bestDayStreak = run;
    }

    final firstDay = today - activityDays + 1;
    final won = List.filled(activityDays, 0);
    final notWon = List.filled(activityDays, 0);
    final byHour = List.filled(24, 0);
    final byWeekday = List.filled(7, 0);
    for (final record in sorted) {
      final local = record.endedAt.toLocal();
      byHour[local.hour]++;
      byWeekday[local.weekday - DateTime.monday]++;
      final day = _dayIndex(record.endedAt) - firstDay;
      if (day < 0 || day >= activityDays) continue;
      if (record.won) {
        won[day]++;
      } else {
        notWon[day]++;
      }
    }

    // Strict comparisons: on a tie, the record reached first holds it.
    GameRecord? fastestWin;
    GameRecord? longestGame;
    GameRecord? mostMovesWin;
    for (final record in sorted) {
      if (longestGame == null || record.playTime > longestGame.playTime) {
        longestGame = record;
      }
      if (!record.won) continue;
      if (fastestWin == null || record.playTime < fastestWin.playTime) {
        fastestWin = record;
      }
      if (mostMovesWin == null || record.moves > mostMovesWin.moves) {
        mostMovesWin = record;
      }
    }

    // On a tie, the favourite is the game played last.
    final byLastPlayed = perGame.entries.toList()
      ..sort((a, b) => a.value.lastPlayedAt!.compareTo(b.value.lastPlayedAt!));
    ({String gameId, int games})? mostPlayed;
    ({String gameId, Duration time})? mostTime;
    for (final MapEntry(key: gameId, value: stats) in byLastPlayed) {
      if (mostPlayed == null || stats.played >= mostPlayed.games) {
        mostPlayed = (gameId: gameId, games: stats.played);
      }
      if (mostTime == null || stats.totalPlayTime >= mostTime.time) {
        mostTime = (gameId: gameId, time: stats.totalPlayTime);
      }
    }

    final overall = GameStats.from(sorted);
    return OverviewStats(
      overall: overall,
      perGame: perGame,
      averageGameTime: sorted.isEmpty
          ? null
          : overall.totalPlayTime ~/ sorted.length,
      daysPlayed: days.length,
      // The streak lives on through today until the player plays.
      currentDayStreak: days.isNotEmpty && today - days.last <= 1 ? run : 0,
      bestDayStreak: bestDayStreak,
      lastDays: [
        for (var i = 0; i < activityDays; i++)
          DayActivity(_localDate(firstDay + i), won: won[i], notWon: notWon[i]),
      ],
      byHour: byHour,
      byWeekday: byWeekday,
      fastestWin: fastestWin,
      longestGame: longestGame,
      mostMovesWin: mostMovesWin,
      mostPlayed: mostPlayed,
      mostTime: mostTime,
      recent: sorted.reversed.take(recentCount).toList(),
    );
  }

  /// Days of [lastDays].
  static const activityDays = 30;

  /// Games in [recent].
  static const recentCount = 10;

  /// Every game together. Its win streaks follow the end times of the games
  /// of every game.
  final GameStats overall;

  /// The stats of each game id of the records, in the order of their first
  /// finished game.
  final Map<String, GameStats> perGame;
  final Duration? averageGameTime;

  /// Local calendar days with at least one finished game.
  final int daysPlayed;

  /// Days in a row with a finished game, up to today, or up to yesterday
  /// while no game is finished today.
  final int currentDayStreak;
  final int bestDayStreak;

  /// The last [activityDays] local days, today last.
  final List<DayActivity> lastDays;

  /// Finished games by local hour of their end, from 0 to 23.
  final List<int> byHour;

  /// Finished games by local weekday of their end, Monday first.
  final List<int> byWeekday;

  /// The won game with the shortest play time.
  final GameRecord? fastestWin;

  /// The game, won or not, with the longest play time.
  final GameRecord? longestGame;
  final GameRecord? mostMovesWin;

  /// The game with the most finished games.
  final ({String gameId, int games})? mostPlayed;

  /// The game with the most play time.
  final ({String gameId, Duration time})? mostTime;

  /// The last [recentCount] finished games, most recent first.
  final List<GameRecord> recent;

  bool get isEmpty => overall.played == 0;
}

/// Days from 1970-01-01 to the local date of [time]. Counting calendar dates,
/// not 24-hour spans, keeps the days of a daylight saving change (23 or 25
/// hours) one day long.
int _dayIndex(DateTime time) {
  final local = time.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;
}

DateTime _localDate(int dayIndex) {
  final utc = DateTime.utc(1970, 1, 1 + dayIndex);
  return DateTime(utc.year, utc.month, utc.day);
}
