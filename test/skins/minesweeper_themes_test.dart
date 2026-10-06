import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_board.dart';
import 'package:all_for_games/games/minesweeper/minesweeper_controller.dart';
import 'package:all_for_games/skins/minesweeper_themes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../games/minesweeper/minesweeper_test_helpers.dart';
import '../helpers/test_stores.dart';

/// The WCAG contrast ratio of two colors, from 1 to 21.
double contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test('classic comes first and is free', () {
    expect(minesweeperThemes.first, same(classicMinesweeperTheme));
    expect(classicMinesweeperTheme.unlockedBy, isNull);
  });

  test('every unlockedBy names a Minesweeper achievement', () {
    for (final theme in minesweeperThemes) {
      if (theme.unlockedBy case final id?) {
        expect(achievementById(id)?.gameId, 'minesweeper', reason: theme.id);
      }
    }
  });

  test('theme ids are unique', () {
    final ids = [for (final theme in minesweeperThemes) theme.id];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('minesweeperThemeById finds a theme, or falls back to classic', () {
    expect(minesweeperThemeById('retro').id, 'retro');
    expect(minesweeperThemeById('unknown'), same(classicMinesweeperTheme));
  });

  test('every theme keeps its numbers, mines and flags readable', () {
    for (final theme in minesweeperThemes) {
      expect(theme.numbers, hasLength(8), reason: theme.id);
      for (final (i, number) in theme.numbers.indexed) {
        expect(
          contrast(number, theme.open),
          greaterThanOrEqualTo(3.5),
          reason: '${theme.id}: ${i + 1}',
        );
      }
      expect(contrast(theme.mine, theme.open), greaterThan(4.5));
      // The flag differs in hue; its pole stands out in any case.
      expect(contrast(theme.flagPole, theme.covered), greaterThan(4));
      expect(contrast(theme.flag, theme.covered), greaterThan(1.7));
    }
  });

  testWidgets('every theme draws a lost board and its preview', (tester) async {
    final stores = await createTestStores();
    for (final theme in minesweeperThemes) {
      final game = MinesweeperController(
        stats: stores.stats,
        saves: stores.saves,
        initialState: cornerBoard,
      );
      addTearDown(game.dispose);
      game
        ..open(cornerTap)
        ..toggleFlag(0)
        ..toggleFlag(at(cornerBoard, 2, 0))
        ..open(at(cornerBoard, 1, 1));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: Column(
              children: [
                MinesweeperThemePreview(theme: theme, width: 30),
                Expanded(
                  child: MinesweeperBoard(controller: game, theme: theme),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: theme.id);
      expect(game.state.isLost, isTrue);
    }
  });
}
