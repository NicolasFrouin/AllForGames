import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../games/freecell/freecell_controller.dart';
import '../games/freecell/freecell_difficulty.dart';
import '../games/klondike/klondike_controller.dart';
import '../games/klondike/klondike_difficulty.dart';
import '../games/mahjong/mahjong_controller.dart';
import '../games/mahjong/mahjong_difficulty.dart';
import '../games/mahjong/mahjong_layout.dart';
import '../games/minesweeper/minesweeper_controller.dart';
import '../games/minesweeper/minesweeper_difficulty.dart';
import '../games/spider/spider_controller.dart';
import '../games/spider/spider_difficulty.dart';
import '../games/tripeaks/tripeaks_controller.dart';
import '../games/tripeaks/tripeaks_difficulty.dart';
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

  /// The game whose records reach it, or [allGamesId].
  final String gameId;
  final IconData icon;
  final int goal;

  /// Gets the records of every game: filters them itself.
  final int Function(List<GameRecord> records) _progress;

  /// Progress toward [goal] in [records] (of every game), capped at [goal].
  int progress(List<GameRecord> records) => min(_progress(records), goal);

  bool isReached(List<GameRecord> records) => progress(records) >= goal;
}

/// [Achievement.gameId] of the achievements reached with any game.
const allGamesId = 'all';

