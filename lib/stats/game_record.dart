enum GameOutcome { won, abandoned }

/// One finished (won or abandoned) game, for any game of the app.
///
/// [details] holds the game-specific counters (for example stock recycles in
/// Klondike). Keys ending with `Ms` are durations in milliseconds.
class GameRecord {
  const GameRecord({
    required this.gameId,
    required this.variant,
    required this.seed,
    required this.startedAt,
    required this.endedAt,
    required this.playTime,
    required this.outcome,
    required this.moves,
    required this.undos,
    required this.score,
    this.difficulty,
    this.details = const {},
  });

  factory GameRecord.fromJson(Map<String, Object?> json) => GameRecord(
    gameId: json['gameId'] as String,
    variant: json['variant'] as String,
    seed: json['seed'] as int,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    playTime: Duration(milliseconds: json['playTimeMs'] as int),
    outcome: GameOutcome.values.byName(json['outcome'] as String),
    moves: json['moves'] as int,
    undos: json['undos'] as int,
    score: json['score'] as int,
    difficulty: json['difficulty'] as String?,
    details: {
      for (final MapEntry(:key, :value)
          in ((json['details'] as Map<String, Object?>?) ?? const {}).entries)
        key: value as int,
    },
  );

  final String gameId;
  final String variant;

  /// Seed of the deal, so a game can be replayed.
  final int seed;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Active play time: time with the game on screen and the app visible.
  final Duration playTime;
  final GameOutcome outcome;
  final int moves;
  final int undos;
  final int score;

  /// Difficulty of the deal (for example `hard`), null when the game has no
  /// levels or the deal is not graded (older records too).
  final String? difficulty;
  final Map<String, int> details;

  /// Stays the same when a saved game continues, so a game recorded twice
  /// (for example by two tabs) is stored once.
  String get id => '$gameId-${startedAt.microsecondsSinceEpoch}-$seed';

  bool get won => outcome == GameOutcome.won;

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'variant': variant,
    'seed': seed,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'playTimeMs': playTime.inMilliseconds,
    'outcome': outcome.name,
    'moves': moves,
    'undos': undos,
    'score': score,
    'difficulty': ?difficulty,
    'details': details,
  };
}
