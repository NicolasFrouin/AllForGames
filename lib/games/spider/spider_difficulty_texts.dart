import '../../l10n/app_localizations.dart';
import 'spider_difficulty.dart';

/// Texts of the difficulty levels. Apart from [SpiderDifficulty], which the
/// offline tool uses without Flutter.
extension SpiderDifficultyTexts on SpiderDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    SpiderDifficulty.easy => l10n.difficultyEasy,
    SpiderDifficulty.medium => l10n.difficultyMedium,
    SpiderDifficulty.hard => l10n.difficultyHard,
  };

  /// `2 suits`: the name of the level that Spider players know.
  String suits(AppLocalizations l10n) => l10n.spiderSuits(suitCount);

  /// What a deal of this level is.
  String hint(AppLocalizations l10n) => switch (this) {
    SpiderDifficulty.easy => l10n.spiderEasyHint,
    SpiderDifficulty.medium => l10n.spiderMediumHint,
    SpiderDifficulty.hard => l10n.spiderHardHint,
  };
}

/// Names of the variants of the records (`suits1`, `suits2`, `suits4`).
final spiderVariantNames = <String, String Function(AppLocalizations)>{
  for (final difficulty in SpiderDifficulty.values)
    difficulty.variant: difficulty.suits,
};
