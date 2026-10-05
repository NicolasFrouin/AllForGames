import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../achievements/achievement_store.dart';
import '../achievements/achievement_texts.dart';
import '../achievements/achievements.dart';
import '../app_stores.dart';
import '../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import 'card_backs.dart';
import 'tile_styles.dart';

/// Every card back and Mahjong tile style: tapping an unlocked one selects
/// it for the games.
class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key, required this.stores});

  final AppStores stores;

  static const _padding = 16.0;
  static const _spacing = 12.0;
  static const _minTileWidth = 160.0;

  void _select(
    BuildContext context, {
    required String? unlockedBy,
    required VoidCallback select,
  }) {
    if (unlockedBy == null || stores.achievements.isUnlocked(unlockedBy)) {
      select();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final title = achievementTitle(unlockedBy, l10n);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.skinUnlockWith(title))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.skins)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            stores.settings,
            stores.achievements,
            stores.stats,
          ]),
          builder: (context, _) {
            final settings = stores.settings;
            final achievementStore = stores.achievements;
            final records = stores.stats.records;
            final cardBackTiles = [
              for (final skin in cardBacks)
                _SkinTile(
                  key: ValueKey('card-back-${skin.id}'),
                  name: cardBackName(skin.id, l10n),
                  preview: _CardBackPreview(skin),
                  selected: skin.id == settings.cardBackId,
                  unlocked: isCardBackUnlocked(skin, achievementStore),
                  unlockedBy: skin.unlockedBy,
                  records: records,
                  onTap: () => _select(
                    context,
                    unlockedBy: skin.unlockedBy,
                    select: () => settings.setCardBack(skin.id),
                  ),
                ),
            ];
            final tileStyleTiles = [
              for (final style in tileStyles)
                _SkinTile(
                  key: ValueKey('tile-style-${style.id}'),
                  name: tileStyleName(style.id, l10n),
                  preview: Center(
                    child: TileStylePreview(
                      style: style,
                      width: _SkinPreview.width,
                    ),
                  ),
                  selected: style.id == settings.tileStyleId,
                  unlocked: isTileStyleUnlocked(style, achievementStore),
                  unlockedBy: style.unlockedBy,
                  records: records,
                  onTap: () => _select(
                    context,
                    unlockedBy: style.unlockedBy,
                    select: () => settings.setTileStyle(style.id),
                  ),
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
                    final rows = [
                      _SectionTitle(l10n.cardBacks),
                      ..._rows(cardBackTiles, columns),
                      _SectionTitle(l10n.mahjongTileStyles),
                      ..._rows(tileStyleTiles, columns),
                    ];
                    return ListView.separated(
                      padding: const EdgeInsets.all(_padding),
                      itemCount: rows.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: _spacing),
                      itemBuilder: (context, index) => rows[index],
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

  /// [tiles] in rows of [columns]. Each row is as tall as its tallest tile,
  /// so no text size can overflow a tile.
  static Iterable<Widget> _rows(List<Widget> tiles, int columns) sync* {
    for (var start = 0; start < tiles.length; start += columns) {
      yield IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _spacing,
          children: [
            for (var i = start; i < start + columns; i++)
              Expanded(child: i < tiles.length ? tiles[i] : const SizedBox()),
          ],
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    super.key,
    required this.name,
    required this.preview,
    required this.selected,
    required this.unlocked,
    required this.unlockedBy,
    required this.records,
    required this.onTap,
  });

  final String name;
  final Widget preview;
  final bool selected;
  final bool unlocked;

  /// Id of the achievement that unlocks the skin, null when it is free.
  final String? unlockedBy;
  final List<GameRecord> records;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final achievement = unlocked ? null : achievementById(unlockedBy!);
    return Semantics(
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
                _SkinPreview(
                  selected: selected,
                  unlocked: unlocked,
                  child: preview,
                ),
                const SizedBox(height: 10),
                Text(
                  name,
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
                    text: l10n.skinSelected,
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

class _CardBackPreview extends StatelessWidget {
  const _CardBackPreview(this.skin);

  final CardBackSkin skin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_SkinPreview.width * 0.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: CardBackView(skin: skin, width: _SkinPreview.width),
    );
  }
}

/// A skin, dimmed under a lock until it is unlocked.
class _SkinPreview extends StatelessWidget {
  const _SkinPreview({
    required this.child,
    required this.selected,
    required this.unlocked,
  });

  final Widget child;
  final bool selected;
  final bool unlocked;

  static const width = 90.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: width * 1.4,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Opacity(opacity: unlocked ? 1 : 0.35, child: child),
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
                  semanticLabel: AppLocalizations.of(context).skinLocked,
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
