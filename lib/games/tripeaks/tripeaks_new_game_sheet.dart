import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'tripeaks_difficulty.dart';
import 'tripeaks_difficulty_texts.dart';

/// Lets the player choose the difficulty of a new game, starting from
/// [initial]. With [abandons], it says that the game on screen will count as
/// abandoned, so Deal also confirms that.
///
/// Returns the chosen difficulty, or null when the player closes the sheet.
Future<TriPeaksDifficulty?> showTriPeaksNewGameSheet(
  BuildContext context, {
  required TriPeaksDifficulty initial,
  required bool abandons,
}) => showModalBottomSheet<TriPeaksDifficulty>(
  context: context,
  // As tall as its content, which scrolls when the text is large.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _NewGameSheet(initial: initial, abandons: abandons),
);

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.initial, required this.abandons});

  final TriPeaksDifficulty initial;
  final bool abandons;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late TriPeaksDifficulty _difficulty = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget note(IconData icon, Color color, String text, {Key? key}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, key: key)),
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
              for (final difficulty in TriPeaksDifficulty.values)
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
          note(Icons.verified_outlined, colors.primary, l10n.newGameWinnable),
          if (widget.abandons)
            note(
              Icons.flag_outlined,
              colors.error,
              l10n.newGameAbandons,
              key: const ValueKey('new-game-abandons'),
            ),
          const SizedBox(height: 20),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('new-game-deal'),
                onPressed: () => Navigator.of(context).pop(_difficulty),
                child: Text(l10n.newGameDeal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
