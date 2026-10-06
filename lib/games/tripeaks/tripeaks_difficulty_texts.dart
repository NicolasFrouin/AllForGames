import '../../l10n/app_localizations.dart';
import 'tripeaks_difficulty.dart';

/// Texts of the difficulty levels. Apart from [TriPeaksDifficulty], which the
/// offline tool uses without Flutter.
extension TriPeaksDifficultyTexts on TriPeaksDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    TriPeaksDifficulty.easy => l10n.difficultyEasy,
    TriPeaksDifficulty.medium => l10n.difficultyMedium,
    TriPeaksDifficulty.hard => l10n.difficultyHard,
  };

  /// What a deal of this level asks of the player.
  String hint(AppLocalizations l10n) => switch (this) {
    TriPeaksDifficulty.easy => l10n.tripeaksEasyHint,
    TriPeaksDifficulty.medium => l10n.tripeaksMediumHint,
    TriPeaksDifficulty.hard => l10n.tripeaksHardHint,
  };
}
