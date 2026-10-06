import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../achievements/achievement_store.dart';
import '../achievements/achievement_texts.dart';
import '../achievements/achievements.dart';
import '../achievements/achievements_screen.dart';
import '../app_stores.dart';
import '../games/freecell/freecell_controller.dart';
import '../games/game_catalog.dart';
import '../games/klondike/klondike_controller.dart';
import '../games/mahjong/mahjong_controller.dart';
import '../games/spider/spider_controller.dart';
import '../l10n/app_localizations.dart';
import '../stats/game_record.dart';
import 'card_backs.dart';
import 'skin_rewards.dart';
import 'tile_styles.dart';

/// A skin as the page shows it.
class _Skin {
  const _Skin({
    required this.key,
    required this.name,
    required this.preview,
    required this.selected,
    required this.unlocked,
    required this.unlockedBy,
    required this.select,
  });

  /// Key of its tile.
  final String key;
  final String name;
  final Widget preview;
  final bool selected;
  final bool unlocked;

  /// Id of the achievement that unlocks it, null when it is free.
  final String? unlockedBy;
  final VoidCallback select;
}

/// The tab of a kind of skin.
class _KindTab {
  const _KindTab({
    required this.label,
    required this.icon,
    required this.title,
    required this.gameIds,
    required this.skins,
  });

  final LocalizedText label;
  final IconData icon;
  final LocalizedText title;

  /// The games that draw these skins.
  final List<String> gameIds;
  final List<_Skin> Function(AppStores stores, AppLocalizations l10n) skins;
}

_KindTab _tabOf(SkinKind kind) => switch (kind) {
  SkinKind.cardBack => _KindTab(
    label: (l10n) => l10n.skinsCards,
    icon: Icons.style,
    title: (l10n) => l10n.cardBacks,
    gameIds: const [
      KlondikeController.gameId,
      FreeCellController.gameId,
      SpiderController.gameId,
    ],
    skins: (stores, l10n) => [
      for (final skin in cardBacks)
        _Skin(
          key: 'card-back-${skin.id}',
          name: cardBackName(skin.id, l10n),
          preview: _CardBackPreview(skin),
          selected: skin.id == stores.settings.cardBackId,
          unlocked: isCardBackUnlocked(skin, stores.achievements),
          unlockedBy: skin.unlockedBy,
          select: () => stores.settings.setCardBack(skin.id),
        ),
    ],
  ),
  SkinKind.tileStyle => _KindTab(
    label: (l10n) => l10n.mahjongTitle,
    icon: Icons.grid_view,
    title: (l10n) => l10n.mahjongTileStyles,
    gameIds: const [MahjongController.gameId],
    skins: (stores, l10n) => [
      for (final style in tileStyles)
        _Skin(
          key: 'tile-style-${style.id}',
          name: tileStyleName(style.id, l10n),
          preview: Center(
            child: TileStylePreview(style: style, width: _SkinPreview.width),
          ),
          selected: style.id == stores.settings.tileStyleId,
          unlocked: isTileStyleUnlocked(style, stores.achievements),
          unlockedBy: style.unlockedBy,
          select: () => stores.settings.setTileStyle(style.id),
        ),
    ],
  ),

};

/// [skins] by where they come from: the free ones first (key null), then
/// by game of the achievement that unlocks them, in the order of the
/// achievements page.
Map<String?, List<_Skin>> _bySource(List<_Skin> skins) {
  final groups = <String?, List<_Skin>>{
    null: [],
    for (final gameId in achievementGameIds) gameId: [],
  };
  for (final skin in skins) {
    final unlockedBy = skin.unlockedBy;
    final source = unlockedBy == null
        ? null
        : achievementById(unlockedBy)?.gameId ?? allGamesId;
    (groups[source] ??= []).add(skin);
  }
  return groups..removeWhere((_, list) => list.isEmpty);
}

/// Every card back and Mahjong tile style, one tab per
/// [SkinKind]: tapping an unlocked one selects it for the games.
class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key, required this.stores, this.kind});

  final AppStores stores;

  /// The kind of the tab that opens first: the first tab when null.
  final SkinKind? kind;

  static const _padding = 16.0;
  static const _spacing = 12.0;
  static const _minTileWidth = 160.0;

  void _select(BuildContext context, _Skin skin) {
    final unlockedBy = skin.unlockedBy;
    if (skin.unlocked || unlockedBy == null) {
      skin.select();
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
    return DefaultTabController(
      // A new ?kind= on the open page selects its tab.
      key: ValueKey(kind),
      length: SkinKind.values.length,
      initialIndex: kind?.index ?? 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.skins),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              for (final kind in SkinKind.values)
                Tab(
                  key: ValueKey('skins-tab-${kind.name}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabOf(kind).icon, size: 18),
                      const SizedBox(width: 8),
                      Text(_tabOf(kind).label(l10n)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              stores.settings,
              stores.achievements,
              stores.stats,
            ]),
            builder: (context, _) => TabBarView(
              children: [
                for (final kind in SkinKind.values)
                  _kindPage(context, kind, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kindPage(BuildContext context, SkinKind kind, AppLocalizations l10n) {
    final tab = _tabOf(kind);
    final records = stores.stats.records;
    final groups = _bySource(tab.skins(stores, l10n));
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
              _KindTitle(
                title: tab.title(l10n),
                // A tab named after its only game needs no list.
                gameIds: tab.gameIds.length > 1 ? tab.gameIds : const [],
              ),
              for (final MapEntry(key: source, value: skins)
                  in groups.entries) ...[
                if (groups.length > 1) _SourceHeader(source),
                ..._rows([
                  for (final skin in skins)
                    _SkinTile(
                      key: ValueKey(skin.key),
                      name: skin.name,
                      preview: skin.preview,
                      selected: skin.selected,
                      unlocked: skin.unlocked,
                      unlockedBy: skin.unlockedBy,
                      records: records,
                      onTap: () => _select(context, skin),
                    ),
                ], columns),
              ],
            ];
            return ListView.separated(
              // Each tab keeps its scroll position.
              key: PageStorageKey(kind),
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

/// The title of a tab, over the games that use its skins.
class _KindTitle extends StatelessWidget {
  const _KindTitle({required this.title, required this.gameIds});

  final String title;
  final List<String> gameIds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (gameIds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final gameId in gameIds)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AchievementGroupIcon(gameId),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        achievementGroupName(gameId, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The header of the free skins ([gameId] null), or of the skins that the
/// achievements of [gameId] unlock.
class _SourceHeader extends StatelessWidget {
  const _SourceHeader(this.gameId);

  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gameId = this.gameId;
    return Padding(
      key: ValueKey('skins-group-${gameId ?? 'free'}'),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (gameId == null)
            Icon(Icons.redeem, size: 20, color: theme.colorScheme.primary)
          else
            AchievementGroupIcon(gameId, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              gameId == null
                  ? l10n.skinsFree
                  : achievementGroupName(gameId, l10n),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
