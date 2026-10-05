import '../../l10n/app_localizations.dart';
import 'klondike_difficulty.dart';

/// Texts of the difficulty levels. Apart from [KlondikeDifficulty], which the
/// offline tool uses without Flutter.
extension KlondikeDifficultyTexts on KlondikeDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    KlondikeDifficulty.easy => l10n.difficultyEasy,
    KlondikeDifficulty.medium => l10n.difficultyMedium,
    KlondikeDifficulty.hard => l10n.difficultyHard,
  };

  /// What a deal of this level asks of the player.
  String hint(AppLocalizations l10n) => switch (this) {
    KlondikeDifficulty.easy => l10n.klondikeEasyHint,
    KlondikeDifficulty.medium => l10n.klondikeMediumHint,
    KlondikeDifficulty.hard => l10n.klondikeHardHint,
  };
}
