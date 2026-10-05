import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../achievements/achievement_texts.dart';
import '../../achievements/achievements.dart';
import '../../app_stores.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import 'klondike_board.dart';
import 'klondike_controller.dart';
import 'klondike_difficulty_texts.dart';
import 'klondike_state.dart';
import 'new_game_sheet.dart';

const feltColor = Color(0xFF0B5D3B);

class KlondikeScreen extends StatefulWidget {
  const KlondikeScreen({
    super.key,
    required this.stores,
    this.drawCount,
    this.seed,
    this.initialState,
    this.clock,
  });

  final AppStores stores;

  /// [drawCount], [seed] and [initialState] ask for a new deal. Without any
  /// of them, the saved game continues. A new deal takes the options of the
  /// settings for the others.
  final int? drawCount;
  final int? seed;

  /// Starts from this board instead of a new deal (used by tests).
  final KlondikeState? initialState;

  /// Source of time for the play timer (used by tests).
  final DateTime Function()? clock;

  @override
  State<KlondikeScreen> createState() => _KlondikeScreenState();
}

class _KlondikeScreenState extends State<KlondikeScreen> {
  late final KlondikeController _controller;
  late final AppLifecycleListener _lifecycle;
  bool _appVisible = true;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _controller = _openGame()..addListener(_onGameChanged);
    _lifecycle = AppLifecycleListener(
      // Hiding pauses the game, which saves it: a closed browser tab keeps the
      // latest play time.
      onHide: () => _setAppVisible(false),
      onShow: () => _setAppVisible(true),
    );
  }

  /// Continues the saved game, unless the widget asks for a new deal: then
  /// the saved game counts as abandoned if it has moves.
  KlondikeController _openGame() {
    final saved = _restoreSavedGame();
    final newDeal =
        widget.drawCount != null ||
        widget.seed != null ||
        widget.initialState != null;
    if (saved != null && !newDeal) return saved;
    final settings = widget.stores.settings;
    final drawCount = widget.drawCount ?? settings.klondikeDrawCount;
    final difficulty = settings.klondikeDifficulty;
    if (saved != null) {
      return saved..newGame(
        drawCount: drawCount,
        difficulty: difficulty,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return KlondikeController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      drawCount: drawCount,
      difficulty: difficulty,
      seed: widget.seed,
      initialState: widget.initialState,
      clock: widget.clock,
    );
  }

  KlondikeController? _restoreSavedGame() {
    final saved = widget.stores.saves[KlondikeController.gameId];
    if (saved == null) return null;
    try {
      return KlondikeController.restore(
        saved.data,
        stats: widget.stores.stats,
        saves: widget.stores.saves,
        clock: widget.clock,
      );
    } on FormatException catch (error) {
      // For example a save of a newer app version: a new deal replaces it.
      debugPrint('KlondikeScreen: cannot continue the saved game: $error');
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again when this route stops or starts being the top route.
    _syncTimer();
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
      KlondikeController.gameId,
      variant: record.variant,
    );
    // The record is already in the stats, but they tell their listeners only
    // after the save: this check unlocks what the win reached right away.
    stores.achievements.check(stores.stats.records);
    final unlocked = stores.achievements.takeAnnouncements();
    final playAgain = await showGeneralDialog<bool>(
      context: context,
      // Light, so the confetti stays visible behind the dialog.
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
      // Same options; a deal from a link has no difficulty.
      _controller.newGame(
        difficulty:
            _controller.difficulty ?? stores.settings.klondikeDifficulty,
      );
    } else {
      context.go('/');
    }
  }

  /// Opens the new game sheet with the options of the settings, then deals
  /// the chosen game and keeps its options for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final options = await showNewGameSheet(
      context,
      initial: (
        drawCount: settings.klondikeDrawCount,
        difficulty: settings.klondikeDifficulty,
      ),
      abandons: _controller.moves > 0 && _controller.result == null,
    );
    if (options == null || !mounted) return;
    unawaited(
      settings.setKlondikeNewGame(
        drawCount: options.drawCount,
        difficulty: options.difficulty,
      ),
    );
    _controller.newGame(
      drawCount: options.drawCount,
      difficulty: options.difficulty,
    );
  }

  void _openStats() => context.push('/stats/${KlondikeController.gameId}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: feltColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF08452C),
        title: Text(l10n.klondikeTitle),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              key: const ValueKey('undo'),
              tooltip: l10n.undo,
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
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
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          ),
          child: _controller.canAutoComplete
              ? FloatingActionButton.extended(
                  key: const ValueKey('auto-complete'),
                  onPressed: _controller.autoComplete,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(l10n.finish),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusBar(controller: _controller),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.stores.settings,
                builder: (context, _) => KlondikeBoard(
                  controller: _controller,
                  cardBack: cardBackById(widget.stores.settings.cardBackId),
                  onCelebrated: _showWinDialog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatefulWidget {
  const _StatusBar({required this.controller});

  final KlondikeController controller;

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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 4,
          children: [
            _StatusItem(
              id: 'time',
              icon: Icons.timer_outlined,
              value: formatClock(controller.playTime),
            ),
            _StatusItem(
              id: 'moves',
              icon: Icons.swap_horiz,
              label: l10n.moves,
              value: '${controller.moves}',
            ),
            _StatusItem(
              id: 'score',
              icon: Icons.star_outline,
              label: l10n.score,
              value: '${controller.score}',
            ),
            _StatusItem(
              id: 'draw',
              icon: Icons.style_outlined,
              value: l10n.klondikeDraw(controller.state.drawCount),
            ),
            if (controller.difficulty case final difficulty?)
              _StatusItem(
                id: 'difficulty',
                icon: Icons.speed,
                value: difficulty.label(l10n),
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
  });

  final String id;
  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        if (label case final label?)
          Text('$label ', style: style.copyWith(color: Colors.white70)),
        Text(value, key: ValueKey('$id-value'), style: style),
      ],
    );
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
