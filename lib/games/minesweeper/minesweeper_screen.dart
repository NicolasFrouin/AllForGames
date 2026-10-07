import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_stores.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_store.dart';
import '../../skins/minesweeper_themes.dart';
import '../win_dialog.dart';
import 'minesweeper_board.dart';
import 'minesweeper_controller.dart';
import 'minesweeper_difficulty.dart';
import 'minesweeper_difficulty_texts.dart';
import 'minesweeper_new_game_sheet.dart';
import 'minesweeper_state.dart';

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({
    super.key,
    required this.stores,
    this.difficulty,
    this.seed,
    this.initialState,
    this.clock,
  });

  final AppStores stores;

  /// [difficulty], [seed] and [initialState] ask for a new game. Without any
  /// of them, the saved game continues. A new game takes the level of the
  /// settings when it has none.
  final MinesweeperDifficulty? difficulty;
  final int? seed;

  /// Starts from this board instead of a new one (used by tests).
  final MinesweeperState? initialState;

  /// Source of time for the play timer (used by tests).
  final DateTime Function()? clock;

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  MinesweeperController? _game;
  late final AppLifecycleListener _lifecycle;
  bool _appVisible = true;
  bool _resultShown = false;
  bool _flagMode = false;

  /// The loss banner shows once the mines of a lost game have shown.
  final _lossShown = ValueNotifier(false);

  MinesweeperController get _controller => _game!;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Hiding pauses the game, which saves it: a closed browser tab keeps the
      // latest play time.
      onHide: () => _setAppVisible(false),
      onShow: () => _setAppVisible(true),
    );
    // A right click flags a cell: the browser menu would cover the board.
    if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new board fits the screen: it needs the screen size.
    _game ??= _openGame()..addListener(_onGameChanged);
    // Runs again when this route stops or starts being the top route.
    _syncTimer();
  }

  /// Continues the saved game, unless the widget asks for a new one: then
  /// the saved game counts as abandoned if it was started.
  MinesweeperController _openGame() {
    final saved = _restoreSavedGame();
    final newGame =
        widget.difficulty != null ||
        widget.seed != null ||
        widget.initialState != null;
    if (saved != null && !newGame) return saved;
    final difficulty =
        widget.difficulty ?? widget.stores.settings.minesweeperDifficulty;
    final turned = _fitsTurned(difficulty);
    if (saved != null) {
      return saved..newGame(
        difficulty: difficulty,
        turned: turned,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return MinesweeperController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      difficulty: difficulty,
      turned: turned,
      seed: widget.seed,
      initialState: widget.initialState,
      clock: widget.clock,
    );
  }

  MinesweeperController? _restoreSavedGame() {
    final saved = widget.stores.saves[MinesweeperController.gameId];
    if (saved == null) return null;
    try {
      return MinesweeperController.restore(
        saved.data,
        stats: widget.stores.stats,
        saves: widget.stores.saves,
        clock: widget.clock,
      );
    } on FormatException catch (error) {
      // For example a save of a newer app version: a new game replaces it.
      debugPrint('MinesweeperScreen: cannot continue the saved game: $error');
      return null;
    }
  }

  /// Whether a new board of [difficulty] gets bigger cells with rows and
  /// columns swapped, on this screen (a phone held upright). The board keeps
  /// its orientation for the whole game.
  bool _fitsTurned(MinesweeperDifficulty difficulty) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final room = Size(
      size.width - padding.horizontal - 16,
      // The app bar and the status bar.
      size.height - padding.vertical - kToolbarHeight - 56,
    );
    return MinesweeperBoardGeometry.prefersTurned(room, difficulty);
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
    if (kIsWeb) unawaited(BrowserContextMenu.enableContextMenu());
    _lifecycle.dispose();
    _lossShown.dispose();
    _controller
      ..removeListener(_onGameChanged)
      // Saves the game (unless finished): the next visit continues it.
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _onGameChanged() {
    if (_controller.result == null) {
      _resultShown = false;
      _lossShown.value = false;
    }
  }

  /// Called by the board once the win celebration has played.
  Future<void> _showWinDialog() async {
    final record = _controller.result;
    if (!mounted || record == null || !record.won || _resultShown) return;
    _resultShown = true;
    final stores = widget.stores;
    final l10n = AppLocalizations.of(context);
    final boardValue = record.details[MinesweeperStatKeys.boardValue] ?? 0;
    final seconds = record.playTime.inMilliseconds / 1000;
    final playAgain = await showWinDialog(
      context,
      stores: stores,
      record: record,
      stats: stores.stats.statsFor(
        MinesweeperController.gameId,
        difficulty: record.difficulty,
      ),
      rows: [
        (label: l10n.minesweeperBoardValue, value: '$boardValue'),
        (
          label: l10n.minesweeperBoardValuePerSecond,
          value: NumberFormat(
            '0.00',
            l10n.localeName,
          ).format(seconds <= 0 ? 0 : boardValue / seconds),
        ),
      ],
    );
    if (!mounted) return;
    if (playAgain) {
      _replay();
    } else {
      context.go('/');
    }
  }

  /// A new board of the same level.
  void _replay() =>
      _controller.newGame(turned: _fitsTurned(_controller.difficulty));

  /// Opens the new game sheet with the level of the settings, then deals the
  /// chosen game and keeps its level for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final difficulty = await showMinesweeperNewGameSheet(
      context,
      initial: settings.minesweeperDifficulty,
      abandons: _controller.started && !_controller.isOver,
    );
    if (difficulty == null || !mounted) return;
    unawaited(settings.setMinesweeperDifficulty(difficulty));
    _controller.newGame(
      difficulty: difficulty,
      turned: _fitsTurned(difficulty),
    );
  }

  void _openStats() => context.push('/stats/${MinesweeperController.gameId}');

  @override
  Widget build(BuildContext context) {
    final settings = widget.stores.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _page(context, settings),
    );
  }

  Widget _page(BuildContext context, SettingsStore settings) {
    final theme = minesweeperThemeById(settings.minesweeperThemeId);
    final l10n = AppLocalizations.of(context);
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.bar,
        title: Text(l10n.minesweeperTitle),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('flag-mode'),
                  tooltip: l10n.minesweeperFlagMode,
                  isSelected: _flagMode,
                  onPressed: controller.isOver
                      ? null
                      : () => setState(() => _flagMode = !_flagMode),
                  // On, it stands out: every tap now flags.
                  style: _flagMode
                      ? IconButton.styleFrom(backgroundColor: Colors.white24)
                      : null,
                  icon: const Icon(Icons.outlined_flag),
                  selectedIcon: Icon(Icons.flag, color: theme.flag),
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
        decoration: BoxDecoration(
          gradient: RadialGradient(radius: 1.1, colors: theme.table),
        ),
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
                        child: MinesweeperBoard(
                          controller: controller,
                          theme: theme,
                          flagMode: _flagMode,
                          flagHold: Duration(
                            milliseconds: settings.minesweeperFlagHoldMs,
                          ),
                          vibrate: settings.minesweeperVibrate,
                          onCelebrated: _showWinDialog,
                          onLost: () => _lossShown.value = true,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _LossBanner(
                        shown: _lossShown,
                        onRetry: controller.retry,
                        onNewGame: _replay,
                      ),
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

/// After a loss: play the same board again, or a new one.
class _LossBanner extends StatelessWidget {
  const _LossBanner({
    required this.shown,
    required this.onRetry,
    required this.onNewGame,
  });

  final ValueListenable<bool> shown;
  final VoidCallback onRetry;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder(
      valueListenable: shown,
      builder: (context, shown, _) => AnimatedSwitcher(
        duration: Duration(milliseconds: animate ? 280 : 0),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: !shown
            ? const SizedBox.shrink()
            : Padding(
                key: const ValueKey('loss-banner'),
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
                                Icons.dangerous_outlined,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l10n.minesweeperLost)),
                            ],
                          ),
                          OverflowBar(
                            spacing: 8,
                            overflowAlignment: OverflowBarAlignment.end,
                            children: [
                              TextButton(
                                key: const ValueKey('lost-new-game'),
                                onPressed: onNewGame,
                                child: Text(l10n.newGame),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('try-again'),
                                onPressed: onRetry,
                                icon: const Icon(Icons.replay),
                                label: Text(l10n.tryAgain),
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

  final MinesweeperController controller;

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
              id: 'mines-left',
              icon: Icons.flag_outlined,
              label: compact ? null : l10n.minesweeperMinesLeft,
              tooltip: l10n.minesweeperMinesLeft,
              value: '${controller.minesLeft}',
            ),
            _StatusItem(
              id: 'time',
              icon: Icons.timer_outlined,
              value: formatClock(controller.playTime),
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
        // Large text can wrap a long label or value.
        if (label case final label?)
          Flexible(
            child: Text(
              '$label ',
              style: style.copyWith(color: Colors.white70),
            ),
          ),
        Flexible(
          child: Text(value, key: ValueKey('$id-value'), style: style),
        ),
      ],
    );
    return label == null && tooltip != null
        ? Tooltip(message: tooltip, child: item)
        : item;
  }
}
