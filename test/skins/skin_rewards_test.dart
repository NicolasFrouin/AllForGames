import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/l10n/app_localizations.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/minesweeper_themes.dart';
import 'package:all_for_games/skins/skin_rewards.dart';
import 'package:all_for_games/skins/tile_styles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('every achievement unlocks exactly one skin', () {
    for (final achievement in achievements) {
      final skins = [
        for (final skin in cardBacks)
          if (skin.unlockedBy == achievement.id) skin.id,
        for (final style in tileStyles)
          if (style.unlockedBy == achievement.id) style.id,
        for (final theme in minesweeperThemes)
          if (theme.unlockedBy == achievement.id) theme.id,
      ];
      expect(skins, hasLength(1), reason: achievement.id);
    }
  });

  test('a reward is the card back or the tile style of its achievement', () {
    final azure = skinRewardOf('freecell.firstWin')!;
    expect((azure.kind, azure.id), (SkinKind.cardBack, 'azure'));
    final jade = skinRewardOf('mahjong.firstWin')!;
    expect((jade.kind, jade.id), (SkinKind.tileStyle, 'jade'));
    final ocean = skinRewardOf('minesweeper.firstWin')!;
    expect((ocean.kind, ocean.id), (SkinKind.minesweeperTheme, 'ocean'));
    expect(skinRewardOf('unknown'), isNull);
  });

  test('a reward says what kind of skin it gives', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    final azure = skinRewardOf('freecell.firstWin')!;
    final jade = skinRewardOf('mahjong.firstWin')!;
    expect(azure.rewardText(en), 'Reward: Azure card back');
    expect(azure.unlockedText(fr), 'Nouveau dos de cartes : Azur');
    expect(jade.rewardText(en), 'Reward: Jade tiles');
    expect(jade.rewardText(fr), 'Récompense : tuiles Jade');
    expect(jade.unlockedText(en), 'New tile style: Jade');
    expect(jade.unlockedText(fr), 'Nouveau style de tuiles : Jade');
    final retro = skinRewardOf('minesweeper.wins10')!;
    expect(retro.rewardText(en), 'Reward: Retro theme');
    expect(retro.rewardText(fr), 'Récompense : thème Rétro');
    expect(retro.unlockedText(en), 'New Minesweeper theme: Retro');
    expect(retro.unlockedText(fr), 'Nouveau thème de Démineur : Rétro');
  });

  testWidgets('every reward has a preview', (tester) async {
    final rewards = [for (final a in achievements) skinRewardOf(a.id)!];
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [for (final reward in rewards) reward.preview(24)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    int count(SkinKind kind) => rewards.where((r) => r.kind == kind).length;
    expect(find.byType(CardBackView), findsNWidgets(count(SkinKind.cardBack)));
    expect(
      find.byType(TileStylePreview),
      findsNWidgets(count(SkinKind.tileStyle)),
    );
    expect(
      find.byType(MinesweeperThemePreview),
      findsNWidgets(count(SkinKind.minesweeperTheme)),
    );
  });
}
