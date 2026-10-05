import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../l10n/app_localizations.dart';
import '../skins/card_backs.dart';
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
            final unlockedCount = achievements
                .where((achievement) => store.isUnlocked(achievement.id))
                .length;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      l10n.achievementsUnlockedCount(
                        unlockedCount,
                        achievements.length,
                      ),
                      key: const ValueKey('achievements-count'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final achievement in achievements)
                      Padding(
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
                  ],
                ),
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
    final reward = cardBackUnlockedBy(achievement.id);
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
                      SizedBox(
                        width: 24,
                        height: 24 * 1.4,
                        child: CardBackView(skin: reward, width: 24),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.achievementReward(cardBackName(reward.id, l10n)),
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
