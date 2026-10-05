import 'dart:math';

import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/klondike/klondike_controller.dart';
import 'package:all_for_games/games/klondike/klondike_state.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a played game shows on the hub and in the statistics', (
    tester,
  ) async {
    await startApp(tester);
    expect(textOf(tester, 'summary-klondike'), startsWith('Not played'));

    await tester.tap(find.byKey(const ValueKey('game-klondike')));
    await tester.pumpAndSettle();
    await tapStock(tester);
    expect(textOf(tester, 'moves-value'), '1');

    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'summary-klondike'), startsWith('1 played'));
    expect(valueOf(tester, 'overall-played'), '1');

    await tester.tap(find.byKey(const ValueKey('stats-klondike')));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 'stat-Played'), '1');
    expect(valueOf(tester, 'stat-Won'), '0');
  });

  testWidgets('drags a card onto another tableau pile', (tester) async {
    final (:seed, :from, :to) = findTableauMove();
    final card = KlondikeState.deal(Random(seed)).tableau[from].last;
    await startApp(tester, '/klondike?seed=$seed');

    final cardFinder = find.byKey(ValueKey(card.id));
    final targetSlot = find.byKey(ValueKey('tableau-$to'));
    // The top strip is the part of a card that stays visible in a pile.
    final gesture = await tester.startGesture(
      tester.getTopLeft(cardFinder) + const Offset(10, 6),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(targetSlot) + const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(textOf(tester, 'moves-value'), '1');
    expect(tester.getTopLeft(cardFinder).dx, tester.getTopLeft(targetSlot).dx);
  });

  testWidgets('a recorded game is saved in browser storage', (tester) async {
    await startApp(tester, '/klondike?seed=42');
    await tapStock(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final saved = (await StatsStore.load()).recordsFor(
      KlondikeController.gameId,
    );
    expect(saved, hasLength(1));
    expect(saved.single.seed, 42);
    expect(saved.single.moves, 1);
    expect(saved.single.outcome, GameOutcome.abandoned);
  });
}

/// Starts the app on empty real storage (localStorage on web).
Future<void> startApp(WidgetTester tester, [String location = '/']) async {
  await SharedPreferencesAsync().clear();
  final stats = await StatsStore.load();
  await tester.pumpWidget(
    AllForGamesApp(stats: stats, initialLocation: location),
  );
  await tester.pumpAndSettle();
}

Future<void> tapStock(WidgetTester tester) async {
  // The top stock card covers the slot and draws on tap too.
  await tester.tap(find.byKey(const ValueKey('stock')), warnIfMissed: false);
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Text of the `value` child of the widget keyed [key].
String valueOf(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byKey(const ValueKey('value')),
      ),
    )
    .data!;

/// The first deal where a tableau top card can go onto another tableau pile.
({int seed, int from, int to}) findTableauMove() {
  for (var seed = 1; seed <= 1000; seed++) {
    final state = KlondikeState.deal(Random(seed));
    for (var from = 0; from < 7; from++) {
      for (var to = 0; to < 7; to++) {
        if (state.canMove(PileRef.tableau(from), 1, PileRef.tableau(to))) {
          return (seed: seed, from: from, to: to);
        }
      }
    }
  }
  throw StateError('No tableau to tableau move in seeds 1 to 1000');
}
