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
  String? difficulty,
  Map<String, int> details = const {},
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
    difficulty: difficulty,
    details: details,
  );
}

GameRecord abandoned({
  String gameId = 'klondike',
  String variant = 'draw1',
  Duration playTime = const Duration(minutes: 10),
  int undos = 1,
  String? difficulty,
  Map<String, int> details = const {},
}) => game(
  gameId: gameId,
  variant: variant,
  outcome: GameOutcome.abandoned,
  playTime: playTime,
  undos: undos,
  difficulty: difficulty,
  details: details,
);

/// A game of [gameId] that reaches every achievement of its game it can.
GameRecord perfect(String gameId, {String? variant}) => game(
  gameId: gameId,
  variant:
      variant ??
      switch (gameId) {
        'klondike' => 'draw3',
        'spider' => 'suits4',
        'mahjong' => 'turtle',
        _ => 'classic',
      },
  playTime: const Duration(minutes: 1),
  undos: 0,
  difficulty: 'hard',
  details: const {
    'mostFreeCellsUsed': 0,
    'hints': 0,
    'bestCombo': 50,
    'longestRun': 28,
    'stockLeft': 23,
    'flagsPlaced': 0,
  },
);

/// Slow FreeCell, Spider (2 suits) and Mahjong (Pyramid) wins with an undo,
/// a hint and free cells: they reach only their games' win counts.
GameRecord freecell({GameOutcome outcome = GameOutcome.won}) => game(
  gameId: 'freecell',
  variant: 'classic',
  outcome: outcome,
  difficulty: 'medium',
  details: const {'mostFreeCellsUsed': 3},
);

GameRecord spider({GameOutcome outcome = GameOutcome.won}) =>
    game(gameId: 'spider', variant: 'suits1', outcome: outcome);

