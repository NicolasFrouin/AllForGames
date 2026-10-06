import '../../l10n/app_localizations.dart';
import 'mahjong_controller.dart';
import 'mahjong_difficulty.dart';

/// Texts of the difficulty levels. Apart from [MahjongDifficulty], which the
/// offline tool uses without Flutter.
extension MahjongDifficultyTexts on MahjongDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    MahjongDifficulty.easy => l10n.difficultyEasy,
    MahjongDifficulty.medium => l10n.difficultyMedium,
    MahjongDifficulty.hard => l10n.difficultyHard,
  };

  /// What a deal of this level is, in [mode].
  String hint(
    AppLocalizations l10n, [
    MahjongMode mode = MahjongMode.classic,
  ]) => switch ((mode, this)) {
    (MahjongMode.classic, MahjongDifficulty.easy) => l10n.mahjongEasyHint,
    (MahjongMode.classic, MahjongDifficulty.medium) => l10n.mahjongMediumHint,
    (MahjongMode.classic, MahjongDifficulty.hard) => l10n.mahjongHardHint,
    (MahjongMode.tray, MahjongDifficulty.easy) => l10n.mahjongTrayEasyHint,
    (MahjongMode.tray, MahjongDifficulty.medium) => l10n.mahjongTrayMediumHint,
    (MahjongMode.tray, MahjongDifficulty.hard) => l10n.mahjongTrayHardHint,
  };
}

/// Texts of the modes.
extension MahjongModeTexts on MahjongMode {
  String label(AppLocalizations l10n) => switch (this) {
    MahjongMode.classic => l10n.mahjongModeClassic,
    MahjongMode.tray => l10n.mahjongModeTray,
  };

  /// How the mode plays.
  String hint(AppLocalizations l10n) => switch (this) {
    MahjongMode.classic => l10n.mahjongClassicModeHint,
    MahjongMode.tray => l10n.mahjongTrayModeHint,
  };
}

/// Names of the layouts, by layout id.
final mahjongLayoutNames = <String, String Function(AppLocalizations)>{
  'pyramid': (l10n) => l10n.mahjongLayoutPyramid,
  'turtle': (l10n) => l10n.mahjongLayoutTurtle,
};

/// Names of the variants of the records: each layout in classic mode, then
/// in tray mode.
final mahjongVariantNames = <String, String Function(AppLocalizations)>{
  for (final mode in MahjongMode.values)
    for (final MapEntry(key: layoutId, value: name)
        in mahjongLayoutNames.entries)
      mahjongVariant(mode, layoutId): mode == MahjongMode.classic
          ? name
          : (l10n) => l10n.mahjongTrayVariant(name(l10n)),
};
