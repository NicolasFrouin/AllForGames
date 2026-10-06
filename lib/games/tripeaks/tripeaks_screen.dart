import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_stores.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/card_backs.dart';
import '../win_dialog.dart';
import 'tripeaks_board.dart';
import 'tripeaks_controller.dart';
import 'tripeaks_difficulty.dart';
import 'tripeaks_difficulty_texts.dart';
import 'tripeaks_new_game_sheet.dart';
import 'tripeaks_state.dart';

/// A teal felt, the colour of TriPeaks on the hub.
const _feltColor = Color(0xFF0B4F55);
const _barColor = Color(0xFF083C41);

class TriPeaksScreen extends StatefulWidget {
  const TriPeaksScreen({
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
  final TriPeaksDifficulty? difficulty;
  final int? seed;

  /// Starts from this board instead of a new deal (used by tests).
  final TriPeaksState? initialState;

  /// Source of time for the play timer (used by tests).
  final DateTime Function()? clock;

  @override
  State<TriPeaksScreen> createState() => _TriPeaksScreenState();
}

class _TriPeaksScreenState extends State<TriPeaksScreen> {
  late final TriPeaksController _controller;
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
  TriPeaksController _openGame() {
    final saved = _restoreSavedGame();
    final newDeal =
        widget.difficulty != null ||
        widget.seed != null ||
        widget.initialState != null;
    if (saved != null && !newDeal) return saved;
    final difficulty =
        widget.difficulty ?? widget.stores.settings.tripeaksDifficulty;
    if (saved != null) {
      return saved..newGame(
        difficulty: difficulty,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return TriPeaksController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      difficulty: difficulty,
      seed: widget.seed,
      initialState: widget.initialState,
      clock: widget.clock,
    );
  }

  TriPeaksController? _restoreSavedGame() {
    final saved = widget.stores.saves[TriPeaksController.gameId];
    if (saved == null) return null;
    try {
      return TriPeaksController.restore(
        saved.data,
        stats: widget.stores.stats,
        saves: widget.stores.saves,
        clock: widget.clock,
      );
    } on FormatException catch (error) {
      // For example a save of a newer app version: a new deal replaces it.
      debugPrint('TriPeaksScreen: cannot continue the saved game: $error');
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
    final l10n = AppLocalizations.of(context);
    final playAgain = await showWinDialog(
      context,
      stores: stores,
      record: record,
      stats: stores.stats.statsFor(
        TriPeaksController.gameId,
        difficulty: record.difficulty,
      ),
      rows: [
        (
          label: l10n.tripeaksLongestRun,
          value: '${record.details[TriPeaksStatKeys.longestRun] ?? 0}',
        ),
        (
          label: l10n.tripeaksStockLeft,
          value: '${record.details[TriPeaksStatKeys.stockLeft] ?? 0}',
        ),
      ],
    );
    if (!mounted) return;
    if (playAgain) {
      // Same level; a deal from a link has none.
      _controller.newGame(
        difficulty:
            _controller.difficulty ?? stores.settings.tripeaksDifficulty,
      );
    } else {
      context.go('/');
    }
  }

  /// Opens the new game sheet with the difficulty of the settings, then
  /// deals the chosen game and keeps its difficulty for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final difficulty = await showTriPeaksNewGameSheet(
      context,
      initial: settings.tripeaksDifficulty,
      abandons: _controller.moves > 0 && _controller.result == null,
    );
    if (difficulty == null || !mounted) return;
    unawaited(settings.setTripeaksDifficulty(difficulty));
    _controller.newGame(difficulty: difficulty);
  }

  void _openStats() => context.push('/stats/${TriPeaksController.gameId}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _feltColor,
      appBar: AppBar(
        backgroundColor: _barColor,
        title: Text(l10n.tripeaksTitle),
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
      body: SafeArea(
        child: Column(
          children: [
            _StatusBar(controller: _controller),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: widget.stores.settings,
                      builder: (context, _) => TriPeaksBoard(
                        controller: _controller,
                        cardBack: cardBackById(
                          widget.stores.settings.cardBackId,
                        ),
                        onCelebrated: _showWinDialog,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _StuckBanner(
                      controller: _controller,
                      onNewGame: _newGame,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown as soon as no move is left: undo, or a new game.
class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.controller, required this.onNewGame});

  final TriPeaksController controller;
  final VoidCallback onNewGame;

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
                                Icons.block,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l10n.tripeaksStuck)),
                            ],
                          ),
                          OverflowBar(
                            spacing: 8,
                            overflowAlignment: OverflowBarAlignment.end,
                            children: [
                              if (controller.canUndo)
                                TextButton(
                                  key: const ValueKey('stuck-undo'),
                                  onPressed: controller.undo,
                                  child: Text(l10n.undo),
                                ),
                              FilledButton.icon(
                                key: const ValueKey('stuck-new-game'),
                                onPressed: onNewGame,
                                icon: const Icon(Icons.add_box_outlined),
                                label: Text(l10n.newGame),
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

  final TriPeaksController controller;

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
    final compact = MediaQuery.sizeOf(context).width < 600;
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
              id: 'moves',
              icon: Icons.swap_horiz,
              label: label(l10n.moves),
              tooltip: l10n.moves,
              value: '${controller.moves}',
            ),
            _StatusItem(
              id: 'run',
              icon: Icons.trending_up,
              label: label(l10n.tripeaksRun),
              tooltip: l10n.tripeaksRun,
              value: '${controller.run}',
            ),
            _StatusItem(
              id: 'stock',
              icon: Icons.layers_outlined,
              label: label(l10n.tripeaksStock),
              tooltip: l10n.tripeaksStock,
              value: '${controller.state.stock.length}',
            ),
            _StatusItem(
              id: 'score',
              icon: Icons.star_outline,
              label: label(l10n.score),
              tooltip: l10n.score,
              value: '${controller.score}',
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
