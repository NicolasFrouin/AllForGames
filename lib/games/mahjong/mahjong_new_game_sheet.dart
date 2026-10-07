import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_difficulty_texts.dart';

/// Options of a new Mahjong game.
typedef MahjongNewGame = ({
  MahjongMode mode,
  MahjongDifficulty difficulty,
  MahjongShape shape,
});

/// Lets the player choose the mode, the difficulty and the shape of a new game,
/// starting from [initial]. With [abandons], it says that the game on screen
/// will count as abandoned, so Deal also confirms that.
///
/// Returns the chosen options, or null when the player closes the sheet.
Future<MahjongNewGame?> showMahjongNewGameSheet(
  BuildContext context, {
  required MahjongNewGame initial,
  required bool abandons,
}) => showModalBottomSheet<MahjongNewGame>(
  context: context,
  // As tall as its content, which scrolls when the text is large.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _NewGameSheet(initial: initial, abandons: abandons),
);

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.initial, required this.abandons});

  final MahjongNewGame initial;
  final bool abandons;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late MahjongMode _mode = widget.initial.mode;
  late MahjongDifficulty _difficulty = widget.initial.difficulty;
  late MahjongShape _shape = widget.initial.shape;

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
            child: Text(
              l10n.mahjongModeTitle,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in MahjongMode.values)
                ChoiceChip(
                  key: ValueKey('new-game-mode-${mode.name}'),
                  label: Text(mode.label(l10n)),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _mode.hint(l10n),
            key: const ValueKey('new-game-mode-hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(l10n.difficulty, style: theme.textTheme.titleSmall),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final difficulty in MahjongDifficulty.values)
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
            _difficulty.hint(l10n, _mode),
            key: const ValueKey('new-game-hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              l10n.mahjongShapeTitle,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final shape in MahjongShape.values)
                ChoiceChip(
                  key: ValueKey('new-game-shape-${shape.name}'),
                  label: Text(shape.label(l10n, _difficulty)),
                  selected: _shape == shape,
                  onSelected: (_) => setState(() => _shape = shape),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _shape.hint(l10n, _difficulty),
            key: const ValueKey('new-game-shape-hint'),
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
                onPressed: () => Navigator.of(context)
                    .pop((mode: _mode, difficulty: _difficulty, shape: _shape)),
                child: Text(l10n.newGameDeal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
