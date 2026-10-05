import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
import '../games/klondike/playing_card.dart';
import '../games/klondike/suit_icon.dart';
import '../l10n/app_localizations.dart';
import '../saves/game_save_store.dart';
import '../settings/settings_store.dart';
import '../stats/game_stats.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.stores});

  final AppStores stores;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E3B2C), Color(0xFF0A1F1A), Color(0xFF07110F)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([stores.stats, stores.saves]),
            builder: (context, _) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: _Header(
                          overall: stores.stats.overall,
                          settings: stores.settings,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          l10n.hubGames,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      sliver: _GameGrid(
                        tiles: [
                          for (final game in gameCatalog)
                            GameTile(
                              game: game,
                              stats: stores.stats.statsFor(game.id),
                              saved: stores.saves[game.id],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A grid where each row is as tall as its tallest tile, so no text size
/// can overflow a tile.
class _GameGrid extends StatelessWidget {
  const _GameGrid({required this.tiles});

  final List<Widget> tiles;

  static const _maxTileWidth = 360.0;
  static const _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = max(
          1,
          (constraints.crossAxisExtent / (_maxTileWidth + _spacing)).ceil(),
        );
        return SliverList.separated(
          itemCount: (tiles.length / columns).ceil(),
          separatorBuilder: (context, _) => const SizedBox(height: _spacing),
          itemBuilder: (context, row) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _spacing,
              children: [
                for (var i = row * columns; i < (row + 1) * columns; i++)
                  Expanded(
                    child: i < tiles.length ? tiles[i] : const SizedBox(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.overall, required this.settings});

  final GameStats overall;
  final SettingsStore settings;

  /// Below this width, the title goes under the logo and the buttons, so
  /// large text never squeezes it.
  static const _narrowWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appTitle,
          style: textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          l10n.hubTagline,
          style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
      ],
    );
    final actions = _HeaderActions(settings: settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _narrowWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const _Logo(), const Spacer(), actions],
                  ),
                  const SizedBox(height: 12),
                  title,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const _Logo(),
                      const SizedBox(width: 16),
                      Expanded(child: title),
                    ],
                  ),
                ),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OverallChip(
              key: const ValueKey('overall-played'),
              icon: Icons.casino_outlined,
              label: l10n.hubGamesPlayed,
              value: '${overall.played}',
            ),
            _OverallChip(
              key: const ValueKey('overall-won'),
              icon: Icons.emoji_events_outlined,
              label: l10n.hubWins,
              value: '${overall.won}',
            ),
            _OverallChip(
              key: const ValueKey('overall-time'),
              icon: Icons.timer_outlined,
              label: l10n.timePlayed,
              value: formatLongDuration(overall.totalPlayTime, l10n),
            ),
          ],
        ),
      ],
    );
  }
}

/// Achievements, card backs and language, at the top right.
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('achievements-button'),
          tooltip: l10n.achievements,
          color: Colors.white70,
          onPressed: () => context.go('/achievements'),
          icon: const Icon(Icons.emoji_events_outlined),
        ),
        IconButton(
          key: const ValueKey('card-backs-button'),
          tooltip: l10n.cardBacks,
          color: Colors.white70,
          onPressed: () => context.go('/card-backs'),
          icon: const Icon(Icons.palette_outlined),
        ),
        _LanguageMenu(settings: settings),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.settings});

  final SettingsStore settings;

  static const _system = 'system';

  /// Each language name is in its own language.
  static const _names = {'en': 'English', 'fr': 'Français'};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: const ValueKey('language-menu'),
      tooltip: l10n.language,
      icon: const Icon(Icons.translate, color: Colors.white70),
      onSelected: (code) =>
          settings.setLocale(code == _system ? null : Locale(code)),
      itemBuilder: (context) {
        final current = settings.locale?.languageCode ?? _system;
        PopupMenuEntry<String> item(String code, String name) =>
            CheckedPopupMenuItem(
              key: ValueKey('language-$code'),
              value: code,
              checked: code == current,
              child: Text(name),
            );
        return [
          item(_system, l10n.languageSystem),
          for (final Locale(:languageCode) in AppLocalizations.supportedLocales)
            item(languageCode, _names[languageCode] ?? languageCode),
        ];
      },
    );
  }
}

/// Three fanned cards.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    Widget card(Suit suit, double angle) => Transform.rotate(
      angle: angle,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 34,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        alignment: Alignment.center,
        child: SuitIcon(suit, size: 20),
      ),
    );
    return SizedBox(
      width: 64,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          card(Suit.clubs, -0.35),
          card(Suit.diamonds, 0),
          card(Suit.hearts, 0.35),
        ],
      ),
    );
  }
}

class _OverallChip extends StatelessWidget {
  const _OverallChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          // The label goes under the value when both do not fit on one line
          // (large text, long French durations).
          Flexible(
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  value,
                  key: const ValueKey('value'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(label, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameTile extends StatelessWidget {
  const GameTile({
    super.key,
    required this.game,
    required this.stats,
    this.saved,
  });

  final GameInfo game;
  final GameStats stats;

  /// The game in progress. Tapping the tile continues it.
  final SavedGame? saved;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final title = game.title(l10n);
    final route = game.route;
    return Opacity(
      opacity: game.isAvailable ? 1 : 0.55,
      child: Card(
        key: ValueKey('game-${game.id}'),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: route == null ? null : () => context.go(route),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  game.color,
                  Color.lerp(game.color, Colors.black, 0.55)!,
                ],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(game.icon, color: Colors.white, size: 30),
                      ),
                      if (game.isAvailable)
                        IconButton(
                          key: ValueKey('stats-${game.id}'),
                          tooltip: l10n.gameStatistics(title),
                          color: Colors.white,
                          onPressed: () => context.go('/stats/${game.id}'),
                          icon: const Icon(Icons.bar_chart),
                        )
                      else
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.hubComingSoon,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.tagline(l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  if (game.isAvailable) ...[
                    const SizedBox(height: 12),
                    if (saved case SavedGame(:final moves, :final playTime)
                        when moves > 0) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.hubContinue(moves, formatClock(playTime)),
                              key: ValueKey('resume-${game.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      _summary(stats, l10n),
                      key: ValueKey('summary-${game.id}'),
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _summary(GameStats stats, AppLocalizations l10n) {
    if (stats.played == 0) return l10n.hubNotPlayed;
    return [
      l10n.hubSummaryPlayed(stats.played),
      l10n.hubSummaryWon(formatPercent(stats.winRate, l10n.localeName)),
      if (stats.bestTime case final best?)
        l10n.hubSummaryBest(formatClock(best)),
    ].join(' · ');
  }
}
