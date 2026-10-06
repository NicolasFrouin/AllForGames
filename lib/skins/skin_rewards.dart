import 'package:material_ui/material_ui.dart';

import '../achievements/achievement_texts.dart';
import '../l10n/app_localizations.dart';
import 'card_backs.dart';
import 'minesweeper_themes.dart';
import 'tile_styles.dart';

enum SkinKind { cardBack, tileStyle, minesweeperTheme }

/// A skin that an achievement unlocks: a card back, a Mahjong tile style or
/// a Minesweeper theme.
class SkinReward {
  const SkinReward(this.kind, this.id);

  final SkinKind kind;

  /// Id of the [CardBackSkin], [TileStyle] or [MinesweeperTheme].
  final String id;

  String name(AppLocalizations l10n) => switch (kind) {
    SkinKind.cardBack => cardBackName(id, l10n),
    SkinKind.tileStyle => tileStyleName(id, l10n),
    SkinKind.minesweeperTheme => minesweeperThemeName(id, l10n),
  };

  /// What an achievement gives, on the achievements page.
  String rewardText(AppLocalizations l10n) => switch (kind) {
    SkinKind.cardBack => l10n.achievementReward(name(l10n)),
    SkinKind.tileStyle => l10n.achievementRewardTiles(name(l10n)),
    SkinKind.minesweeperTheme => l10n.achievementRewardMinesweeperTheme(
      name(l10n),
    ),
  };

  /// What a just unlocked achievement gives, in the win dialog.
  String unlockedText(AppLocalizations l10n) => switch (kind) {
    SkinKind.cardBack => l10n.newCardBack(name(l10n)),
    SkinKind.tileStyle => l10n.newTileStyle(name(l10n)),
    SkinKind.minesweeperTheme => l10n.newMinesweeperTheme(name(l10n)),
  };

  /// The skin [width] pixels wide: a card back, a sample tile or a corner
  /// of a board.
  Widget preview(double width) => switch (kind) {
    SkinKind.cardBack => SizedBox(
      width: width,
      height: width * 1.4,
      child: CardBackView(skin: cardBackById(id), width: width),
    ),
    SkinKind.tileStyle => TileStylePreview(
      style: tileStyleById(id),
      width: width,
    ),
    SkinKind.minesweeperTheme => MinesweeperThemePreview(
      theme: minesweeperThemeById(id),
      width: width,
    ),
  };
}

/// The skin that the achievement [achievementId] unlocks, if any.
SkinReward? skinRewardOf(String achievementId) {
  for (final skin in cardBacks) {
    if (skin.unlockedBy == achievementId) {
      return SkinReward(SkinKind.cardBack, skin.id);
    }
  }
  for (final style in tileStyles) {
    if (style.unlockedBy == achievementId) {
      return SkinReward(SkinKind.tileStyle, style.id);
    }
  }
  for (final theme in minesweeperThemes) {
    if (theme.unlockedBy == achievementId) {
      return SkinReward(SkinKind.minesweeperTheme, theme.id);
    }
  }
  return null;
}
