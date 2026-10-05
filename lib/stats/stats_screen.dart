import 'package:material_ui/material_ui.dart';

import '../app_stores.dart';
import '../common/format.dart';
import '../games/game_catalog.dart';
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
  /// Null means all variants.
  String? _variant;

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset ${widget.game.title} statistics?'),
        content: const Text('This deletes all saved games of this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await widget.stores.stats.clear(widget.game.id);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.title} statistics'),
        actions: [
          IconButton(
            key: const ValueKey('reset-stats'),
            tooltip: 'Reset statistics',
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
            );
            final stats = GameStats.from(records);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (game.variants.isNotEmpty) _variantFilter(game),
                    if (stats.played == 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'No games yet. Play one to see your statistics.',
                          ),
                        ),
                      )
                    else ...[
                      _Section('Overview', [
                        _StatTile('Played', '${stats.played}'),
                        _StatTile('Won', '${stats.won}'),
                        _StatTile('Win rate', formatPercent(stats.winRate)),
                        _StatTile('Current streak', '${stats.currentStreak}'),
                        _StatTile('Best streak', '${stats.bestStreak}'),
                        _StatTile(
                          'Time played',
                          formatLongDuration(stats.totalPlayTime),
                        ),
                      ]),
                      _Section('Records', [
                        _StatTile(
                          'Best time',
                          _orDash(stats.bestTime, formatClock),
                        ),
                        _StatTile(
                          'Average win time',
                          _orDash(stats.averageWinTime, formatClock),
                        ),
                        _StatTile(
                          'Fewest moves',
                          _orDash(stats.fewestMoves, _int),
                        ),
                        _StatTile('Best score', _orDash(stats.bestScore, _int)),
                        _StatTile('Total moves', '${stats.totalMoves}'),
                        _StatTile('Total undos', '${stats.totalUndos}'),
                      ]),
                      if (stats.detailAverages.isNotEmpty)
                        _Section('Average per game', [
                          for (final MapEntry(:key, :value)
                              in stats.detailAverages.entries)
                            _StatTile(
                              game.detailLabels[key] ?? key,
                              _formatDetail(key, value),
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

  Widget _variantFilter(GameInfo game) {
    Widget chip(String? variant, String label) => ChoiceChip(
      key: ValueKey('variant-${variant ?? 'all'}'),
      label: Text(label),
      selected: _variant == variant,
      onSelected: (_) => setState(() => _variant = variant),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        children: [
          chip(null, 'All'),
          for (final MapEntry(:key, :value) in game.variants.entries)
            chip(key, value),
        ],
      ),
    );
  }

  static String _int(int value) => '$value';

  static String _orDash<T>(T? value, String Function(T) format) =>
      value == null ? '—' : format(value);

  static String _formatDetail(String key, double value) {
    if (key.endsWith('Ms')) {
      return formatLongDuration(Duration(milliseconds: value.round()));
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
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
  const _StatTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('stat-$label'),
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
    final recent =
        (records.toList()..sort((a, b) => b.endedAt.compareTo(a.endedAt))).take(
          20,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent games', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final record in recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                record.won ? Icons.emoji_events : Icons.flag_outlined,
                color: record.won ? Colors.amber : null,
              ),
              title: Text(
                '${record.won ? 'Won' : 'Abandoned'} · ${formatClock(record.playTime)}',
              ),
              subtitle: Text(
                [
                  game.variants[record.variant] ?? record.variant,
                  '${record.moves} moves',
                  '${record.undos} undos',
                  '${record.score} pts',
                ].join(' · '),
              ),
              trailing: Text(formatDateTime(record.endedAt)),
            ),
        ],
      ),
    );
  }
}
