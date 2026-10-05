import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
import '../l10n/app_localizations.dart';
import '../skins/skin_rewards.dart';
import 'achievement_texts.dart';
import 'achievements.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.stores});

  final AppStores stores;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievements)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([stores.achievements, stores.stats]),
          builder: (context, _) {
            final store = stores.achievements;
            final records = stores.stats.records;
            int unlockedIn(Iterable<Achievement> list) =>
                list.where((a) => store.isUnlocked(a.id)).length;
            final byGame = {
              for (final gameId in achievementGameIds)
                gameId: [
                  for (final achievement in achievements)
                    if (achievement.gameId == gameId) achievement,
                ],
            };
            // Each game: its header (without achievement), then its
            // achievements.
            final items = <(String, Achievement?)>[
              for (final MapEntry(key: gameId, value: list)
                  in byGame.entries) ...[
                (gameId, null),
                for (final achievement in list) (gameId, achievement),
              ],
            ];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        l10n.achievementsUnlockedCount(
                          unlockedIn(achievements),
                          achievements.length,
                        ),
                        key: const ValueKey('achievements-count'),
                        style: Theme.of(context).textTheme.titleMedium,
                      );
                    }
                    return switch (items[index - 1]) {
                      (_, final Achievement achievement) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _AchievementTile(
                          achievement: achievement,
                          unlockedAt: store.unlockedAt(achievement.id),
                          // Unlocks are permanent: an unlocked achievement
                          // stays full when its records are cleared.
                          progress: store.isUnlocked(achievement.id)
                              ? achievement.goal
                              : achievement.progress(records),
                        ),
                      ),
                      (final gameId, null) => _GroupHeader(
                        gameId: gameId,
                        unlocked: unlockedIn(byGame[gameId]!),
                        total: byGame[gameId]!.length,
                      ),
                    };
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The title of the achievements of a game, and how many are unlocked.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.gameId,
    required this.unlocked,
    required this.total,
  });

  final String gameId;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = gameById(gameId);
    return Padding(
      key: ValueKey('achievement-group-$gameId'),
      padding: const EdgeInsets.only(top: 28, bottom: 2),
      child: Row(
        children: [
          Icon(
            game?.icon ?? Icons.apps,
            color: game?.color ?? Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              game?.title(l10n) ?? l10n.achievementsAllGames,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$unlocked / $total',
            key: ValueKey('achievements-count-$gameId'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: unlocked == total
                  ? Colors.amber
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlockedAt,
    required this.progress,
  });

  final Achievement achievement;
  final DateTime? unlockedAt;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unlockedAt = this.unlockedAt;
    final unlocked = unlockedAt != null;
    final reward = skinRewardOf(achievement.id);
    return Container(
      key: ValueKey('achievement-${achievement.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? Colors.amber.withAlpha(140) : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.amber.withAlpha(40)
                  : const Color(0x14FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              achievement.icon,
              color: unlocked ? Colors.amber : colors.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievementTitle(achievement.id, l10n),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  achievementDescription(achievement.id, l10n),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      // The bar fills up when the page opens.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: progress / achievement.goal,
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          color: unlocked ? Colors.amber : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$progress / ${achievement.goal}',
                      key: const ValueKey('progress'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                if (unlocked) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.achievementUnlockedOn(
                      formatDateTime(unlockedAt, l10n.localeName),
                    ),
                    key: const ValueKey('unlocked-on'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (reward != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      reward.preview(24),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          reward.rewardText(l10n),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
