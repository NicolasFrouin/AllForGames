import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_stores.dart';
import '../win_dialog.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../skins/tile_styles.dart';
import '../../stats/game_record.dart';
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
    this.mode,
    this.difficulty,
    this.seed,
    this.initialState,
    this.clock,
  });

  final AppStores stores;

  /// [mode], [difficulty], [seed] and [initialState] ask for a new deal.
  /// Without any of them, the saved game continues. A new deal takes the
  /// mode and the difficulty of the settings when it has none.
  final MahjongMode? mode;
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
        widget.mode != null ||
        widget.difficulty != null ||
        widget.seed != null ||
        widget.initialState != null;
    if (saved != null && !newDeal) return saved;
    final settings = widget.stores.settings;
    final mode = widget.mode ?? settings.mahjongMode;
    final difficulty = widget.difficulty ?? settings.mahjongDifficulty;
    final transposed = _fitsTransposed(difficulty, mode);
    if (saved != null) {
      return saved..newGame(
        difficulty: difficulty,
        mode: mode,
        transposed: transposed,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return MahjongController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      difficulty: difficulty,
      mode: mode,
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

  /// Whether a new deal of [difficulty] in [mode] gets bigger tiles with
  /// rows and columns swapped, on this screen (a phone held upright). The
  /// board keeps its orientation for the whole game: the rules depend on it.
  bool _fitsTransposed(MahjongDifficulty difficulty, MahjongMode mode) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final room = Size(
      size.width - padding.horizontal,
      // The app bar and the status bar.
      size.height - padding.vertical - kToolbarHeight - 48,
    );
    return MahjongBoardGeometry.prefersTransposed(
      room,
      difficulty.layout(),
      tray: mode == MahjongMode.tray
          ? widget.stores.settings.mahjongTraySide
          : null,
    );
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
    if (!mounted || record == null || !record.won || _resultShown) return;
    _resultShown = true;
    final stores = widget.stores;
    final l10n = AppLocalizations.of(context);
    final playAgain = await showWinDialog(
      context,
      stores: stores,
      record: record,
      stats: stores.stats.statsFor(
        MahjongController.gameId,
        variant: record.variant,
        difficulty: record.difficulty,
      ),
      rows: [
        (
          label: l10n.mahjongBestCombo,
          value: '${record.details[MahjongStatKeys.bestCombo] ?? 0}',
        ),
        if (record.details[MahjongStatKeys.mostHeld] case final held?)
          (label: l10n.mahjongMostHeld, value: '$held'),
      ],
    );
    if (!mounted) return;
    if (playAgain) {
      _dealAgain();
    } else {
      context.go('/');
    }
  }

  /// Called by the board once the full tray has flashed: the game is lost.
  /// Try again deals the same game, New game another one.
  Future<void> _showLossDialog() async {
    final record = _controller.result;
    if (!mounted || record == null || record.won || _resultShown) return;
    _resultShown = true;
    final tryAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TrayFullDialog(record: record),
    );
    if (!mounted || tryAgain == null) return;
    if (tryAgain) {
      _controller.newGame(seed: _controller.seed);
    } else {
      _dealAgain();
    }
  }

  /// A new deal of the same mode and difficulty.
  void _dealAgain() => _controller.newGame(
    transposed: _fitsTransposed(_controller.difficulty, _controller.mode),
  );

  /// Opens the new game sheet with the options of the settings, then deals
  /// the chosen game and keeps its options for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final options = await showMahjongNewGameSheet(
      context,
      initial: (
        mode: settings.mahjongMode,
        difficulty: settings.mahjongDifficulty,
      ),
      abandons: _controller.moves > 0 && _controller.result == null,
    );
    if (options == null || !mounted) return;
    final (:mode, :difficulty) = options;
    unawaited(settings.setMahjongMode(mode));
    unawaited(settings.setMahjongDifficulty(difficulty));
    _controller.newGame(
      difficulty: difficulty,
      mode: mode,
      transposed: _fitsTransposed(difficulty, mode),
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
                  onPressed: !controller.canHint
                      ? null
                      : controller.isTray
                      ? controller.hintPick
                      : controller.hint,
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
                child: ListenableBuilder(
                  listenable: widget.stores.settings,
                  builder: (context, _) {
                    final settings = widget.stores.settings;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                            child: MahjongBoard(
                              controller: controller,
                              tileStyle: tileStyleById(settings.tileStyleId),
                              traySide: settings.mahjongTraySide,
                              onCelebrated: _showWinDialog,
                              onLost: _showLossDialog,
                            ),
                          ),
                        ),
                        _StuckBanner(
                          controller: controller,
                          trayAtBottom:
                              settings.mahjongTraySide ==
                              MahjongTraySide.bottom,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tray is full: the game is lost. Shows what the game reached, and
/// returns true for Try again (the same deal), false for New game.
class _TrayFullDialog extends StatelessWidget {
  const _TrayFullDialog({required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget row(String label, Object? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${value ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return AlertDialog(
      key: const ValueKey('tray-full'),
      icon: Icon(Icons.inbox, size: 40, color: theme.colorScheme.error),
      title: Text(l10n.mahjongTrayFullTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mahjongTrayFullMessage),
          const SizedBox(height: 12),
          row(
            l10n.mahjongPairsMatched,
            record.details[MahjongStatKeys.pairsMatched],
          ),
          row(l10n.mahjongTilesLeft, record.details[MahjongStatKeys.tilesLeft]),
          row(l10n.time, formatClock(record.playTime)),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('lost-new-game'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.newGame),
        ),
        FilledButton(
          key: const ValueKey('try-again'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// Offered as soon as no move is left that does not lose: in classic mode
/// shuffle, or undo; in tray mode undo.
class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.controller, required this.trayAtBottom});

  final MahjongController controller;

  /// In tray mode, a tray at the bottom puts the banner at the top.
  final bool trayAtBottom;

  bool get _atTop => trayAtBottom && controller.isTray;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Align(
        alignment: _atTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: animate ? 280 : 0),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween(begin: Offset(0, _atTop ? -1 : 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
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
                                  controller.isTray
                                      ? Icons.inbox
                                      : Icons.shuffle,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    controller.isTray
                                        ? l10n.mahjongTrayStuck
                                        : l10n.mahjongStuck,
                                  ),
                                ),
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
                                if (!controller.isTray)
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
              value: '${controller.tilesLeft}',
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
            // Tray mode names itself with the level, so a phone keeps one
            // line.
            if (controller.isTray)
              _StatusItem(
                id: 'mode',
                icon: Icons.view_week_outlined,
                value:
                    '${controller.mode.label(l10n)} · '
                    '${controller.difficulty.label(l10n)}',
              )
            else
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
        // Large text can wrap a long label, or a long value.
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
