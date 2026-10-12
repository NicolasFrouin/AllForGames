import '../../l10n/app_localizations.dart';
import 'sudoku_level.dart';

/// Texts of the levels. Apart from [SudokuLevel], which the offline tool
/// uses without Flutter.
extension SudokuLevelTexts on SudokuLevel {
  /// "Level 7".
  String label(AppLocalizations l10n) => l10n.sudokuLevel(number);

  /// Easy, Medium, Hard or Expert: three levels each.
  String group(AppLocalizations l10n) => l10n.sudokuLevelGroup('${index ~/ 3}');

  /// What the level asks of the player.
  String hint(AppLocalizations l10n) => l10n.sudokuLevelHint('$number');
}
