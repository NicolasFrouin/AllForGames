import '../../l10n/app_localizations.dart';
import 'mahjong_controller.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_shapes.dart';

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
  ]) => switch ((mode.usesTray, this)) {
    (false, MahjongDifficulty.easy) => l10n.mahjongEasyHint,
    (false, MahjongDifficulty.medium) => l10n.mahjongMediumHint,
    (false, MahjongDifficulty.hard) => l10n.mahjongHardHint,
    (true, MahjongDifficulty.easy) => l10n.mahjongTrayEasyHint,
    (true, MahjongDifficulty.medium) => l10n.mahjongTrayMediumHint,
    (true, MahjongDifficulty.hard) => l10n.mahjongTrayHardHint,
  };
}

/// Texts of the modes.
extension MahjongModeTexts on MahjongMode {
  String label(AppLocalizations l10n) => switch (this) {
    MahjongMode.classic => l10n.mahjongModeClassic,
    MahjongMode.tray => l10n.mahjongModeTray,
    MahjongMode.discs => l10n.mahjongModeDiscs,
  };

  /// How the mode plays.
  String hint(AppLocalizations l10n) => switch (this) {
    MahjongMode.classic => l10n.mahjongClassicModeHint,
    MahjongMode.tray => l10n.mahjongTrayModeHint,
    MahjongMode.discs => l10n.mahjongDiscsModeHint,
  };
}

/// Texts of the shapes.
extension MahjongShapeTexts on MahjongShape {
  /// The classic shape is named after the layout of [difficulty].
  String label(AppLocalizations l10n, MahjongDifficulty difficulty) =>
      switch (this) {
        MahjongShape.generated => l10n.mahjongShapeGenerated,
        MahjongShape.classic => mahjongLayoutNames[difficulty.layoutId]!(l10n),
      };

  String hint(AppLocalizations l10n, MahjongDifficulty difficulty) =>
      switch (this) {
        MahjongShape.generated => l10n.mahjongShapeGeneratedHint(
          difficulty.shape.maxLayers,
        ),
        MahjongShape.classic => l10n.mahjongShapeClassicHint,
      };
}

/// Names of the layouts, by layout id.
final mahjongLayoutNames = <String, String Function(AppLocalizations)>{
  'pyramid': (l10n) => l10n.mahjongLayoutPyramid,
  'turtle': (l10n) => l10n.mahjongLayoutTurtle,
  generatedLayoutId: (l10n) => l10n.mahjongLayoutRandom,
};

/// Names of the variants of the records: each layout in classic mode, then
/// in tray mode.
final mahjongVariantNames = <String, String Function(AppLocalizations)>{
  for (final mode in MahjongMode.values)
    for (final MapEntry(key: layoutId, value: name)
        in mahjongLayoutNames.entries)
      mahjongVariant(mode, layoutId): switch (mode) {
        MahjongMode.classic => name,
        MahjongMode.tray => (l10n) => l10n.mahjongTrayVariant(name(l10n)),
        MahjongMode.discs => (l10n) => l10n.mahjongDiscsVariant(name(l10n)),
      },
};
