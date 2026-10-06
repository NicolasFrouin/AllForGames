import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../achievements/achievements.dart';
import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
import '../l10n/app_localizations.dart';
import 'game_record.dart';
import 'game_stats.dart';
import 'overview_stats.dart';

const _gap = 16.0;
const _wonColor = Colors.amber;

/// The statistics of every game together.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.stores});

  final AppStores stores;

  /// From this width, the cards under the totals stand in two columns.
  static const _wideWidth = 760.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([stores.stats, stores.achievements]),
          builder: (context, _) {
            final stats = OverviewStats.from(stores.stats.records);
            final achievementsCard = _AchievementsCard(
              unlocked: achievements
                  .where((a) => stores.achievements.isUnlocked(a.id))
                  .length,
              total: achievements.length,
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _wideWidth;
                    final cards = stats.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Text(
                                l10n.statsEmpty,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            achievementsCard,
                          ]
                        : wide
                        ? [
                            _TotalsCard(stats),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: _gap,
                              children: [
                                _column([
                                  _GamesCard(stats),
                                  _ActivityCard(stats),
                                  _WhenYouPlayCard(stats),
                                ]),
                                _column([
                                  achievementsCard,
                                  _RecordsCard(stats),
                                  _RecentCard(stats),
                                ]),
                              ],
                            ),
                          ]
                        : [
                            _TotalsCard(stats),
                            achievementsCard,
                            _GamesCard(stats),
                            _ActivityCard(stats),
                            _WhenYouPlayCard(stats),
                            _RecordsCard(stats),
                            _RecentCard(stats),
                          ];
                    return ListView.separated(
                      padding: EdgeInsets.all(wide ? 24 : 12),
                      itemCount: cards.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: _gap),
                      itemBuilder: (context, index) => cards[index],
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

  static Widget _column(List<Widget> cards) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _gap,
      children: cards,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard(this.stats);

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;
    final overall = stats.overall;
    String count(int value) => formatCount(value, locale);
    // In pairs, so that the two columns of a phone read well too.
    return _Card(
      title: l10n.statsOverview,
      children: [
        _TileGrid([
          _Tile('played', l10n.statPlayed, count(overall.played)),
          _Tile('won', l10n.statWon, count(overall.won)),
          _Tile(
            'winRate',
            l10n.statWinRate,
            formatPercent(overall.winRate, locale),
          ),
          _Tile('totalMoves', l10n.statTotalMoves, count(overall.totalMoves)),
          _Tile(
            'winStreak',
            l10n.overviewWinStreak,
            count(overall.currentStreak),
          ),
          _Tile(
            'bestWinStreak',
            l10n.overviewBestWinStreak,
            count(overall.bestStreak),
          ),
          _Tile(
            'timePlayed',
            l10n.timePlayed,
            formatLongDuration(overall.totalPlayTime, l10n),
          ),
          _Tile(
            'averageGameTime',
            l10n.overviewAverageGameTime,
            formatClock(stats.averageGameTime ?? Duration.zero),
          ),
          _Tile('daysPlayed', l10n.overviewDaysPlayed, count(stats.daysPlayed)),
          _Tile('totalUndos', l10n.statTotalUndos, count(overall.totalUndos)),
          _Tile(
            'dayStreak',
            l10n.overviewDayStreak,
            count(stats.currentDayStreak),
          ),
          _Tile(
            'bestDayStreak',
            l10n.overviewBestDayStreak,
            count(stats.bestDayStreak),
          ),
        ]),
      ],
    );
  }
}

/// Tiles in as many equal columns as fit, at least two on a phone.
class _TileGrid extends StatelessWidget {
  const _TileGrid(this.tiles);

  final List<Widget> tiles;

