import '../../l10n/app_localizations.dart';
import 'mahjong_difficulty.dart';

/// Texts of the difficulty levels. Apart from [MahjongDifficulty], which the
/// offline tool uses without Flutter.
extension MahjongDifficultyTexts on MahjongDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    MahjongDifficulty.easy => l10n.difficultyEasy,
    MahjongDifficulty.medium => l10n.difficultyMedium,
    MahjongDifficulty.hard => l10n.difficultyHard,
  };

  /// What a deal of this level is.
  String hint(AppLocalizations l10n) => switch (this) {
    MahjongDifficulty.easy => l10n.mahjongEasyHint,
    MahjongDifficulty.medium => l10n.mahjongMediumHint,
    MahjongDifficulty.hard => l10n.mahjongHardHint,
  };
}

/// Names of the layouts, by layout id (the variants of the records).
final mahjongLayoutNames = <String, String Function(AppLocalizations)>{
  'pyramid': (l10n) => l10n.mahjongLayoutPyramid,
  'turtle': (l10n) => l10n.mahjongLayoutTurtle,
};
