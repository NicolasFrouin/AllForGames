import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
import '../l10n/app_localizations.dart';
import '../skins/skin_rewards.dart';
import '../stats/game_record.dart';
import 'achievement_store.dart';
import 'achievement_texts.dart';
import 'achievements.dart';

/// The achievements, one tab per game of [achievementGameIds].
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.stores, this.gameId});

  final AppStores stores;

  /// The game of the tab that opens first: the first tab when null or
  /// unknown.
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gameId = this.gameId;
    return ListenableBuilder(
      listenable: Listenable.merge([stores.achievements, stores.stats]),
      builder: (context, _) {
        final store = stores.achievements;
        int unlockedIn(Iterable<Achievement> list) =>
            list.where((a) => store.isUnlocked(a.id)).length;
        final byGame = {
          for (final gameId in achievementGameIds)
            gameId: [
              for (final achievement in achievements)
                if (achievement.gameId == gameId) achievement,
            ],
        };
        final unlocked = unlockedIn(achievements);
        return DefaultTabController(
          // A new ?game= on the open page selects its tab.
          key: ValueKey(gameId),
          length: byGame.length,
          initialIndex: gameId == null
              ? 0
              : max(0, achievementGameIds.indexOf(gameId)),
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.achievements),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Tooltip(
                    message: l10n.achievementsUnlockedCount(
                      unlocked,
                      achievements.length,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$unlocked / ${achievements.length}',
                          key: const ValueKey('achievements-count'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  for (final MapEntry(key: gameId, value: list)
                      in byGame.entries)
                    _GameTab(
                      gameId: gameId,
                      unlocked: unlockedIn(list),
                      total: list.length,
                    ),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  for (final MapEntry(key: gameId, value: list)
                      in byGame.entries)
                    _GamePage(
                      gameId: gameId,
                      achievements: list,
                      store: store,
                      records: stores.stats.records,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The name of the achievements of [gameId]: its game's, or "All games".
String achievementGroupName(String gameId, AppLocalizations l10n) =>
    gameId == allGamesId
    ? l10n.achievementsAllGames
    : gameById(gameId)?.title(l10n) ?? gameId;

/// The icon of the achievements of [gameId], in the color of its game.
class AchievementGroupIcon extends StatelessWidget {
  const AchievementGroupIcon(this.gameId, {super.key, this.size = 18});

  final String gameId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final game = gameById(gameId);
    return Icon(
      game?.icon ?? Icons.apps,
      color: game?.color ?? Colors.amber,
      size: size,
    );
  }
}

/// The tab of a game: its name and how many of its achievements are
/// unlocked.
class _GameTab extends StatelessWidget {
  const _GameTab({
    required this.gameId,
    required this.unlocked,
    required this.total,
  });

  final String gameId;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tab(
      key: ValueKey('achievement-tab-$gameId'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AchievementGroupIcon(gameId),
          const SizedBox(width: 8),
          Text(achievementGroupName(gameId, AppLocalizations.of(context))),
          const SizedBox(width: 6),
          Text(
            '$unlocked/$total',
            style: theme.textTheme.labelMedium?.copyWith(
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

/// The achievements of a game, under how many are unlocked.
class _GamePage extends StatelessWidget {
  const _GamePage({
    required this.gameId,
    required this.achievements,
    required this.store,
    required this.records,
  });

  final String gameId;
  final List<Achievement> achievements;
  final AchievementStore store;
  final List<GameRecord> records;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unlocked = achievements.where((a) => store.isUnlocked(a.id)).length;
    final total = achievements.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
          // Each tab keeps its scroll position.
          key: PageStorageKey(gameId),
          padding: const EdgeInsets.all(20),
          itemCount: achievements.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.achievementsUnlockedCount(unlocked, total),
                    key: ValueKey('achievements-count-$gameId'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : unlocked / total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: unlocked == total ? Colors.amber : null,
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }
            final achievement = achievements[index - 1];
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _AchievementTile(
                achievement: achievement,
                unlockedAt: store.unlockedAt(achievement.id),
                // Unlocks are permanent: an unlocked achievement stays full
                // when its records are cleared.
                progress: store.isUnlocked(achievement.id)
                    ? achievement.goal
                    : achievement.progress(records),
              ),
            );
          },
        ),
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
