import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../achievements/achievement_store.dart';
import '../achievements/achievement_texts.dart';
import '../achievements/achievements.dart';
import '../app_stores.dart';
import '../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import 'card_backs.dart';

/// Every card back: tapping an unlocked one selects it for the games.
class CardBacksScreen extends StatelessWidget {
  const CardBacksScreen({super.key, required this.stores});

  final AppStores stores;

  static const _padding = 16.0;
  static const _spacing = 12.0;
  static const _minTileWidth = 160.0;

  void _select(BuildContext context, CardBackSkin skin) {
    if (isCardBackUnlocked(skin, stores.achievements)) {
      stores.settings.setCardBack(skin.id);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final title = achievementTitle(skin.unlockedBy!, l10n);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.cardBackUnlockWith(title))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cardBacks)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            stores.settings,
            stores.achievements,
            stores.stats,
          ]),
          builder: (context, _) {
            final tiles = [
              for (final skin in cardBacks)
                _CardBackTile(
                  skin: skin,
                  selected: skin.id == stores.settings.cardBackId,
                  store: stores.achievements,
                  records: stores.stats.records,
                  onTap: () => _select(context, skin),
                ),
            ];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = max(
                      2,
                      ((constraints.maxWidth - _padding * 2 + _spacing) /
                              (_minTileWidth + _spacing))
                          .floor(),
                    );
                    // Each row is as tall as its tallest tile, so no text
                    // size can overflow a tile.
                    return ListView.separated(
                      padding: const EdgeInsets.all(_padding),
                      itemCount: (tiles.length / columns).ceil(),
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: _spacing),
                      itemBuilder: (context, row) => IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: _spacing,
                          children: [
                            for (
                              var i = row * columns;
                              i < (row + 1) * columns;
                              i++
                            )
                              Expanded(
                                child: i < tiles.length
                                    ? tiles[i]
                                    : const SizedBox(),
                              ),
                          ],
                        ),
                      ),
                    );
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

class _CardBackTile extends StatelessWidget {
  const _CardBackTile({
    required this.skin,
    required this.selected,
    required this.store,
    required this.records,
    required this.onTap,
  });

  final CardBackSkin skin;
  final bool selected;
  final AchievementStore store;
  final List<GameRecord> records;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unlocked = isCardBackUnlocked(skin, store);
    final achievement = unlocked ? null : achievementById(skin.unlockedBy!);
    return Semantics(
      key: ValueKey('card-back-${skin.id}'),
      selected: selected,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _Preview(skin: skin, selected: selected, unlocked: unlocked),
                const SizedBox(height: 10),
                Text(
                  cardBackName(skin.id, l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (selected)
                  _Line(
                    icon: Icons.check_circle,
                    color: colors.primary,
                    text: l10n.cardBackSelected,
                  )
                else if (achievement != null) ...[
                  _Line(
                    icon: achievement.icon,
                    color: colors.onSurfaceVariant,
                    text: achievementTitle(achievement.id, l10n),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${achievement.progress(records)} / ${achievement.goal}',
                    key: const ValueKey('progress'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card back, dimmed under a lock until it is unlocked.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.skin,
    required this.selected,
    required this.unlocked,
  });

  final CardBackSkin skin;
  final bool selected;
  final bool unlocked;

  static const _width = 90.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: _width,
      height: _width * 1.4,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_width * 0.1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Opacity(
              opacity: unlocked ? 1 : 0.35,
              child: CardBackView(skin: skin, width: _width),
            ),
          ),
          if (!unlocked)
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 26,
                  semanticLabel: AppLocalizations.of(context).cardBackLocked,
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primaryContainer, width: 2),
                ),
                child: Icon(Icons.check, color: colors.onPrimary, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

/// An icon and a text that wraps under large text sizes.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
