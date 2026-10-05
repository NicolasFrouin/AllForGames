import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../achievements/achievement_texts.dart';
import '../../achievements/achievements.dart';
import '../../app_stores.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'mahjong_board.dart';
import 'mahjong_controller.dart';
import 'mahjong_difficulty.dart';
import 'mahjong_difficulty_texts.dart';
import 'mahjong_new_game_sheet.dart';
import 'mahjong_state.dart';

/// A jade table, darker at the edges.
const _tableGradient = RadialGradient(
  radius: 1.1,
  colors: [Color(0xFF1D5450), Color(0xFF0C2B2B)],
);
const _barColor = Color(0xFF0B2A2A);

class MahjongScreen extends StatefulWidget {
  const MahjongScreen({
    super.key,
    required this.stores,
    this.difficulty,
    this.seed,
    this.initialState,
    this.clock,
  });

  final AppStores stores;

  /// [difficulty], [seed] and [initialState] ask for a new deal. Without any
  /// of them, the saved game continues. A new deal takes the difficulty of
  /// the settings when it has none.
  final MahjongDifficulty? difficulty;
  final int? seed;

  /// Starts from this board instead of a new deal (used by tests).
  final MahjongState? initialState;

  /// Source of time for the play timer (used by tests).
  final DateTime Function()? clock;

  @override
  State<MahjongScreen> createState() => _MahjongScreenState();
}

class _MahjongScreenState extends State<MahjongScreen> {
  MahjongController? _game;
  late final AppLifecycleListener _lifecycle;
  bool _appVisible = true;
  bool _resultShown = false;

  MahjongController get _controller => _game!;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Hiding pauses the game, which saves it: a closed browser tab keeps the
      // latest play time.
      onHide: () => _setAppVisible(false),
      onShow: () => _setAppVisible(true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new deal fits the screen: it needs the screen size.
    _game ??= _openGame()..addListener(_onGameChanged);
    // Runs again when this route stops or starts being the top route.
    _syncTimer();
  }

  /// Continues the saved game, unless the widget asks for a new deal: then
  /// the saved game counts as abandoned if it has moves.
  MahjongController _openGame() {
    final saved = _restoreSavedGame();
    final newDeal =
        widget.difficulty != null ||
        widget.seed != null ||
        widget.initialState != null;
    if (saved != null && !newDeal) return saved;
    final difficulty =
        widget.difficulty ?? widget.stores.settings.mahjongDifficulty;
    final transposed = _fitsTransposed(difficulty);
    if (saved != null) {
      return saved..newGame(
        difficulty: difficulty,
        transposed: transposed,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return MahjongController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      difficulty: difficulty,
      transposed: transposed,
      seed: widget.seed,
      initialState: widget.initialState,
      clock: widget.clock,
    );
  }

  MahjongController? _restoreSavedGame() {
    final saved = widget.stores.saves[MahjongController.gameId];
    if (saved == null) return null;
    try {
      return MahjongController.restore(
        saved.data,
        stats: widget.stores.stats,
        saves: widget.stores.saves,
        clock: widget.clock,
      );
    } on FormatException catch (error) {
      // For example a save of a newer app version: a new deal replaces it.
      debugPrint('MahjongScreen: cannot continue the saved game: $error');
      return null;
    }
  }

  /// Whether a new deal of [difficulty] gets bigger tiles with rows and
  /// columns swapped, on this screen (a phone held upright). The board keeps
  /// its orientation for the whole game: the rules depend on it.
  bool _fitsTransposed(MahjongDifficulty difficulty) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final room = Size(
      size.width - padding.horizontal,
      // The app bar and the status bar.
      size.height - padding.vertical - kToolbarHeight - 48,
    );
    return MahjongBoardGeometry.prefersTransposed(room, difficulty.layout());
  }

  void _setAppVisible(bool visible) {
    _appVisible = visible;
    _syncTimer();
  }

