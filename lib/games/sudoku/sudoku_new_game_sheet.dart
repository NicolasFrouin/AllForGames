import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../new_game_actions.dart';
import 'sudoku_level.dart';
import 'sudoku_level_texts.dart';

/// Lets the player choose the level of a new game, starting from [initial].
/// With [inProgress] (a game with moves on screen), the player also chooses
/// whether that game counts as abandoned.
///
/// Returns the choice, or null when the player closes the sheet.
Future<NewGameChoice<SudokuLevel>?> showSudokuNewGameSheet(
  BuildContext context, {
  required SudokuLevel initial,
  required bool inProgress,
}) => showModalBottomSheet<NewGameChoice<SudokuLevel>>(
  context: context,
  // As tall as its content, which scrolls when the text is large.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _NewGameSheet(initial: initial, inProgress: inProgress),
);

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.initial, required this.inProgress});

  final SudokuLevel initial;
  final bool inProgress;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late SudokuLevel _level = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.newGame, style: theme.textTheme.titleLarge),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(l10n.difficulty, style: theme.textTheme.titleSmall),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in SudokuLevel.values)
                ChoiceChip(
                  key: ValueKey('new-game-difficulty-${level.name}'),
                  label: SizedBox(
                    width: 24,
                    child: Text('${level.number}', textAlign: TextAlign.center),
                  ),
                  tooltip: level.label(l10n),
                  showCheckmark: false,
                  selected: _level == level,
                  onSelected: (_) => setState(() => _level = level),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_level.label(l10n)} · ${_level.group(l10n)}',
            key: const ValueKey('new-game-level'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _level.hint(l10n),
            key: const ValueKey('new-game-hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.sudokuOneSolution)),
              ],
            ),
          ),
          NewGameActions(inProgress: widget.inProgress, options: () => _level),
        ],
      ),
    );
  }
}
