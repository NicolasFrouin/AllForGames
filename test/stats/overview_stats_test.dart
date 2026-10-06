import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/overview_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game that ended at [endedAt] (local time when not UTC).
GameRecord game(
  DateTime endedAt, {
  String gameId = 'klondike',
  bool won = true,
  bool lost = false,
  Duration playTime = const Duration(minutes: 5),
  int moves = 100,
}) => GameRecord(
  gameId: gameId,
  variant: 'draw1',
  seed: endedAt.microsecondsSinceEpoch,
  startedAt: endedAt.subtract(playTime),
  endedAt: endedAt,
  playTime: playTime,
  outcome: lost
      ? GameOutcome.lost
      : won
      ? GameOutcome.won
      : GameOutcome.abandoned,
  moves: moves,
  undos: 0,
  score: 0,
);

/// Local noon of 2026-01-[day].
DateTime jan(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 1, day, hour, minute);

OverviewStats overview(List<GameRecord> records, {DateTime? now}) =>
    OverviewStats.from(records, now: now ?? jan(31));

void main() {
  test('no games gives zeros, empty charts and no records', () {
    final stats = overview([]);
    expect(stats.isEmpty, isTrue);
    expect(stats.overall.played, 0);
    expect(stats.perGame, isEmpty);
    expect(stats.averageGameTime, isNull);
    expect(stats.daysPlayed, 0);
    expect(stats.currentDayStreak, 0);
    expect(stats.bestDayStreak, 0);
    expect(stats.lastDays, hasLength(OverviewStats.activityDays));
    expect(stats.lastDays.every((day) => day.played == 0), isTrue);
    expect(stats.byHour, List.filled(24, 0));
    expect(stats.byWeekday, List.filled(7, 0));
    expect(stats.fastestWin, isNull);
    expect(stats.longestGame, isNull);
    expect(stats.mostMovesWin, isNull);
    expect(stats.mostPlayed, isNull);
    expect(stats.mostTime, isNull);
    expect(stats.recent, isEmpty);
  });

  test('totals add every game of every game id', () {
    final stats = overview([
      game(jan(1), playTime: const Duration(minutes: 2), moves: 50),
      game(jan(2), gameId: 'freecell', won: false, moves: 10),
      game(jan(3), gameId: 'spider', playTime: const Duration(minutes: 8)),
    ]);
    expect(stats.overall.played, 3);
    expect(stats.overall.won, 2);
    expect(stats.overall.totalPlayTime, const Duration(minutes: 15));
    expect(stats.overall.totalMoves, 160);
    expect(stats.averageGameTime, const Duration(minutes: 5));
    expect(stats.perGame.keys, ['klondike', 'freecell', 'spider']);
    expect(stats.perGame['freecell']!.won, 0);
  });

  test('win streaks run across games, in end time order', () {
    // Given out of order: the end times set the order.
    final stats = overview([
      game(jan(5), gameId: 'spider'),
      game(jan(1)),
      game(jan(4), gameId: 'freecell'),
      game(jan(2), won: false),
      game(jan(3), gameId: 'mahjong'),
      game(jan(6), gameId: 'freecell', won: false),
      game(jan(7)),
    ]);
    expect(stats.overall.bestStreak, 3);
    expect(stats.overall.currentStreak, 1);
  });

  test('records of an unknown game count, under their id', () {
    final stats = overview([
      game(jan(1), gameId: 'future-game', playTime: const Duration(hours: 1)),
      game(jan(2), gameId: 'future-game'),
      game(jan(3)),
    ]);
    expect(stats.overall.played, 3);
    expect(stats.perGame['future-game']!.played, 2);
    expect(stats.mostPlayed, (gameId: 'future-game', games: 2));
    expect(stats.longestGame!.gameId, 'future-game');
  });

  group('days', () {
    test('two games on each side of midnight are two days in a row', () {
      final stats = overview([
        game(jan(10, 23, 59)),
        game(jan(11, 0, 1)),
      ], now: jan(11, 0, 2));
      expect(stats.daysPlayed, 2);
      expect(stats.bestDayStreak, 2);
      expect(stats.currentDayStreak, 2);
    });

    test('several games on one day count one day', () {
      final stats = overview([
        game(jan(10, 0, 0)),
        game(jan(10, 12)),
        game(jan(10, 23, 59)),
      ], now: jan(10, 23, 59));
      expect(stats.daysPlayed, 1);
      expect(stats.bestDayStreak, 1);
      expect(stats.currentDayStreak, 1);
    });

    test('the best day streak is the longest run, a gap breaks it', () {
      final stats = overview([
        for (final day in [1, 2, 3, 5, 6, 7, 8, 10, 11]) game(jan(day)),
      ], now: jan(20));
      expect(stats.daysPlayed, 9);
      expect(stats.bestDayStreak, 4);
      expect(stats.currentDayStreak, 0);
    });

    test('the current day streak lasts until the end of the next day', () {
      final records = [game(jan(8)), game(jan(9)), game(jan(10, 23, 30))];
      expect(overview(records, now: jan(10, 23, 45)).currentDayStreak, 3);
      expect(overview(records, now: jan(11, 23, 59)).currentDayStreak, 3);
      expect(overview(records, now: jan(12, 0, 1)).currentDayStreak, 0);
    });

    test('streaks span daylight saving changes', () {
      // Every day through the spring and autumn changes of Europe (March 29,
      // October 25) and the USA (March 8, November 1), one just after
      // midnight, the next just before: 23 or 25 hour days must not merge
      // nor split days, whatever the time zone of the test machine.
      final spring = [
        for (var day = 1; day <= 40; day++)
          game(DateTime(2026, 3, day, day.isEven ? 0 : 23, 30)),
      ];
      final autumn = [
        for (var day = 15; day <= 40; day++)
          game(DateTime(2026, 10, day, day.isEven ? 0 : 23, 30)),
      ];
      final stats = OverviewStats.from([
        ...spring,
        ...autumn,
      ], now: DateTime(2026, 11, 10, 0, 15));
      expect(stats.daysPlayed, 66);
      expect(stats.bestDayStreak, 40);
      expect(stats.currentDayStreak, 26);
    });

    test('stored records in UTC count on their local day and hour', () {
      final endedAt = DateTime(2026, 5, 1, 23, 30);
      final stats = OverviewStats.from([
        game(endedAt.toUtc()),
      ], now: DateTime(2026, 5, 1, 23, 45));
      expect(stats.lastDays.last.day, DateTime(2026, 5, 1));
      expect(stats.lastDays.last.won, 1);
      expect(stats.byHour[23], 1);
      expect(stats.byWeekday[DateTime.friday - 1], 1);
    });
  });

  group('activity', () {
    test('the last 30 days end today, split into won and not won', () {
      final stats = overview([
        game(DateTime(2025, 12, 31)), // 31 days before today: left out.
        game(jan(1), won: false),
        game(jan(15)),
        game(jan(15), won: false),
        game(jan(15, 18), lost: true),
        game(jan(15, 20)),
        game(jan(30, 8)),
      ], now: jan(30, 9));
      final days = stats.lastDays;
      expect(days.first.day, DateTime(2026, 1, 1));
      expect(days.last.day, DateTime(2026, 1, 30));
      expect((days.first.won, days.first.notWon), (0, 1));
      expect((days[14].won, days[14].notWon), (2, 2));
      expect(days.last.played, 1);
      expect(days.fold(0, (sum, day) => sum + day.played), 6);
    });

    test('the last 30 days are local midnights over a time change', () {
      final stats = OverviewStats.from([], now: DateTime(2026, 4, 10, 12));
      final days = stats.lastDays.map((activity) => activity.day).toList();
      expect(days.first, DateTime(2026, 3, 12));
      expect(days.last, DateTime(2026, 4, 10));
      for (var i = 1; i < days.length; i++) {
        final previous = days[i - 1];
        expect(
          days[i],
          DateTime(previous.year, previous.month, previous.day + 1),
        );
      }
    });

    test('games by hour and weekday follow the local end time', () {
      // January 5, 2026 is a Monday.
      final stats = overview([
        game(jan(5, 9, 10)),
        game(jan(5, 9, 50), won: false),
        game(jan(6, 21)),
        game(jan(11, 0, 5)),
      ]);
      expect(stats.byHour[9], 2);
      expect(stats.byHour[21], 1);
      expect(stats.byHour[0], 1);
      expect(stats.byWeekday, [2, 1, 0, 0, 0, 0, 1]);
    });
  });

  group('records', () {
    test('fastest win and most moves skip the games not won', () {
      final stats = overview([
        game(jan(1), won: false, playTime: const Duration(seconds: 5)),
        game(jan(2), won: false, moves: 999),
        game(jan(3), gameId: 'freecell', playTime: const Duration(minutes: 3)),
        game(jan(4), playTime: const Duration(minutes: 9), moves: 300),
      ]);
      expect(stats.fastestWin!.endedAt, jan(3));
      expect(stats.mostMovesWin!.endedAt, jan(4));
    });

    test('the longest game may be a game not won', () {
      final stats = overview([
        game(jan(1)),
        game(jan(2), won: false, playTime: const Duration(hours: 2)),
      ]);
      expect(stats.longestGame!.endedAt, jan(2));
    });

    test('on a tie, the record reached first holds it', () {
      final stats = overview([
        game(jan(2), gameId: 'spider', moves: 80),
        game(jan(1), moves: 80),
        game(jan(3), gameId: 'freecell', moves: 80),
      ]);
      expect(stats.fastestWin!.gameId, 'klondike');
      expect(stats.longestGame!.gameId, 'klondike');
      expect(stats.mostMovesWin!.gameId, 'klondike');
    });

    test('favourite games: the most games and the most time', () {
      final stats = overview([
        game(jan(1), playTime: const Duration(minutes: 1)),
        game(jan(2), playTime: const Duration(minutes: 1)),
        game(jan(3), gameId: 'mahjong', playTime: const Duration(minutes: 9)),
      ]);
      expect(stats.mostPlayed, (gameId: 'klondike', games: 2));
      expect(stats.mostTime, (
        gameId: 'mahjong',
        time: const Duration(minutes: 9),
      ));
    });

    test('on a tie, the favourite is the game played last', () {
      final stats = overview([
        game(jan(1), gameId: 'freecell'),
        game(jan(2)),
        game(jan(3), gameId: 'freecell'),
        game(jan(4)),
      ]);
      expect(stats.mostPlayed, (gameId: 'klondike', games: 2));
      expect(stats.mostTime, (
        gameId: 'klondike',
        time: const Duration(minutes: 10),
      ));
    });
  });

  test('recent games: the last 10, most recent first', () {
    final stats = overview([
      for (var day = 12; day >= 1; day--) game(jan(day), won: day.isEven),
    ]);
    expect(stats.recent.map((record) => record.endedAt.day), [
      for (var day = 12; day >= 3; day--) day,
    ]);
  });
}
