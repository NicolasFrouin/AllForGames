import 'package:material_ui/material_ui.dart';

import '../achievements/achievement_texts.dart';
import '../achievements/achievements.dart';
import '../app_stores.dart';
import '../common/format.dart';
import '../l10n/app_localizations.dart';
import '../skins/skin_rewards.dart';
import '../stats/game_record.dart';
import '../stats/game_stats.dart';

/// One more line of the win dialog, after time, moves and score.
typedef WinDialogRow = ({String label, String value});

/// What the player chose at the end of a won game.
enum WinChoice {
  /// A new deal with the same options.
  playAgain,

  /// The game's new game sheet, to choose other options.
  otherOptions,

  /// Back to the hub.
  leave,
}

/// The dialog at the end of a won game, the same for every game: it pops in,
/// counts up moves and score, compares with [stats] and shows the achievements
/// that the win unlocked.
Future<WinChoice> showWinDialog(
  BuildContext context, {
  required AppStores stores,
  required GameRecord record,
  required GameStats stats,
  List<WinDialogRow> rows = const [],
}) async {
  // The record is already in the stats, but they tell their listeners only
  // after the save: this check unlocks what the win reached right away.
  stores.achievements.check(stores.stats.records);
  final unlocked = stores.achievements.takeAnnouncements();
  final choice = await showGeneralDialog<WinChoice>(
    context: context,
    // Light, so the confetti stays visible behind the dialog.
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
    pageBuilder: (context, _, _) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        icon: const _Trophy(),
        title: Text(l10n.winTitle),
        // New achievements make it taller than a small phone.
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow(l10n.time, formatClock(record.playTime)),
            _ResultRow(l10n.moves, '${record.moves}', count: record.moves),
            _ResultRow(l10n.score, '${record.score}', count: record.score),
            for (final row in rows) _ResultRow(row.label, row.value),
            const Divider(),
            _ResultRow(
              l10n.bestTime,
              formatClock(stats.bestTime ?? record.playTime),
            ),
            _ResultRow(l10n.winStreak, '${stats.currentStreak}'),
            _ResultRow(l10n.gamesWon, '${stats.won} / ${stats.played}'),
            for (final achievement in unlocked) ...[
              const SizedBox(height: 8),
              _UnlockedRow(achievement),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(WinChoice.leave),
            child: Text(l10n.backToGames),
          ),
          TextButton(
            key: const ValueKey('other-options'),
            onPressed: () => Navigator.of(context).pop(WinChoice.otherOptions),
            child: Text(l10n.otherOptions),
          ),
          FilledButton(
            key: const ValueKey('play-again'),
            onPressed: () => Navigator.of(context).pop(WinChoice.playAgain),
            child: Text(l10n.playAgain),
          ),
        ],
      );
    },
  );
  return choice ?? WinChoice.leave;
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.count});

  final String label;
  final String value;

  /// When given, the value counts up from 0 to [count] (then shows [value]).
  final int? count;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (count case final count?)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, shown, _) => Text(
                shown == count ? value : '${shown.round()}',
                style: style,
              ),
            )
          else
            Text(value, style: style),
        ],
      ),
    );
  }
}

/// The trophy of the win dialog: it springs in with a little swing.
class _Trophy extends StatelessWidget {
  const _Trophy();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * 0.6,
        child: Transform.scale(scale: t, child: child),
      ),
      child: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
    );
  }
}

/// An achievement that the win just unlocked, with the skin it gives.
class _UnlockedRow extends StatelessWidget {
  const _UnlockedRow(this.achievement);

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reward = skinRewardOf(achievement.id);
    return Container(
      key: ValueKey('unlocked-${achievement.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(achievement.icon, color: Colors.amber, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.achievementUnlocked,
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  achievementTitle(achievement.id, l10n),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (reward != null)
                  Text(
                    reward.unlockedText(l10n),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (reward != null) ...[
            const SizedBox(width: 12),
            reward.preview(30),
          ],
        ],
      ),
    );
  }
}
