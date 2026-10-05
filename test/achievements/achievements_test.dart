import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';

var _order = 0;

/// A game ended after the previous one, by default a slow Klondike Draw 1
/// win with one undo: it reaches only the win-count achievements.
GameRecord game({
  String gameId = 'klondike',
  String variant = 'draw1',
  GameOutcome outcome = GameOutcome.won,
  Duration playTime = const Duration(minutes: 10),
  int undos = 1,
}) {
  final order = _order++;
  return GameRecord(
    gameId: gameId,
    variant: variant,
    seed: order,
    startedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: order)),
    endedAt: DateTime.utc(2026, 1, 1, 0, 30).add(Duration(hours: order)),
    playTime: playTime,
    outcome: outcome,
    moves: 100,
    undos: undos,
    score: 500,
  );
}

GameRecord abandoned({
  String gameId = 'klondike',
  String variant = 'draw1',
  Duration playTime = const Duration(minutes: 10),
  int undos = 1,
}) => game(
  gameId: gameId,
  variant: variant,
  outcome: GameOutcome.abandoned,
  playTime: playTime,
  undos: undos,
);

int progress(String id, List<GameRecord> records) =>
    achievements.firstWhere((a) => a.id == id).progress(records);

void main() {
  test('win counts count only won games, capped at the goal', () {
    final records = [
      for (var i = 0; i < 12; i++) game(),
      for (var i = 0; i < 5; i++) abandoned(),
    ];
    expect(progress('klondike.firstWin', []), 0);
    expect(progress('klondike.firstWin', records), 1);
    expect(progress('klondike.wins10', records), 10);
    expect(progress('klondike.wins50', records), 12);
    expect(progress('klondike.wins10', records.sublist(3)), 9);
  });

  test('an achievement is reached at its goal', () {
    final wins = [for (var i = 0; i < 10; i++) game()];
    final tenWins = achievements.firstWhere((a) => a.id == 'klondike.wins10');
    expect(tenWins.isReached(wins.sublist(1)), isFalse);
    expect(tenWins.isReached(wins), isTrue);
  });

  test('draw3Win needs a won Draw 3 game', () {
    final records = [game(), abandoned(variant: 'draw3')];
    expect(progress('klondike.draw3Win', records), 0);
    expect(
      progress('klondike.draw3Win', [...records, game(variant: 'draw3')]),
      1,
    );
  });

  test('fastWin needs a win in under 5 minutes of play time', () {
    final records = [
      game(playTime: const Duration(minutes: 5)),
      abandoned(playTime: const Duration(minutes: 1)),
    ];
    expect(progress('klondike.fastWin', records), 0);
    final fast = game(playTime: const Duration(minutes: 4, seconds: 59));
    expect(progress('klondike.fastWin', [...records, fast]), 1);
  });

  test('noUndoWin needs a win without any undo', () {
    final records = [game(undos: 1), abandoned(undos: 0)];
    expect(progress('klondike.noUndoWin', records), 0);
    expect(progress('klondike.noUndoWin', [...records, game(undos: 0)]), 1);
  });

  test('streak3 is the best run of wins, broken by an abandoned game', () {
    final records = [game(), game(), abandoned(), game(), game()];
    expect(progress('klondike.streak3', records), 2);
    expect(progress('klondike.streak3', [...records, game(), game()]), 3);
  });

  test('records of another game are ignored', () {
    final other = [
      for (var i = 0; i < 60; i++)
        game(
          gameId: 'freecell',
          variant: 'draw3',
          playTime: const Duration(minutes: 1),
          undos: 0,
        ),
    ];
    for (final achievement in achievements) {
      expect(achievement.progress(other), 0, reason: achievement.id);
    }

    // A game lost in another game type does not break a Klondike streak.
    final streak = [game(), game(), abandoned(gameId: 'freecell'), game()];
    expect(progress('klondike.streak3', streak), 3);
  });
}