GameRecord mahjong({GameOutcome outcome = GameOutcome.won}) => game(
  gameId: 'mahjong',
  variant: 'pyramid',
  outcome: outcome,
  difficulty: 'easy',
  details: const {'hints': 1, 'bestCombo': 3},
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

  test('hardWin needs a won Hard game', () {
    final records = [
      game(difficulty: 'medium'),
      game(),
      abandoned(difficulty: 'hard'),
    ];
    expect(progress('klondike.hardWin', records), 0);
    expect(
      progress('klondike.hardWin', [...records, game(difficulty: 'hard')]),
      1,
    );
  });

  test('streak3 is the best run of wins, broken by an abandoned game', () {
    final records = [game(), game(), abandoned(), game(), game()];
    expect(progress('klondike.streak3', records), 2);
    expect(progress('klondike.streak3', [...records, game(), game()]), 3);
  });

  test('records of another game are ignored', () {
    const games = [
      'klondike',
      'freecell',
      'spider',
      'tripeaks',
      'mahjong',
      'minesweeper',
    ];
    for (final gameId in games) {
      final others = [
        for (final other in games)
          if (other != gameId)
            for (var i = 0; i < 60; i++) ...[
              perfect(other),
              perfect(other, variant: 'suits2'),
            ],
      ];
      for (final achievement in achievements) {
        if (achievement.gameId != gameId) continue;
        expect(achievement.progress(others), 0, reason: achievement.id);
      }
    }

    // A game lost in another game type does not break a Klondike streak.
    final streak = [game(), game(), abandoned(gameId: 'freecell'), game()];
    expect(progress('klondike.streak3', streak), 3);
  });

  group('FreeCell', () {
    test('win counts count only won FreeCell games', () {
      final records = [
        for (var i = 0; i < 11; i++) freecell(),
        freecell(outcome: GameOutcome.abandoned),
        game(),
      ];
      expect(progress('freecell.firstWin', []), 0);
      expect(progress('freecell.firstWin', records), 1);
      expect(progress('freecell.wins10', records), 10);
      expect(progress('freecell.wins10', records.sublist(2)), 9);
    });

    test('hardWin needs a won Hard game', () {
      final records = [
        freecell(),
        abandoned(gameId: 'freecell', variant: 'classic', difficulty: 'hard'),
      ];
      expect(progress('freecell.hardWin', records), 0);
      final hard = game(
        gameId: 'freecell',
        variant: 'classic',
        difficulty: 'hard',
      );
      expect(progress('freecell.hardWin', [...records, hard]), 1);
    });

    test('noUndoWin needs a win without any undo', () {
      final records = [
        freecell(),
        abandoned(gameId: 'freecell', variant: 'classic', undos: 0),
      ];
      expect(progress('freecell.noUndoWin', records), 0);
      final clean = game(gameId: 'freecell', variant: 'classic', undos: 0);
      expect(progress('freecell.noUndoWin', [...records, clean]), 1);
    });

    test('oneCellWin needs a win with at most one free cell used', () {
      GameRecord using(int cells, {GameOutcome outcome = GameOutcome.won}) =>
          game(
            gameId: 'freecell',
            variant: 'classic',
            outcome: outcome,
            details: {'mostFreeCellsUsed': cells},
          );
      final records = [using(2), using(1, outcome: GameOutcome.abandoned)];
      expect(progress('freecell.oneCellWin', records), 0);
      expect(progress('freecell.oneCellWin', [...records, using(1)]), 1);
      expect(progress('freecell.oneCellWin', [...records, using(0)]), 1);
    });

    test('fastWin needs a win in under 4 minutes of play time', () {
      GameRecord inTime(Duration playTime, {GameOutcome? outcome}) => game(
        gameId: 'freecell',
        variant: 'classic',
        playTime: playTime,
        outcome: outcome ?? GameOutcome.won,
      );
      final records = [
        inTime(const Duration(minutes: 4)),
        inTime(const Duration(minutes: 1), outcome: GameOutcome.abandoned),
      ];
      expect(progress('freecell.fastWin', records), 0);
      final fast = inTime(const Duration(minutes: 3, seconds: 59));
      expect(progress('freecell.fastWin', [...records, fast]), 1);
    });
  });

  group('Spider', () {
    test('win counts count only won Spider games', () {
      final records = [
        for (var i = 0; i < 10; i++) spider(),
        spider(outcome: GameOutcome.abandoned),
        game(),
      ];
      expect(progress('spider.firstWin', records), 1);
      expect(progress('spider.wins10', records), 10);
      expect(progress('spider.wins10', records.sublist(1)), 9);
    });

    test('twoSuitsWin and fourSuitsWin need a win with that many suits', () {
      final records = [
        spider(),
        abandoned(gameId: 'spider', variant: 'suits2'),
        abandoned(gameId: 'spider', variant: 'suits4'),
      ];
      expect(progress('spider.twoSuitsWin', records), 0);
      expect(progress('spider.fourSuitsWin', records), 0);

      final twoSuits = [...records, game(gameId: 'spider', variant: 'suits2')];
      expect(progress('spider.twoSuitsWin', twoSuits), 1);
      expect(progress('spider.fourSuitsWin', twoSuits), 0);

      final fourSuits = [...records, game(gameId: 'spider', variant: 'suits4')];
      expect(progress('spider.twoSuitsWin', fourSuits), 0);
      expect(progress('spider.fourSuitsWin', fourSuits), 1);
    });

    test('noUndoWin needs a win without any undo', () {
      final records = [
        spider(),
        abandoned(gameId: 'spider', variant: 'suits1', undos: 0),
      ];
      expect(progress('spider.noUndoWin', records), 0);
      final clean = game(gameId: 'spider', variant: 'suits1', undos: 0);
      expect(progress('spider.noUndoWin', [...records, clean]), 1);
    });

    test('streak3 is the best run of Spider wins, broken by an abandoned '
        'Spider game only', () {
      final records = [
        spider(),
        spider(),
        spider(outcome: GameOutcome.abandoned),
        spider(),
        abandoned(),
        spider(),
      ];
      expect(progress('spider.streak3', records), 2);
      expect(progress('spider.streak3', [...records, spider()]), 3);
    });
  });

  group('TriPeaks', () {
    /// By default a Medium win with an undo, a short run and few stock cards
    /// left: it reaches only the win counts.
    GameRecord tripeaks({
      GameOutcome outcome = GameOutcome.won,
      String? difficulty = 'medium',
      int undos = 1,
      int longestRun = 6,
      int stockLeft = 3,
    }) => game(
      gameId: 'tripeaks',
      variant: 'classic',
      outcome: outcome,
      difficulty: difficulty,
      undos: undos,
      details: {'longestRun': longestRun, 'stockLeft': stockLeft},
    );

    test('win counts count only won TriPeaks games', () {
      final records = [
        for (var i = 0; i < 10; i++) tripeaks(),
        tripeaks(outcome: GameOutcome.abandoned),
        game(),
      ];
      expect(progress('tripeaks.firstWin', records), 1);
      expect(progress('tripeaks.wins10', records), 10);
      expect(progress('tripeaks.wins10', records.sublist(1)), 9);
      for (final id in [
        'tripeaks.hardWin',
        'tripeaks.stock10Win',
        'tripeaks.noUndoWin',
      ]) {
        expect(progress(id, records), 0, reason: id);
      }
    });

    test('hardWin needs a won Hard game', () {
      final records = [
        tripeaks(),
        tripeaks(outcome: GameOutcome.abandoned, difficulty: 'hard'),
      ];
      expect(progress('tripeaks.hardWin', records), 0);
      final hard = tripeaks(difficulty: 'hard');
      expect(progress('tripeaks.hardWin', [...records, hard]), 1);
    });

    test('run10 is the longest run of any TriPeaks game, won or not', () {
      final records = [
        tripeaks(longestRun: 9),
        tripeaks(outcome: GameOutcome.abandoned, longestRun: 7),
        game(details: const {'longestRun': 12}),
      ];
      expect(progress('tripeaks.run10', records), 9);
      final long = tripeaks(outcome: GameOutcome.abandoned, longestRun: 11);
      expect(progress('tripeaks.run10', [...records, long]), 10);
    });

    test('stock10Win needs a win with 10 stock cards left or more', () {
      final records = [
        tripeaks(stockLeft: 9),
        tripeaks(outcome: GameOutcome.abandoned, stockLeft: 23),
      ];
      expect(progress('tripeaks.stock10Win', records), 0);
      final saved = tripeaks(stockLeft: 10);
      expect(progress('tripeaks.stock10Win', [...records, saved]), 1);
    });

    test('noUndoWin needs a Medium or Hard win without any undo', () {
      final records = [
        tripeaks(),
        tripeaks(difficulty: 'easy', undos: 0),
        tripeaks(difficulty: null, undos: 0),
        tripeaks(outcome: GameOutcome.abandoned, undos: 0),
      ];
      expect(progress('tripeaks.noUndoWin', records), 0);
      expect(
        progress('tripeaks.noUndoWin', [...records, tripeaks(undos: 0)]),
        1,
      );
      final hard = tripeaks(difficulty: 'hard', undos: 0);
      expect(progress('tripeaks.noUndoWin', [...records, hard]), 1);
    });
  });

  group('Mahjong', () {
    test('win counts count only won Mahjong games', () {
      final records = [
        for (var i = 0; i < 10; i++) mahjong(),
        mahjong(outcome: GameOutcome.abandoned),
        game(),
      ];
      expect(progress('mahjong.firstWin', records), 1);
      expect(progress('mahjong.wins10', records), 10);
      expect(progress('mahjong.wins10', records.sublist(1)), 9);
    });

    test('turtleWin needs a win on the Turtle', () {
      final records = [
        mahjong(),
        abandoned(gameId: 'mahjong', variant: 'turtle'),
      ];
      expect(progress('mahjong.turtleWin', records), 0);
      final turtle = game(gameId: 'mahjong', variant: 'turtle');
      expect(progress('mahjong.turtleWin', [...records, turtle]), 1);
    });

    test('hardWin needs a won Hard game', () {
      final records = [
        mahjong(),
        abandoned(gameId: 'mahjong', variant: 'turtle', difficulty: 'hard'),
      ];
      expect(progress('mahjong.hardWin', records), 0);
      final hard = game(
        gameId: 'mahjong',
        variant: 'turtle',
        difficulty: 'hard',
      );
      expect(progress('mahjong.hardWin', [...records, hard]), 1);
    });

    test('noHintWin needs a win without hints', () {
      final records = [
        mahjong(),
        abandoned(gameId: 'mahjong', variant: 'pyramid', details: {'hints': 0}),
      ];
      expect(progress('mahjong.noHintWin', records), 0);
      final sharp = game(
        gameId: 'mahjong',
        variant: 'pyramid',
        details: {'hints': 0},
      );
      expect(progress('mahjong.noHintWin', [...records, sharp]), 1);
    });

    test('combo10 is the best combo of any Mahjong game, won or not', () {
      GameRecord combo(int pairs, {String gameId = 'mahjong'}) => abandoned(
        gameId: gameId,
        variant: 'turtle',
        details: {'bestCombo': pairs},
      );
      expect(progress('mahjong.combo10', [mahjong(), combo(7), combo(4)]), 7);
      expect(progress('mahjong.combo10', [combo(12, gameId: 'freecell')]), 0);
      expect(progress('mahjong.combo10', [combo(7), combo(12)]), 10);
    });

    test('turtleWin counts a Turtle win in either mode', () {
      final pyramid = game(gameId: 'mahjong', variant: 'tray-pyramid');
      expect(progress('mahjong.turtleWin', [pyramid]), 0);
      final turtle = game(gameId: 'mahjong', variant: 'tray-turtle');
      expect(progress('mahjong.turtleWin', [pyramid, turtle]), 1);
    });

    group('in tray mode', () {
      /// A tray game, by default a Medium Turtle win with an undo and a hint.
      GameRecord tray({
        GameOutcome outcome = GameOutcome.won,
        String difficulty = 'medium',
        int undos = 1,
        int hints = 1,
      }) => game(
        gameId: 'mahjong',
        variant: 'tray-turtle',
        outcome: outcome,
        undos: undos,
        difficulty: difficulty,
        details: {'hints': hints},
      );

      test('win counts count only won Tray games', () {
        final records = [
          for (var i = 0; i < 9; i++) tray(),
          tray(outcome: GameOutcome.lost),
          tray(outcome: GameOutcome.abandoned),
          for (var i = 0; i < 3; i++) mahjong(),
        ];
        expect(progress('mahjong.trayWin', records.sublist(9)), 0);
        expect(progress('mahjong.trayWin', records), 1);
        expect(progress('mahjong.trayWins10', records), 9);
        expect(progress('mahjong.trayWins10', [...records, tray()]), 10);
        expect(progress('mahjong.wins10', records), 10, reason: 'both modes');
      });

      test('trayHardWin needs a won Hard Tray game', () {
        final records = [
          tray(),
          tray(difficulty: 'hard', outcome: GameOutcome.lost),
          perfect('mahjong'),
        ];
        expect(progress('mahjong.trayHardWin', records), 0);
        expect(
          progress('mahjong.trayHardWin', [
            ...records,
            tray(difficulty: 'hard'),
          ]),
          1,
        );
      });

      test('trayNoUndoWin needs a Medium or Hard Tray win without undo or '
          'hint', () {
        final records = [
          tray(undos: 0),
          tray(hints: 0),
          tray(undos: 0, hints: 0, difficulty: 'easy'),
          tray(undos: 0, hints: 0, outcome: GameOutcome.lost),
          perfect('mahjong'),
        ];
        expect(progress('mahjong.trayNoUndoWin', records), 0);
        expect(
          progress('mahjong.trayNoUndoWin', [
            ...records,
            tray(undos: 0, hints: 0),
          ]),
          1,
        );
      });
    });
  });

  group('Minesweeper', () {
    GameRecord minesweeper({
      String difficulty = 'easy',
      Duration playTime = const Duration(minutes: 2),
      int flags = 3,
      GameOutcome outcome = GameOutcome.won,
    }) => game(
      gameId: 'minesweeper',
      variant: 'classic',
      outcome: outcome,
      playTime: playTime,
      undos: 0,
      difficulty: difficulty,
      details: {'flagsPlaced': flags},
    );

    test('win counts count only won Minesweeper games', () {
      final records = [
        minesweeper(),
        minesweeper(outcome: GameOutcome.lost),
        minesweeper(outcome: GameOutcome.abandoned),
      ];
      expect(progress('minesweeper.firstWin', records), 1);
      expect(progress('minesweeper.wins10', records), 1);
      final ten = [for (var i = 0; i < 10; i++) minesweeper()];
      expect(progress('minesweeper.wins10', ten), 10);
    });

    test('intermediateWin and expertWin need a win at that level', () {
      final lost = [
        minesweeper(difficulty: 'medium', outcome: GameOutcome.lost),
        minesweeper(difficulty: 'hard', outcome: GameOutcome.lost),
        minesweeper(),
      ];
      expect(progress('minesweeper.intermediateWin', lost), 0);
      expect(progress('minesweeper.expertWin', lost), 0);

      final medium = [...lost, minesweeper(difficulty: 'medium')];
      expect(progress('minesweeper.intermediateWin', medium), 1);
      expect(progress('minesweeper.expertWin', medium), 0);
      final hard = [...lost, minesweeper(difficulty: 'hard')];
      expect(progress('minesweeper.expertWin', hard), 1);
    });

    test('fastWin needs a Beginner win in under 30 seconds', () {
      final slow = [
        minesweeper(playTime: const Duration(seconds: 30)),
        minesweeper(difficulty: 'medium', playTime: const Duration(seconds: 9)),
        minesweeper(
          playTime: const Duration(seconds: 9),
          outcome: GameOutcome.lost,
        ),
      ];
      expect(progress('minesweeper.fastWin', slow), 0);
      final fast = minesweeper(playTime: const Duration(seconds: 29));
      expect(progress('minesweeper.fastWin', [...slow, fast]), 1);
    });

    test('noFlagWin needs an Intermediate or Expert win without a flag', () {
      final others = [
        minesweeper(flags: 0),
        minesweeper(difficulty: 'medium', flags: 1),
        minesweeper(difficulty: 'hard', flags: 0, outcome: GameOutcome.lost),
      ];
      expect(progress('minesweeper.noFlagWin', others), 0);
      for (final difficulty in ['medium', 'hard']) {
        final clean = minesweeper(difficulty: difficulty, flags: 0);
        expect(
          progress('minesweeper.noFlagWin', [...others, clean]),
          1,
          reason: difficulty,
        );
      }
    });
  });

  group('all games', () {
    test('everyGame needs a win in each game of the achievements', () {
      final games = achievementGameIds.where((id) => id != allGamesId);
      final everyGame = achievementById('all.everyGame')!;
      expect(everyGame.goal, games.length);
      final wins = [for (final gameId in games) perfect(gameId)];
      expect(everyGame.isReached(wins), isTrue);
      expect(everyGame.isReached(wins.skip(1).toList()), isFalse);
    });

    test('everyGame counts the games won at least once', () {
      final records = [
        game(),
        game(),
        freecell(),
        spider(outcome: GameOutcome.abandoned),
        mahjong(outcome: GameOutcome.abandoned),
      ];
      expect(progress('all.everyGame', records), 2);
      expect(progress('all.everyGame', [...records, mahjong()]), 3);
      expect(progress('all.everyGame', [...records, mahjong(), spider()]), 4);
    });

    test('wins100 counts the wins of every game', () {
      final records = [
        for (var i = 0; i < 40; i++) ...[game(), freecell(), abandoned()],
        for (var i = 0; i < 19; i++) spider(),
      ];
      expect(progress('all.wins100', records), 99);
      expect(progress('all.wins100', [...records, mahjong()]), 100);
    });

    test('hours10 counts the whole hours of play of every game', () {
      GameRecord played(Duration playTime, String gameId) =>
          abandoned(gameId: gameId, variant: 'classic', playTime: playTime);
      final records = [
        played(const Duration(hours: 4), 'klondike'),
        played(const Duration(hours: 3, minutes: 30), 'spider'),
        played(const Duration(hours: 2, minutes: 29), 'mahjong'),
      ];
      expect(progress('all.hours10', records), 9);
      final more = played(const Duration(minutes: 1), 'freecell');
      expect(progress('all.hours10', [...records, more]), 10);
    });
  });
}