/// The games of the achievements, in the order of the achievements page.
const achievementGameIds = [
  KlondikeController.gameId,
  FreeCellController.gameId,
  SpiderController.gameId,
  TriPeaksController.gameId,
  MahjongController.gameId,
  MinesweeperController.gameId,
  allGamesId,
];

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
  Achievement(
    id: 'klondike.hardWin',
    gameId: KlondikeController.gameId,
    icon: Icons.psychology,
    goal: 1,
    progress: _klondikeHardWins,
  ),
  Achievement(
    id: 'freecell.firstWin',
    gameId: FreeCellController.gameId,
    icon: Icons.lock_open,
    goal: 1,
    progress: _freecellWinCount,
  ),
  Achievement(
    id: 'freecell.wins10',
    gameId: FreeCellController.gameId,
    icon: Icons.view_module,
    goal: 10,
    progress: _freecellWinCount,
  ),
  Achievement(
    id: 'freecell.hardWin',
    gameId: FreeCellController.gameId,
    icon: Icons.psychology_alt,
    goal: 1,
    progress: _freecellHardWins,
  ),
  Achievement(
    id: 'freecell.noUndoWin',
    gameId: FreeCellController.gameId,
    icon: Icons.cleaning_services,
    goal: 1,
    progress: _freecellNoUndoWins,
  ),
  Achievement(
    id: 'freecell.oneCellWin',
    gameId: FreeCellController.gameId,
    icon: Icons.looks_one,
    goal: 1,
    progress: _freecellOneCellWins,
  ),
  Achievement(
    id: 'freecell.fastWin',
    gameId: FreeCellController.gameId,
    icon: Icons.speed,
    goal: 1,
    progress: _freecellFastWins,
  ),
  Achievement(
    id: 'spider.firstWin',
    gameId: SpiderController.gameId,
    icon: Icons.hub,
    goal: 1,
    progress: _spiderWinCount,
  ),
  Achievement(
    id: 'spider.twoSuitsWin',
    gameId: SpiderController.gameId,
    icon: Icons.contrast,
    goal: 1,
    progress: _spiderTwoSuitsWins,
  ),
  Achievement(
    id: 'spider.fourSuitsWin',
    gameId: SpiderController.gameId,
    icon: Icons.pest_control,
    goal: 1,
    progress: _spiderFourSuitsWins,
  ),
  Achievement(
    id: 'spider.wins10',
    gameId: SpiderController.gameId,
    icon: Icons.route,
    goal: 10,
    progress: _spiderWinCount,
  ),
  Achievement(
    id: 'spider.noUndoWin',
    gameId: SpiderController.gameId,
    icon: Icons.pan_tool,
    goal: 1,
    progress: _spiderNoUndoWins,
  ),
  Achievement(
    id: 'spider.streak3',
    gameId: SpiderController.gameId,
    icon: Icons.whatshot,
    goal: 3,
    progress: _spiderBestStreak,
  ),
  Achievement(
    id: 'tripeaks.firstWin',
    gameId: TriPeaksController.gameId,
    icon: Icons.flag,
    goal: 1,
    progress: _tripeaksWinCount,
  ),
  Achievement(
    id: 'tripeaks.wins10',
    gameId: TriPeaksController.gameId,
    icon: Icons.hiking,
    goal: 10,
    progress: _tripeaksWinCount,
  ),
  Achievement(
    id: 'tripeaks.hardWin',
    gameId: TriPeaksController.gameId,
    icon: Icons.filter_hdr,
    goal: 1,
    progress: _tripeaksHardWins,
  ),
  Achievement(
    id: 'tripeaks.run10',
    gameId: TriPeaksController.gameId,
    icon: Icons.ac_unit,
    goal: 10,
    progress: _tripeaksLongestRun,
  ),
  Achievement(
    id: 'tripeaks.stock10Win',
    gameId: TriPeaksController.gameId,
    icon: Icons.savings,
    goal: 1,
    progress: _tripeaksStock10Wins,
  ),
  Achievement(
    id: 'tripeaks.noUndoWin',
    gameId: TriPeaksController.gameId,
    icon: Icons.verified_user,
    goal: 1,
    progress: _tripeaksNoUndoWins,
  ),
  Achievement(
    id: 'mahjong.firstWin',
    gameId: MahjongController.gameId,
    icon: Icons.done_all,
    goal: 1,
    progress: _mahjongWinCount,
  ),
  Achievement(
    id: 'mahjong.turtleWin',
    gameId: MahjongController.gameId,
    icon: Icons.terrain,
    goal: 1,
    progress: _mahjongTurtleWins,
  ),
  Achievement(
    id: 'mahjong.hardWin',
    gameId: MahjongController.gameId,
    icon: Icons.sports_martial_arts,
    goal: 1,
    progress: _mahjongHardWins,
  ),
  Achievement(
    id: 'mahjong.noHintWin',
    gameId: MahjongController.gameId,
    icon: Icons.visibility,
    goal: 1,
    progress: _mahjongNoHintWins,
  ),
  Achievement(
    id: 'mahjong.combo10',
    gameId: MahjongController.gameId,
    icon: Icons.auto_awesome,
    goal: 10,
    progress: _mahjongBestCombo,
  ),
  Achievement(
    id: 'mahjong.wins10',
    gameId: MahjongController.gameId,
    icon: Icons.stars,
    goal: 10,
    progress: _mahjongWinCount,
  ),
  Achievement(
    id: 'mahjong.trayWin',
    gameId: MahjongController.gameId,
    icon: Icons.view_week,
    goal: 1,
    progress: _mahjongTrayWinCount,
  ),
  Achievement(
    id: 'mahjong.trayHardWin',
    gameId: MahjongController.gameId,
    icon: Icons.local_fire_department,
    goal: 1,
    progress: _mahjongTrayHardWins,
  ),
  Achievement(
    id: 'mahjong.trayNoUndoWin',
    gameId: MahjongController.gameId,
    icon: Icons.back_hand,
    goal: 1,
    progress: _mahjongTrayCleanWins,
  ),
  Achievement(
    id: 'mahjong.trayWins10',
    gameId: MahjongController.gameId,
    icon: Icons.inventory_2,
    goal: 10,
    progress: _mahjongTrayWinCount,
  ),
  Achievement(
    id: 'minesweeper.firstWin',
    gameId: MinesweeperController.gameId,
    icon: Icons.outlined_flag,
    goal: 1,
    progress: _minesweeperWinCount,
  ),
  Achievement(
    id: 'minesweeper.intermediateWin',
    gameId: MinesweeperController.gameId,
    icon: Icons.grid_on,
    goal: 1,
    progress: _minesweeperIntermediateWins,
  ),
  Achievement(
    id: 'minesweeper.expertWin',
    gameId: MinesweeperController.gameId,
    icon: Icons.local_police,
    goal: 1,
    progress: _minesweeperExpertWins,
  ),
  Achievement(
    id: 'minesweeper.fastWin',
    gameId: MinesweeperController.gameId,
    icon: Icons.timer,
    goal: 1,
    progress: _minesweeperFastWins,
  ),
  Achievement(
    id: 'minesweeper.noFlagWin',
    gameId: MinesweeperController.gameId,
    icon: Icons.do_not_touch,
    goal: 1,
    progress: _minesweeperNoFlagWins,
  ),
  Achievement(
    id: 'minesweeper.wins10',
    gameId: MinesweeperController.gameId,
    icon: Icons.emoji_flags,
    goal: 10,
    progress: _minesweeperWinCount,
  ),
  Achievement(
    id: 'all.everyGame',
    gameId: allGamesId,
    icon: Icons.category,
    // Every game of achievementGameIds but allGamesId (a test checks it).
    goal: 6,
    progress: _gamesWon,
  ),
  Achievement(
    id: 'all.wins100',
    gameId: allGamesId,
    icon: Icons.diamond,
    goal: 100,
    progress: _winCount,
  ),
  Achievement(
    id: 'all.hours10',
    gameId: allGamesId,
    icon: Icons.hourglass_full,
    goal: 10,
    progress: _hoursPlayed,
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

int _klondikeHardWins(List<GameRecord> records) =>
    _klondikeWins(records)
        .where((record) => record.difficulty == KlondikeDifficulty.hard.name)
        .length;

int _klondikeBestStreak(List<GameRecord> records) =>
    GameStats.from(_klondike(records)).bestStreak;

Iterable<GameRecord> _winsOf(List<GameRecord> records, String gameId) =>
    records.where((record) => record.gameId == gameId && record.won);

int _freecellWinCount(List<GameRecord> records) =>
    _winsOf(records, FreeCellController.gameId).length;

int _freecellHardWins(List<GameRecord> records) => _winsOf(
  records,
  FreeCellController.gameId,
).where((record) => record.difficulty == FreeCellDifficulty.hard.name).length;

int _freecellNoUndoWins(List<GameRecord> records) => _winsOf(
  records,
  FreeCellController.gameId,
).where((record) => record.undos == 0).length;

// A missing counter is 0, as on the FreeCell win dialog.
int _freecellOneCellWins(List<GameRecord> records) =>
    _winsOf(records, FreeCellController.gameId)
        .where(
          (record) =>
              (record.details[FreeCellStatKeys.mostFreeCellsUsed] ?? 0) <= 1,
        )
        .length;

int _freecellFastWins(List<GameRecord> records) => _winsOf(
  records,
  FreeCellController.gameId,
).where((record) => record.playTime < const Duration(minutes: 4)).length;

int _spiderWinCount(List<GameRecord> records) =>
    _winsOf(records, SpiderController.gameId).length;

int _spiderTwoSuitsWins(List<GameRecord> records) => _winsOf(
  records,
  SpiderController.gameId,
).where((record) => record.variant == SpiderDifficulty.medium.variant).length;

int _spiderFourSuitsWins(List<GameRecord> records) => _winsOf(
  records,
  SpiderController.gameId,
).where((record) => record.variant == SpiderDifficulty.hard.variant).length;

int _spiderNoUndoWins(List<GameRecord> records) => _winsOf(
  records,
  SpiderController.gameId,
).where((record) => record.undos == 0).length;

int _spiderBestStreak(List<GameRecord> records) => GameStats.from(
  records.where((record) => record.gameId == SpiderController.gameId),
).bestStreak;

int _tripeaksWinCount(List<GameRecord> records) =>
    _winsOf(records, TriPeaksController.gameId).length;

int _tripeaksHardWins(List<GameRecord> records) => _winsOf(
  records,
  TriPeaksController.gameId,
).where((record) => record.difficulty == TriPeaksDifficulty.hard.name).length;

/// The longest run of any TriPeaks game, won or not.
int _tripeaksLongestRun(List<GameRecord> records) => records
    .where((record) => record.gameId == TriPeaksController.gameId)
    .fold(
      0,
      (best, record) =>
          max(best, record.details[TriPeaksStatKeys.longestRun] ?? 0),
    );

int _tripeaksStock10Wins(List<GameRecord> records) =>
    _winsOf(records, TriPeaksController.gameId)
        .where(
          (record) => (record.details[TriPeaksStatKeys.stockLeft] ?? 0) >= 10,
        )
        .length;

/// Wins above Easy without undo: the greedy player wins every Easy deal
/// without one, and an undo shows the next stock card.
int _tripeaksNoUndoWins(List<GameRecord> records) =>
    _winsOf(records, TriPeaksController.gameId)
        .where(
          (record) =>
              record.undos == 0 &&
              record.difficulty != null &&
              record.difficulty != TriPeaksDifficulty.easy.name,
        )
        .length;

int _mahjongWinCount(List<GameRecord> records) =>
    _winsOf(records, MahjongController.gameId).length;

/// Turtles cleared, in the classic mode or the tray mode (the discs mode
/// does not clear the board).
int _mahjongTurtleWins(List<GameRecord> records) =>
    _winsOf(records, MahjongController.gameId)
        .where(
          (record) => switch (mahjongModeAndLayout(record.variant)) {
            (MahjongMode.discs, _) => false,
            (_, final layoutId) => layoutId == turtleLayout.id,
          },
        )
        .length;

int _mahjongHardWins(List<GameRecord> records) => _winsOf(
  records,
  MahjongController.gameId,
).where((record) => record.difficulty == MahjongDifficulty.hard.name).length;

int _mahjongNoHintWins(List<GameRecord> records) => _winsOf(
  records,
  MahjongController.gameId,
).where((record) => (record.details[MahjongStatKeys.hints] ?? 0) == 0).length;

/// The longest combo of any Mahjong game, won or not.
int _mahjongBestCombo(List<GameRecord> records) => records
    .where((record) => record.gameId == MahjongController.gameId)
    .fold(
      0,
      (best, record) =>
          max(best, record.details[MahjongStatKeys.bestCombo] ?? 0),
    );

Iterable<GameRecord> _mahjongTrayWins(List<GameRecord> records) =>
    _winsOf(records, MahjongController.gameId).where(
      (record) => mahjongModeAndLayout(record.variant).$1 == MahjongMode.tray,
    );

int _mahjongTrayWinCount(List<GameRecord> records) =>
    _mahjongTrayWins(records).length;

int _mahjongTrayHardWins(List<GameRecord> records) =>
    _mahjongTrayWins(records)
        .where((record) => record.difficulty == MahjongDifficulty.hard.name)
        .length;

/// Tray wins above Easy with no undo and no hint: each tile chosen alone,
/// no second try.
int _mahjongTrayCleanWins(List<GameRecord> records) =>
    _mahjongTrayWins(records)
        .where(
          (record) =>
              (record.difficulty == MahjongDifficulty.medium.name ||
                  record.difficulty == MahjongDifficulty.hard.name) &&
              record.undos == 0 &&
              (record.details[MahjongStatKeys.hints] ?? 0) == 0,
        )
        .length;

int _minesweeperWinCount(List<GameRecord> records) =>
    _winsOf(records, MinesweeperController.gameId).length;

int _minesweeperIntermediateWins(List<GameRecord> records) =>
    _winsOf(records, MinesweeperController.gameId)
        .where(
          (record) => record.difficulty == MinesweeperDifficulty.medium.name,
        )
        .length;

int _minesweeperExpertWins(List<GameRecord> records) =>
    _winsOf(records, MinesweeperController.gameId)
        .where((record) => record.difficulty == MinesweeperDifficulty.hard.name)
        .length;

/// Beginner wins in under 30 s: a 3BV of about 15 at 0.5 3BV/s, quick but
/// within reach of a casual player.
int _minesweeperFastWins(List<GameRecord> records) =>
    _winsOf(records, MinesweeperController.gameId)
        .where(
          (record) =>
              record.difficulty == MinesweeperDifficulty.easy.name &&
              record.playTime < const Duration(seconds: 30),
        )
        .length;

/// Intermediate or Expert wins without placing a flag: every mine kept in
/// mind. A won board flags its mines itself, but not as flags placed.
int _minesweeperNoFlagWins(List<GameRecord> records) =>
    _winsOf(records, MinesweeperController.gameId)
        .where(
          (record) =>
              (record.difficulty == MinesweeperDifficulty.medium.name ||
                  record.difficulty == MinesweeperDifficulty.hard.name) &&
              record.details[MinesweeperStatKeys.flagsPlaced] == 0,
        )
        .length;

/// How many of the games have at least one win.
int _gamesWon(List<GameRecord> records) => {
  for (final record in records)
    if (record.won && achievementGameIds.contains(record.gameId)) record.gameId,
}.length;

int _winCount(List<GameRecord> records) =>
    records.where((record) => record.won).length;

/// Whole hours of play, in every game.
int _hoursPlayed(List<GameRecord> records) => records
    .fold(Duration.zero, (total, record) => total + record.playTime)
    .inHours;
