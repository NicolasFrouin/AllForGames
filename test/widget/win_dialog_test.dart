import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/win_dialog.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/minesweeper_themes.dart';
import 'package:all_for_games/skins/tile_styles.dart';
import 'package:all_for_games/stats/game_record.dart';
import 'package:all_for_games/stats/game_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_helpers.dart';

/// Records [win] as a game screen does, then opens its win dialog.
Future<void> showWin(WidgetTester tester, GameRecord win) async {
  useSurface(tester);
  final stores = await seededStores([]);
  await stores.stats.add(win);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showWinDialog(
            context,
            stores: stores,
            record: win,
            stats: GameStats.from(stores.stats.records),
          ),
          child: const Text('Show'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show'));
  await tester.pumpAndSettle();
}

Finder unlocked(String id) => find.byKey(ValueKey('unlocked-$id'));

void main() {
  testWidgets('a Mahjong win shows the tile style it unlocks', (tester) async {
    await showWin(
      tester,
      record(
        gameId: 'mahjong',
        variant: 'pyramid',
        difficulty: 'easy',
        details: {'hints': 1, 'bestCombo': 3},
      ),
    );

    final firstWin = unlocked('mahjong.firstWin');
    expect(
      find.descendant(
        of: firstWin,
        matching: find.text('New tile style: Jade'),
      ),
      findsOneWidget,
    );
    final preview = tester.widget<TileStylePreview>(
      find.descendant(of: firstWin, matching: find.byType(TileStylePreview)),
    );
    expect(preview.style.id, 'jade');
    expect(unlocked('mahjong.noHintWin'), findsNothing);
  });

  testWidgets('a FreeCell win shows the card backs it unlocks', (tester) async {
    await showWin(
      tester,
      record(
        gameId: 'freecell',
        variant: 'classic',
        difficulty: 'hard',
        undos: 2,
        playTime: const Duration(minutes: 9),
        details: {'mostFreeCellsUsed': 3},
      ),
    );

    expect(
      find.descendant(
        of: unlocked('freecell.firstWin'),
        matching: find.text('New card back: Azure'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: unlocked('freecell.hardWin'),
        matching: find.text('New card back: Labyrinth'),
      ),
      findsOneWidget,
    );
    expect(unlocked('freecell.fastWin'), findsNothing);
  });

  testWidgets('a TriPeaks win shows the card backs it unlocks', (tester) async {
    await showWin(
      tester,
      record(
        gameId: 'tripeaks',
        variant: 'classic',
        difficulty: 'hard',
        details: {'longestRun': 12, 'stockLeft': 4},
      ),
    );

    for (final (id, name) in [
      ('tripeaks.firstWin', 'Peaks'),
      ('tripeaks.hardWin', 'Aurora'),
      ('tripeaks.run10', 'Ember'),
      ('tripeaks.noUndoWin', 'Tide'),
    ]) {
      expect(
        find.descendant(
          of: unlocked(id),
          matching: find.text('New card back: $name'),
        ),
        findsOneWidget,
        reason: id,
      );
    }
    final preview = tester.widget<CardBackView>(
      find.descendant(
        of: unlocked('tripeaks.firstWin'),
        matching: find.byType(CardBackView),
      ),
    );
    expect(preview.skin.id, 'peaks');
    expect(unlocked('tripeaks.stock10Win'), findsNothing);
    expect(unlocked('tripeaks.wins10'), findsNothing);
  });

  testWidgets('a Minesweeper win shows the themes it unlocks', (tester) async {
    // A fast Beginner win, with flags: first win and fast win.
    await showWin(
      tester,
      record(
        gameId: 'minesweeper',
        variant: 'classic',
        difficulty: 'easy',
        playTime: const Duration(seconds: 25),
        details: {'flagsPlaced': 3},
      ),
    );

    for (final (id, name) in [
      ('minesweeper.firstWin', 'Ocean'),
      ('minesweeper.fastWin', 'Candy'),
    ]) {
      expect(
        find.descendant(
          of: unlocked(id),
          matching: find.text('New Minesweeper theme: $name'),
        ),
        findsOneWidget,
        reason: id,
      );
    }
    final preview = tester.widget<MinesweeperThemePreview>(
      find.descendant(
        of: unlocked('minesweeper.firstWin'),
        matching: find.byType(MinesweeperThemePreview),
      ),
    );
    expect(preview.theme.id, 'ocean');
    expect(unlocked('minesweeper.noFlagWin'), findsNothing);
  });
}
