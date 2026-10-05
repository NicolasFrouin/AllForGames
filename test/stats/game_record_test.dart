import 'dart:convert';

import 'package:all_for_games/stats/game_record.dart';
import 'package:flutter_test/flutter_test.dart';

GameRecord roundTrip(GameRecord record) => GameRecord.fromJson(
  jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>,
);

void main() {
  final record = GameRecord(
    gameId: 'klondike',
    variant: 'draw3',
    seed: 42,
    startedAt: DateTime.utc(2026, 3, 1, 10),
    endedAt: DateTime.utc(2026, 3, 1, 10, 7, 30),
    playTime: const Duration(minutes: 6, milliseconds: 250),
    outcome: GameOutcome.won,
    moves: 120,
    undos: 3,
    score: 640,
    details: const {'stockDraws': 40, 'longestThinkMs': 12000},
  );

  test('keeps every field through JSON text', () {
    final restored = roundTrip(record);
    expect(restored.gameId, 'klondike');
    expect(restored.variant, 'draw3');
    expect(restored.seed, 42);
    expect(restored.startedAt, record.startedAt);
    expect(restored.endedAt, record.endedAt);
    expect(restored.playTime, record.playTime);
    expect(restored.outcome, GameOutcome.won);
    expect(restored.won, isTrue);
    expect(restored.moves, 120);
    expect(restored.undos, 3);
    expect(restored.score, 640);
    expect(restored.details, record.details);
  });

  test('saves dates in UTC so local times keep the same moment', () {
    final local = DateTime(2026, 3, 1, 10, 30);
    final restored = roundTrip(
      GameRecord(
        gameId: 'klondike',
        variant: 'draw1',
        seed: 1,
        startedAt: local,
        endedAt: local,
        playTime: Duration.zero,
        outcome: GameOutcome.abandoned,
        moves: 0,
        undos: 0,
        score: 0,
      ),
    );
    expect(restored.startedAt.isUtc, isTrue);
    expect(restored.startedAt.isAtSameMomentAs(local), isTrue);
    expect(restored.won, isFalse);
  });

  test('reads a record saved without details', () {
    final json = record.toJson()..remove('details');
    expect(GameRecord.fromJson(json).details, isEmpty);
  });
}
