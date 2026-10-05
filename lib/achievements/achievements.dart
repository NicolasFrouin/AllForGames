import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../games/klondike/klondike_controller.dart';
import '../stats/game_record.dart';
import '../stats/game_stats.dart';

/// A goal reached from the statistics. Titles and descriptions are translated
/// by [id] in the UI.
class Achievement {
  const Achievement({
    required this.id,
    required this.gameId,
    required this.icon,
    required this.goal,
    required this._progress,
  });

  final String id;
  final String gameId;
  final IconData icon;
  final int goal;

  /// Gets the records of every game: filters them itself.
  final int Function(List<GameRecord> records) _progress;

  /// Progress toward [goal] in [records] (of every game), capped at [goal].
  int progress(List<GameRecord> records) => min(_progress(records), goal);

  bool isReached(List<GameRecord> records) => progress(records) >= goal;
}

const achievements = [
  Achievement(
    id: 'klondike.firstWin',
    gameId: KlondikeController.gameId,
    icon: Icons.emoji_events,
    goal: 1,
    progress: _klondikeWinCount,
  ),
  Achievement(
    id: 'klondike.wins10',
    gameId: KlondikeController.gameId,
    icon: Icons.military_tech,
    goal: 10,
    progress: _klondikeWinCount,
  ),
  Achievement(
    id: 'klondike.wins50',
    gameId: KlondikeController.gameId,
    icon: Icons.workspace_premium,
    goal: 50,
    progress: _klondikeWinCount,
  ),
  Achievement(
    id: 'klondike.draw3Win',
    gameId: KlondikeController.gameId,
    icon: Icons.filter_3,
    goal: 1,
    progress: _klondikeDraw3Wins,
  ),
  Achievement(
    id: 'klondike.fastWin',
    gameId: KlondikeController.gameId,
    icon: Icons.bolt,
    goal: 1,
    progress: _klondikeFastWins,
  ),
  Achievement(
    id: 'klondike.noUndoWin',
    gameId: KlondikeController.gameId,
    icon: Icons.verified,
    goal: 1,
    progress: _klondikeNoUndoWins,
  ),
  Achievement(
    id: 'klondike.streak3',
    gameId: KlondikeController.gameId,
    icon: Icons.local_fire_department,
    goal: 3,
    progress: _klondikeBestStreak,
  ),
];

Achievement? achievementById(String id) {
  for (final achievement in achievements) {
    if (achievement.id == id) return achievement;
  }
  return null;
}

Iterable<GameRecord> _klondike(List<GameRecord> records) =>
    records.where((record) => record.gameId == KlondikeController.gameId);

Iterable<GameRecord> _klondikeWins(List<GameRecord> records) =>
    _klondike(records).where((record) => record.won);

int _klondikeWinCount(List<GameRecord> records) =>
    _klondikeWins(records).length;

int _klondikeDraw3Wins(List<GameRecord> records) =>
    _klondikeWins(records).where((record) => record.variant == 'draw3').length;

int _klondikeFastWins(List<GameRecord> records) =>
    _klondikeWins(records)
        .where((record) => record.playTime < const Duration(minutes: 5))
        .length;

int _klondikeNoUndoWins(List<GameRecord> records) =>
    _klondikeWins(records).where((record) => record.undos == 0).length;

int _klondikeBestStreak(List<GameRecord> records) =>
    GameStats.from(_klondike(records)).bestStreak;
