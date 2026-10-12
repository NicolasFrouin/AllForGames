import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../new_game_actions.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_difficulty_texts.dart';

/// Options of a new Mahjong game. [belt] applies to the classic and tray
/// modes, not to the discs mode.
typedef MahjongNewGame = ({
  MahjongMode mode,
  MahjongDifficulty difficulty,
  MahjongShape shape,
  bool belt,
});

/// Lets the player choose the mode, the difficulty, the shape and the belt of
/// a new game, starting from [initial]. With [inProgress] (a game with moves on screen),
/// the player also chooses whether that game counts as abandoned.
///
/// Returns the choice, or null when the player closes the sheet.
Future<NewGameChoice<MahjongNewGame>?> showMahjongNewGameSheet(
  BuildContext context, {
  required MahjongNewGame initial,
  required bool inProgress,
}) => showModalBottomSheet<NewGameChoice<MahjongNewGame>>(
  context: context,
  // As tall as its content, which scrolls when the text is large.
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _NewGameSheet(initial: initial, inProgress: inProgress),
);

class _NewGameSheet extends StatefulWidget {
  const _NewGameSheet({required this.initial, required this.inProgress});

  final MahjongNewGame initial;
  final bool inProgress;

  @override
  State<_NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<_NewGameSheet> {
  late MahjongMode _mode = widget.initial.mode;

  /// The goal of the tray rules, kept while the classic mode is chosen.
  late MahjongMode _trayGoal = widget.initial.mode == MahjongMode.discs
      ? MahjongMode.discs
      : MahjongMode.tray;
  late MahjongDifficulty _difficulty = widget.initial.difficulty;
  late MahjongShape _shape = widget.initial.shape;
  late bool _belt = widget.initial.belt;

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
          // The discs mode is a goal of the tray rules.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in [MahjongMode.classic, MahjongMode.tray])
                ChoiceChip(
                  key: ValueKey('new-game-mode-${mode.name}'),
                  label: Text(mode.label(l10n)),
                  selected: _mode.usesTray == mode.usesTray,
                  onSelected: (_) =>
                      setState(() => _mode = mode.usesTray ? _trayGoal : mode),
                ),
            ],
          ),
          if (_mode.usesTray) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                l10n.mahjongGoalTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (goal, key, label) in [
                  (MahjongMode.tray, 'tiles', l10n.mahjongGoalTiles),
                  (MahjongMode.discs, 'discs', l10n.mahjongGoalDiscs),
                ])
                  ChoiceChip(
                    key: ValueKey('new-game-goal-$key'),
                    label: Text(label),
                    selected: _mode == goal,
                    onSelected: (_) => setState(() => _mode = _trayGoal = goal),
                  ),
              ],
            ),
          ],
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
          if (_mode != MahjongMode.discs)
            SwitchListTile(
              key: const ValueKey('new-game-belt'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.sync),
              title: Text(l10n.mahjongBelt),
              subtitle: Text(l10n.mahjongBeltHint),
              value: _belt,
              onChanged: (belt) => setState(() => _belt = belt),
            ),
          const SizedBox(height: 4),
          note(Icons.verified_outlined, colors.primary, l10n.newGameWinnable),
          if (_difficulty.hiddenPercent > 0)
            note(
              Icons.visibility_off_outlined,
              colors.primary,
              l10n.mahjongHiddenNote,
              key: const ValueKey('new-game-hidden-note'),
            ),
          NewGameActions(
            inProgress: widget.inProgress,
            options: () => (
              mode: _mode,
              difficulty: _difficulty,
              shape: _shape,
              belt: _belt,
            ),
          ),
        ],
      ),
    );
  }
}
