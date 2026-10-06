import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
import '../l10n/app_localizations.dart';
import 'game_record.dart';
import 'game_stats.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.stores, required this.game});

  final AppStores stores;
  final GameInfo game;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Null means all variants, all difficulties.
  String? _variant;
  String? _difficulty;

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.statsResetTitle(widget.game.title(l10n))),
          content: Text(l10n.statsResetBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('confirm-reset'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.statsReset),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) await widget.stores.stats.clear(widget.game.id);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gameStatistics(game.title(l10n))),
        actions: [
          IconButton(
            key: const ValueKey('reset-stats'),
            tooltip: l10n.statsResetTooltip,
            onPressed: _confirmReset,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.stores.stats,
          builder: (context, _) {
            final records = widget.stores.stats.recordsFor(
              game.id,
              variant: _variant,
              difficulty: _difficulty,
            );
            final stats = GameStats.from(records);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (game.variants.isNotEmpty)
                      _filter(
                        'variant',
                        game.variants,
                        _variant,
                        (variant) => _variant = variant,
                        l10n,
                      ),
                    if (game.difficulties.isNotEmpty)
                      _filter(
                        'difficulty',
                        game.difficulties,
                        _difficulty,
                        (difficulty) => _difficulty = difficulty,
                        l10n,
                      ),
                    if (stats.played == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text(l10n.statsEmpty)),
                      )
                    else ...[
                      _Section(l10n.statsOverview, [
                        _StatTile('played', l10n.statPlayed, '${stats.played}'),
                        _StatTile('won', l10n.statWon, '${stats.won}'),
                        _StatTile(
                          'winRate',
                          l10n.statWinRate,
                          formatPercent(stats.winRate, locale),
                        ),
                        _StatTile(
                          'currentStreak',
                          l10n.statCurrentStreak,
                          '${stats.currentStreak}',
                        ),
                        _StatTile(
                          'bestStreak',
                          l10n.statBestStreak,
                          '${stats.bestStreak}',
                        ),
                        _StatTile(
                          'timePlayed',
                          l10n.timePlayed,
                          formatLongDuration(stats.totalPlayTime, l10n),
                        ),
                      ]),
                      _Section(l10n.statsRecords, [
                        _StatTile(
                          'bestTime',
                          l10n.bestTime,
                          _orDash(stats.bestTime, formatClock),
                        ),
                        _StatTile(
                          'averageWinTime',
                          l10n.statAverageWinTime,
                          _orDash(stats.averageWinTime, formatClock),
                        ),
                        _StatTile(
                          'fewestMoves',
                          l10n.statFewestMoves,
                          _orDash(stats.fewestMoves, _int),
                        ),
                        _StatTile(
                          'bestScore',
                          l10n.statBestScore,
                          _orDash(stats.bestScore, _int),
                        ),
                        _StatTile(
                          'totalMoves',
                          l10n.statTotalMoves,
                          '${stats.totalMoves}',
                        ),
                        _StatTile(
                          'totalUndos',
                          l10n.statTotalUndos,
                          '${stats.totalUndos}',
                        ),
                      ]),
                      if (stats.detailAverages.isNotEmpty)
                        _Section(l10n.statsAveragePerGame, [
                          for (final MapEntry(:key, :value)
                              in stats.detailAverages.entries)
                            _StatTile(
                              key,
                              game.detailLabels[key]?.call(l10n) ?? key,
                              _formatDetail(key, value, l10n),
                            ),
                        ]),
                      _RecentGames(records: records, game: game),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A row of chips keyed `<kind>-<value>`: All (null), then [values].
  Widget _filter(
    String kind,
    Map<String, LocalizedText> values,
    String? selected,
    void Function(String?) select,
    AppLocalizations l10n,
  ) {
    Widget chip(String? value, String label) => ChoiceChip(
      key: ValueKey('$kind-${value ?? 'all'}'),
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => setState(() => select(value)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(null, l10n.statsAllVariants),
          for (final MapEntry(:key, :value) in values.entries)
            chip(key, value(l10n)),
        ],
      ),
    );
  }

  static String _int(int value) => '$value';

  static String _orDash<T>(T? value, String Function(T) format) =>
      value == null ? '—' : format(value);

  static String _formatDetail(String key, double value, AppLocalizations l10n) {
    if (key.endsWith('Ms')) {
      return formatLongDuration(Duration(milliseconds: value.round()), l10n);
    }
    // One decimal at most: `16.5`, `31`.
    return NumberFormat('0.#', l10n.localeName).format(value);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.tiles);

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: tiles),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.id, this.label, this.value);

  /// Names the tile for tests, in any language.
  final String id;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('stat-$id'),
      // Two tiles per row on a 360 px wide phone.
      width: 150,
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

class _RecentGames extends StatelessWidget {
  const _RecentGames({required this.records, required this.game});

  final List<GameRecord> records;
  final GameInfo game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recent =
        (records.toList()..sort((a, b) => b.endedAt.compareTo(a.endedAt))).take(
          20,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statsRecentGames,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          for (final record in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (record.outcome) {
                GameOutcome.won => Icons.emoji_events,
                GameOutcome.abandoned => Icons.flag_outlined,
                GameOutcome.lost => Icons.close,
              }, color: record.won ? Colors.amber : null),
              title: Text(
                '${switch (record.outcome) {
                  GameOutcome.won => l10n.recordWon,
                  GameOutcome.abandoned => l10n.recordAbandoned,
                  GameOutcome.lost => l10n.recordLost,
                }}'
                ' · ${formatClock(record.playTime)}',
              ),
              subtitle: Text(
                [
                  game.variants[record.variant]?.call(l10n) ?? record.variant,
                  if (record.difficulty case final difficulty?)
                    game.difficulties[difficulty]?.call(l10n) ?? difficulty,
                  l10n.recordMoves(record.moves),
                  l10n.recordUndos(record.undos),
                  l10n.recordPoints(record.score),
                ].join(' · '),
              ),
              trailing: Text(formatDateTime(record.endedAt, l10n.localeName)),
            ),
        ],
      ),
    );
  }
}