  /// Play time only counts while the game is on screen: the app is visible
  /// and no page or dialog (stats, menu) is on top of the game.
  void _syncTimer() {
    if (_appVisible && (ModalRoute.isCurrentOf(context) ?? true)) {
      _controller.resume();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller
      ..removeListener(_onGameChanged)
      // Saves the game (unless won): the next visit continues it.
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (_controller.result == null) _resultShown = false;
  }

  /// Called by the board once the win celebration has played.
  Future<void> _showWinDialog() async {
    final record = _controller.result;
    if (!mounted || record == null || _resultShown) return;
    _resultShown = true;
    final stores = widget.stores;
    final stats = stores.stats.statsFor(
      MahjongController.gameId,
      difficulty: record.difficulty,
    );
    // The record is already in the stats, but they tell their listeners only
    // after the save: this check unlocks what the win reached right away.
    stores.achievements.check(stores.stats.records);
    final unlocked = stores.achievements.takeAnnouncements();
    final playAgain = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 420),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      pageBuilder: (context, _, _) {
        final l10n = AppLocalizations.of(context);
        final combo = record.details[MahjongStatKeys.bestCombo] ?? 0;
        return AlertDialog(
          icon: const _Trophy(),
          title: Text(l10n.winTitle),
          // New achievements make it taller than a small phone.
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResultRow(l10n.time, formatClock(record.playTime)),
              _ResultRow(l10n.moves, '${record.moves}', count: record.moves),
              _ResultRow(l10n.score, '${record.score}', count: record.score),
              _ResultRow(l10n.mahjongBestCombo, '$combo'),
              const Divider(),
              _ResultRow(
                l10n.bestTime,
                formatClock(stats.bestTime ?? record.playTime),
              ),
              _ResultRow(l10n.winStreak, '${stats.currentStreak}'),
              _ResultRow(l10n.gamesWon, '${stats.won} / ${stats.played}'),
              for (final achievement in unlocked) ...[
                const SizedBox(height: 8),
                _UnlockedRow(achievement),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.backToGames),
            ),
            FilledButton(
              key: const ValueKey('play-again'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.playAgain),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (playAgain ?? false) {
      _controller.newGame(transposed: _fitsTransposed(_controller.difficulty));
    } else {
      context.go('/');
    }
  }

  /// Opens the new game sheet with the difficulty of the settings, then
  /// deals the chosen game and keeps its difficulty for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final difficulty = await showMahjongNewGameSheet(
      context,
      initial: settings.mahjongDifficulty,
      abandons: _controller.moves > 0 && _controller.result == null,
    );
    if (difficulty == null || !mounted) return;
    unawaited(settings.setMahjongDifficulty(difficulty));
    _controller.newGame(
      difficulty: difficulty,
      transposed: _fitsTransposed(difficulty),
    );
  }

