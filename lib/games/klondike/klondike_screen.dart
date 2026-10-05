import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_stores.dart';
import '../../common/format.dart';
import 'klondike_board.dart';
import 'klondike_controller.dart';
import 'klondike_state.dart';

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
  /// of them, the saved game continues.
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
    final drawCount = widget.drawCount ?? 1;
    if (saved != null) {
      return saved..newGame(
        drawCount: drawCount,
        seed: widget.seed,
        initialState: widget.initialState,
      );
    }
    return KlondikeController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      drawCount: drawCount,
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
    if (_controller.result == null) {
      _resultShown = false;
    } else if (!_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
    }
  }

  Future<void> _showWinDialog() async {
    final record = _controller.result;
    if (!mounted || record == null) return;
    final stats = widget.stores.stats.statsFor(
      KlondikeController.gameId,
      variant: record.variant,
    );
    final playAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 40),
        title: const Text('You won!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow('Time', formatClock(record.playTime)),
            _ResultRow('Moves', '${record.moves}'),
            _ResultRow('Score', '${record.score}'),
            const Divider(),
            _ResultRow(
              'Best time',
              formatClock(stats.bestTime ?? record.playTime),
            ),
            _ResultRow('Win streak', '${stats.currentStreak}'),
            _ResultRow('Games won', '${stats.won} / ${stats.played}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back to games'),
          ),
          FilledButton(
            key: const ValueKey('play-again'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Play again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (playAgain ?? false) {
      _controller.newGame();
    } else {
      context.go('/');
    }
  }

  /// Asks first when the current game would count as abandoned.
  Future<void> _newGame(int drawCount) async {
    if (_controller.moves > 0 && _controller.result == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new game?'),
          content: const Text('The current game will count as abandoned.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-new-game'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('New game'),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false) || !mounted) return;
    }
    _controller.newGame(drawCount: drawCount);
  }

  void _openStats() => context.push('/stats/${KlondikeController.gameId}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: feltColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF08452C),
        title: const Text('Klondike'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              key: const ValueKey('undo'),
              tooltip: 'Undo',
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
            ),
          ),
          PopupMenuButton<int>(
            key: const ValueKey('new-game'),
            tooltip: 'New game',
            icon: const Icon(Icons.add_box_outlined),
            onSelected: _newGame,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 1, child: Text('New game · Draw 1')),
              PopupMenuItem(value: 3, child: Text('New game · Draw 3')),
            ],
          ),
          IconButton(
            key: const ValueKey('open-stats'),
            tooltip: 'Statistics',
            onPressed: _openStats,
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.canAutoComplete
            ? FloatingActionButton.extended(
                key: const ValueKey('auto-complete'),
                onPressed: _controller.autoComplete,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Finish'),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusBar(controller: _controller),
            Expanded(child: KlondikeBoard(controller: _controller)),
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
              label: 'Moves',
              value: '${controller.moves}',
            ),
            _StatusItem(
              id: 'score',
              icon: Icons.star_outline,
              label: 'Score',
              value: '${controller.score}',
            ),
            _StatusItem(
              id: 'draw',
              icon: Icons.style_outlined,
              value: 'Draw ${controller.state.drawCount}',
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
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
