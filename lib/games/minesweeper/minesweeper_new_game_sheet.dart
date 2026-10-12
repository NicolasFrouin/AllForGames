import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../new_game_actions.dart';
import 'minesweeper_difficulty.dart';
import 'minesweeper_difficulty_texts.dart';

/// Lets the player choose the level of a new game, starting from [initial].
/// With [inProgress] (a game with moves on screen), the player also chooses
/// whether that game counts as abandoned.
///
/// Returns the choice, or null when the player closes the sheet.
Future<NewGameChoice<MinesweeperDifficulty>?> showMinesweeperNewGameSheet(
  BuildContext context, {
  required MinesweeperDifficulty initial,
  required bool inProgress,
}) => showModalBottomSheet<NewGameChoice<MinesweeperDifficulty>>(
  context: context,
  // As tall as its content, which scrolls when the text is large.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _NewGameSheet(initial: initial, inProgress: inProgress),
);

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.initial, required this.inProgress});

  final MinesweeperDifficulty initial;
  final bool inProgress;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late MinesweeperDifficulty _difficulty = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget note(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

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
              for (final difficulty in MinesweeperDifficulty.values)
                ChoiceChip(
                  key: ValueKey('new-game-difficulty-${difficulty.name}'),
                  label: Text(difficulty.label(l10n)),
                  selected: _difficulty == difficulty,
                  onSelected: (_) => setState(() => _difficulty = difficulty),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _difficulty.hint(l10n),
            key: const ValueKey('new-game-hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          note(
            Icons.verified_outlined,
            colors.primary,
            l10n.minesweeperNoGuess,
          ),
          NewGameActions(
            inProgress: widget.inProgress,
            options: () => _difficulty,
            dealLabel: l10n.minesweeperPlay,
            abandonLabel: l10n.minesweeperAbandonPlay,
          ),
        ],
      ),
    );
  }
}