  void _openStats() => context.push('/stats/${MahjongController.gameId}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _barColor,
        title: Text(l10n.mahjongTitle),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('undo'),
                  tooltip: l10n.undo,
                  onPressed: controller.canUndo ? controller.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: const ValueKey('hint'),
                  tooltip: l10n.hint,
                  onPressed: controller.canHint ? controller.hint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('new-game'),
            tooltip: l10n.newGame,
            onPressed: _newGame,
            icon: const Icon(Icons.add_box_outlined),
          ),
          IconButton(
            key: const ValueKey('open-stats'),
            tooltip: l10n.statistics,
            onPressed: _openStats,
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _tableGradient),
        child: SafeArea(
          child: Column(
            children: [
              _StatusBar(controller: controller),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        child: MahjongBoard(
                          controller: controller,
                          onCelebrated: _showWinDialog,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _StuckBanner(controller: controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offered as soon as no match is left: shuffle, or undo.
class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.controller});

  final MahjongController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: Duration(milliseconds: animate ? 280 : 0),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: !controller.isStuck
            ? const SizedBox.shrink()
            : Padding(
                key: const ValueKey('stuck-banner'),
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHigh,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shuffle,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l10n.mahjongStuck)),
                            ],
                          ),
                          OverflowBar(
                            spacing: 8,
                            overflowAlignment: OverflowBarAlignment.end,
                            children: [
                              if (controller.canUndo)
                                TextButton(
                                  onPressed: controller.undo,
                                  child: Text(l10n.undo),
                                ),
                              FilledButton.icon(
                                key: const ValueKey('shuffle'),
                                onPressed: controller.shuffle,
                                icon: const Icon(Icons.shuffle),
                                label: Text(l10n.mahjongShuffle),
                              ),
                            ],
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

class _StatusBar extends StatefulWidget {
  const _StatusBar({required this.controller});

  final MahjongController controller;

  @override
  State<_StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<_StatusBar> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = AppLocalizations.of(context);
    // A phone keeps the icons only, so the bar takes one line.
    final compact = MediaQuery.sizeOf(context).width < 480;
    String? label(String text) => compact ? null : text;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: compact ? 14 : 20,
          runSpacing: 4,
          children: [
            _StatusItem(
              id: 'time',
              icon: Icons.timer_outlined,
              value: formatClock(controller.playTime),
            ),
            _StatusItem(
              id: 'tiles',
              icon: Icons.grid_view,
              label: label(l10n.mahjongTiles),
              tooltip: l10n.mahjongTiles,
              value: '${controller.state.tileCount}',
            ),
            _StatusItem(
              id: 'pairs',
              icon: Icons.join_inner,
              label: label(l10n.mahjongOpenPairs),
              tooltip: l10n.mahjongOpenPairs,
              value: '${controller.state.freePairs.length}',
            ),
            _StatusItem(
              id: 'score',
              icon: Icons.star_outline,
              label: label(l10n.score),
              tooltip: l10n.score,
              value: '${controller.score}',
            ),
            _StatusItem(
              id: 'difficulty',
              icon: Icons.speed,
              value: controller.difficulty.label(l10n),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.id,
    required this.icon,
    required this.value,
    this.label,
    this.tooltip,
  });

  final String id;
  final IconData icon;
  final String value;
  final String? label;

  /// Names the value when the label is not shown.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    final item = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        // Large text can wrap a long label.
        if (label case final label?)
          Flexible(
            child: Text(
              '$label ',
              style: style.copyWith(color: Colors.white70),
            ),
          ),
        Text(value, key: ValueKey('$id-value'), style: style),
      ],
    );
    return label == null && tooltip != null
        ? Tooltip(message: tooltip, child: item)
        : item;
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.count});

  final String label;
  final String value;

  /// When given, the value counts up from 0 to [count] (then shows [value]).
  final int? count;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (count case final count?)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, shown, _) => Text(
                shown == count ? value : '${shown.round()}',
                style: style,
              ),
            )
          else
            Text(value, style: style),
        ],
      ),
    );
  }
}

/// The trophy of the win dialog: it springs in with a little swing.
class _Trophy extends StatelessWidget {
  const _Trophy();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * 0.6,
        child: Transform.scale(scale: t, child: child),
      ),
      child: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
    );
  }
}

/// An achievement that the win just unlocked, with the card back it gives.
class _UnlockedRow extends StatelessWidget {
  const _UnlockedRow(this.achievement);

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reward = cardBackUnlockedBy(achievement.id);
    return Container(
      key: ValueKey('unlocked-${achievement.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(achievement.icon, color: Colors.amber, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.achievementUnlocked,
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  achievementTitle(achievement.id, l10n),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (reward != null)
                  Text(
                    l10n.newCardBack(cardBackName(reward.id, l10n)),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (reward != null) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 30,
              height: 42,
              child: CardBackView(skin: reward, width: 30),
            ),
          ],
        ],
      ),
    );
  }
}
