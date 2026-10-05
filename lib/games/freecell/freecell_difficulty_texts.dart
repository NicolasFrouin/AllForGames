import '../../l10n/app_localizations.dart';
import 'freecell_difficulty.dart';

/// Texts of the difficulty levels. Apart from [FreeCellDifficulty], which the
/// offline tool uses without Flutter.
extension FreeCellDifficultyTexts on FreeCellDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    FreeCellDifficulty.easy => l10n.difficultyEasy,
    FreeCellDifficulty.medium => l10n.difficultyMedium,
    FreeCellDifficulty.hard => l10n.difficultyHard,
  };

  /// What a deal of this level asks of the player.
  String hint(AppLocalizations l10n) => switch (this) {
    FreeCellDifficulty.easy => l10n.freecellEasyHint,
    FreeCellDifficulty.medium => l10n.freecellMediumHint,
    FreeCellDifficulty.hard => l10n.freecellHardHint,
  };
}