  static const _minWidth = 140.0;
  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = max(
          2,
          ((constraints.maxWidth + _spacing) / (_minWidth + _spacing)).floor(),
        );
        // Rounded down: a sum a hair too wide would wrap a row.
        final width =
            ((constraints.maxWidth - _spacing * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.id, this.label, this.value);

  /// Names the tile for tests, in any language.
  final String id;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('overview-stat-$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            key: const ValueKey('value'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _Card(
      title: l10n.achievements,
      children: [
        Row(
          key: const ValueKey('overview-stat-achievements'),
          children: [
            const Icon(Icons.emoji_events, color: _wonColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.achievementsUnlockedCount(unlocked, total),
                key: const ValueKey('value'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: total == 0 ? 0 : unlocked / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: _wonColor,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            key: const ValueKey('overview-achievements'),
            onPressed: () => context.push('/achievements'),
            icon: const Icon(Icons.chevron_right),
            iconAlignment: IconAlignment.end,
            label: Text(l10n.overviewSeeAchievements),
          ),
        ),
      ],
    );
  }
}

/// The games of the catalog, then the games of records that the catalog
/// does not have (from another app version), by id.
class _GamesCard extends StatelessWidget {
  const _GamesCard(this.stats);

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      title: l10n.hubGames,
      children: [
        for (final game in gameCatalog)
          if (game.isAvailable || stats.perGame.containsKey(game.id))
            _GameRow(game.id, stats.perGame[game.id]),
        for (final MapEntry(key: gameId, value: gameStats)
            in stats.perGame.entries)
          if (gameById(gameId) == null) _GameRow(gameId, gameStats),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow(this.gameId, this.stats);

  final String gameId;

  /// Null when the game has no finished game.
  final GameStats? stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final game = gameById(gameId);
    final lines = switch (stats) {
      null => [l10n.overviewNotPlayed],
      final stats => [
        l10n.overviewGameSummary(
          stats.played,
          stats.won,
          formatPercent(stats.winRate, locale),
        ),
        [
          if (stats.bestTime case final best?)
            l10n.overviewBest(formatClock(best)),
          l10n.overviewTimePlayed(
            formatLongDuration(stats.totalPlayTime, l10n),
          ),
        ].join(' · '),
        l10n.overviewLastPlayed(formatDate(stats.lastPlayedAt!, locale)),
      ],
    };
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      key: ValueKey('overview-game-$gameId'),
      borderRadius: BorderRadius.circular(14),
      // A game missing from the catalog has no statistics page.
      onTap: game == null ? null : () => context.push('/stats/$gameId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _GameIcon(game),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game?.title(l10n) ?? gameId,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final line in lines) Text(line, style: muted),
                ],
              ),
            ),
            if (game != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// The icon of [game] on its color, or a neutral one for a game missing from
/// the catalog.
class _GameIcon extends StatelessWidget {
  const _GameIcon(this.game, {this.size = 40});

  final GameInfo? game;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: game?.color ?? Colors.blueGrey,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        game?.icon ?? Icons.videogame_asset,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.stats);

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final days = stats.lastDays;
    final notWonColor = theme.colorScheme.outline;
    final summary = l10n.overviewActivitySummary(
      days.fold(0, (sum, day) => sum + day.played),
      days.fold(0, (sum, day) => sum + day.won),
    );
    return _Card(
      title: l10n.overviewLast30Days,
      children: [
        Text(
          summary,
          key: const ValueKey('overview-activity-summary'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _BarChart(
          key: const ValueKey('overview-activity'),
          label: [
            l10n.overviewLast30Days,
            summary,
            for (final day in days)
              if (day.played > 0)
                l10n.overviewDayEntry(
                  formatShortDate(day.day, locale),
                  day.won,
                  day.notWon,
                ),
          ].join('. '),
          height: 110,
          lower: [for (final day in days) day.won],
          upper: [for (final day in days) day.notWon],
          lowerColor: _wonColor,
          upperColor: notWonColor,
          axis: [
            _AxisLabel(formatShortDate(days.first.day, locale)),
            _AxisLabel(l10n.overviewToday, align: TextAlign.end),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(_wonColor, l10n.statWon),
            _Legend(notWonColor, l10n.overviewNotWon),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _WhenYouPlayCard extends StatelessWidget {
  const _WhenYouPlayCard(this.stats);

  final OverviewStats stats;

  static const _hourLabels = [0, 6, 12, 18];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final weekdays = weekdaysInOrder(locale);
    final heading = theme.textTheme.labelLarge;
    return _Card(
      title: l10n.overviewWhenYouPlay,
      children: [
        Text(l10n.overviewByHour, style: heading),
        const SizedBox(height: 8),
        _BarChart(
          key: const ValueKey('overview-hours'),
          label: [
            l10n.overviewByHour,
            for (var hour = 0; hour < 24; hour++)
              if (stats.byHour[hour] > 0)
                l10n.overviewChartEntry(
                  formatHour(hour, locale),
                  stats.byHour[hour],
                ),
          ].join('. '),
          lower: stats.byHour,
          lowerColor: color,
          axis: [
            for (final hour in _hourLabels)
              _AxisLabel(formatHour(hour, locale)),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.overviewByWeekday, style: heading),
        const SizedBox(height: 8),
        _BarChart(
          key: const ValueKey('overview-weekdays'),
          label: [
            l10n.overviewByWeekday,
            for (final weekday in weekdays)
              l10n.overviewChartEntry(
                formatWeekday(weekday, locale),
                stats.byWeekday[weekday - DateTime.monday],
              ),
          ].join('. '),
          lower: [
            for (final weekday in weekdays)
              stats.byWeekday[weekday - DateTime.monday],
          ],
          lowerColor: color,
          axis: [
            for (final weekday in weekdays)
              _AxisLabel(
                formatWeekday(weekday, locale),
                align: TextAlign.center,
              ),
          ],
        ),
      ],
    );
  }
}

/// A label under a chart, in an equal share of its width.
class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text, {this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _chartTextStyle(context),
      ),
    );
  }
}

TextStyle? _chartTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// Bars on a base line, scaled to the highest one, whose value stands at the
/// end of a faint line. Each bar is its [lower] value with its [upper] value
/// on top; [axis] labels go under the bars. Screen readers read [label].
class _BarChart extends StatelessWidget {
  const _BarChart({
    super.key,
    required this.label,
    required this.lower,
    required this.lowerColor,
    required this.axis,
    this.upper,
    this.upperColor = Colors.transparent,
    this.height = 72,
  });

  final String label;
  final List<int> lower;
  final List<int>? upper;
  final Color lowerColor;
  final Color upperColor;
  final List<Widget> axis;
  final double height;

  /// Width of the value of the highest bar.
  static const _gutter = 28.0;

  @override
  Widget build(BuildContext context) {
    final upper = this.upper ?? List.filled(lower.length, 0);
    final highest = [for (var i = 0; i < lower.length; i++) lower[i] + upper[i]]
        .fold(0, max);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: CustomPaint(
                      painter: _BarsPainter(
                        lower: lower,
                        upper: upper,
                        highest: highest,
                        lowerColor: lowerColor,
                        upperColor: upperColor,
                        lineColor: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _gutter,
                  child: Text(
                    highest == 0
                        ? ''
                        : formatCount(
                            highest,
                            AppLocalizations.of(context).localeName,
                          ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: _chartTextStyle(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: _gutter),
              child: Row(children: axis),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.lower,
    required this.upper,
    required this.highest,
    required this.lowerColor,
    required this.upperColor,
    required this.lineColor,
  });

  final List<int> lower;
  final List<int> upper;
  final int highest;
  final Color lowerColor;
  final Color upperColor;
  final Color lineColor;

  /// Height of the line of the highest value: the middle of its label.
  static const _top = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 1;
    canvas.drawRect(
      Rect.fromLTWH(0, base, size.width, 1),
      Paint()..color = lineColor,
    );
    if (highest == 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, _top, size.width, 1),
      Paint()..color = lineColor.withValues(alpha: 0.4),
    );
    final slot = size.width / lower.length;
    final gap = min(4.0, slot * 0.3);
    final unit = (base - _top) / highest;
    for (var i = 0; i < lower.length; i++) {
      final left = i * slot + gap / 2;
      var bottom = base;
      for (final (value, color) in [
        (lower[i], lowerColor),
        (upper[i], upperColor),
      ]) {
        if (value == 0) continue;
        final top = bottom - value * unit;
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            top,
            left + slot - gap,
            bottom,
            const Radius.circular(2),
          ),
          Paint()..color = color,
        );
        bottom = top;
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      !listEquals(lower, old.lower) ||
      !listEquals(upper, old.upper) ||
      highest != old.highest ||
      lowerColor != old.lowerColor ||
      upperColor != old.upperColor ||
      lineColor != old.lineColor;
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard(this.stats);

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final OverviewStats(
      :fastestWin,
      :longestGame,
      :mostMovesWin,
      :mostPlayed,
      :mostTime,
    ) = stats;
    return _Card(
      title: l10n.statsRecords,
      children: [
        _RecordRow(
          'fastestWin',
          l10n.overviewFastestWin,
          fastestWin?.gameId,
          fastestWin == null ? null : formatClock(fastestWin.playTime),
        ),
        _RecordRow(
          'longestGame',
          l10n.overviewLongestGame,
          longestGame?.gameId,
          longestGame == null ? null : formatClock(longestGame.playTime),
        ),
        _RecordRow(
          'mostMovesWin',
          l10n.overviewMostMovesWin,
          mostMovesWin?.gameId,
          mostMovesWin == null ? null : l10n.recordMoves(mostMovesWin.moves),
        ),
        _RecordRow(
          'mostPlayed',
          l10n.overviewMostPlayed,
          mostPlayed?.gameId,
          mostPlayed == null ? null : l10n.overviewGames(mostPlayed.games),
        ),
        _RecordRow(
          'mostTime',
          l10n.overviewMostTime,
          mostTime?.gameId,
          mostTime == null ? null : formatLongDuration(mostTime.time, l10n),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(this.id, this.label, this.gameId, this.value);

  /// Names the row for tests, in any language.
  final String id;
  final String label;

  /// Both null without such a game, for example no win yet.
  final String? gameId;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gameId = this.gameId;
    final game = gameId == null ? null : gameById(gameId);
    return Padding(
      key: ValueKey('overview-stat-$id'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _GameIcon(game, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value == null
                      ? '—'
                      : '${game?.title(l10n) ?? gameId} · $value',
                  key: const ValueKey('value'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard(this.stats);

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      title: l10n.statsRecentGames,
      children: [
        for (final (index, record) in stats.recent.indexed)
          _RecentRow(index, record),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(this.index, this.record);

  /// 0 for the most recent game.
  final int index;
  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = gameById(record.gameId);
    final title = [
      game?.title(l10n) ?? record.gameId,
      if (game?.variants[record.variant] case final variant?
          when game!.variants.length > 1)
        variant(l10n),
      if (record.difficulty case final difficulty?)
        game?.difficulties[difficulty]?.call(l10n) ?? difficulty,
    ].join(' · ');
    final details = [
      switch (record.outcome) {
        GameOutcome.won => l10n.recordWon,
        GameOutcome.abandoned => l10n.recordAbandoned,
        GameOutcome.lost => l10n.recordLost,
      },
      formatClock(record.playTime),
      l10n.recordMoves(record.moves),
    ].join(' · ');
    final muted = theme.colorScheme.onSurfaceVariant;
    final detailStyle = theme.textTheme.bodySmall?.copyWith(color: muted);
    return InkWell(
      key: ValueKey('overview-recent-$index'),
      borderRadius: BorderRadius.circular(14),
      onTap: game == null
          ? null
          : () => context.push('/stats/${record.gameId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            _GameIcon(game, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // The date goes to the next line as a whole.
                  Wrap(
                    spacing: 10,
                    children: [
                      Text(details, style: detailStyle),
                      Text(
                        formatDateTime(record.endedAt, l10n.localeName),
                        style: detailStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(switch (record.outcome) {
              GameOutcome.won => Icons.emoji_events,
              GameOutcome.abandoned => Icons.flag_outlined,
              GameOutcome.lost => Icons.close,
            }, color: record.won ? _wonColor : muted),
          ],
        ),
      ),
    );
  }
}
