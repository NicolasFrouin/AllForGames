import '../../l10n/app_localizations.dart';
import 'minesweeper_difficulty.dart';

/// Texts of the levels. Apart from [MinesweeperDifficulty], which the
/// offline tool uses without Flutter.
extension MinesweeperDifficultyTexts on MinesweeperDifficulty {
  String label(AppLocalizations l10n) => switch (this) {
    MinesweeperDifficulty.easy => l10n.minesweeperBeginner,
    MinesweeperDifficulty.medium => l10n.minesweeperIntermediate,
    MinesweeperDifficulty.hard => l10n.minesweeperExpert,
  };

  /// The size of the board and its mines.
  String hint(AppLocalizations l10n) =>
      l10n.minesweeperLevelHint(columns, rows, mines);
}
