import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// What the player chose in a new game sheet: the [options] of the new game,
/// and whether the game on screen counts as abandoned ([abandon]). Without
/// it, that game leaves no record.
typedef NewGameChoice<T> = ({T options, bool abandon});

/// The end of every new game sheet: Cancel and Deal. With a game in progress
/// ([inProgress]), a note says that it will not count, and Abandon and deal
/// also records it as abandoned. The sheet returns a [NewGameChoice] with
/// [options].
class NewGameActions<T> extends StatelessWidget {
  const NewGameActions({
    super.key,
    required this.inProgress,
    required this.options,
    this.dealLabel,
    this.abandonLabel,
  });

  final bool inProgress;

  /// Instead of Deal and Abandon and deal.
  final String? dealLabel;
  final String? abandonLabel;

  /// The options chosen in the sheet, read when a button is pressed.
  final T Function() options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    void deal({required bool abandon}) =>
        Navigator.of(context)
            .pop<NewGameChoice<T>>((options: options(), abandon: abandon));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inProgress)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.newGameNotCounted,
                    key: const ValueKey('new-game-abandons'),
                  ),
                ),
              ],
            ),
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
            if (inProgress)
              TextButton.icon(
                key: const ValueKey('new-game-abandon'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
                onPressed: () => deal(abandon: true),
                icon: const Icon(Icons.flag_outlined),
                label: Text(abandonLabel ?? l10n.newGameAbandon),
              ),
            FilledButton(
              key: const ValueKey('new-game-deal'),
              onPressed: () => deal(abandon: false),
              child: Text(dealLabel ?? l10n.newGameDeal),
            ),
          ],
        ),
      ],
    );
  }
}
