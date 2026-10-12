import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_stores.dart';
import '../../common/format.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_store.dart';
import '../../skins/sudoku_themes.dart';
import '../win_dialog.dart';
import 'sudoku_board.dart';
import 'sudoku_controller.dart';
import 'sudoku_deal.dart';
import 'sudoku_keypad.dart';
import 'sudoku_level.dart';
import 'sudoku_level_texts.dart';
import 'sudoku_new_game_sheet.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({
    super.key,
    required this.stores,
    this.level,
    this.seed,
    this.deal,
    this.clock,
  });

  final AppStores stores;

  /// [level], [seed] and [deal] ask for a new game. Without any of them,
  /// the saved game continues. A new game takes the level of the settings
  /// when it has none.
  final SudokuLevel? level;
  final int? seed;

  /// Plays this puzzle instead of the deal of the seed (used by tests).
  final SudokuDeal? deal;

  /// Source of time for the play timer (used by tests).
  final DateTime Function()? clock;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuController _controller = _openGame()
    ..addListener(_onGameChanged);
  late final AppLifecycleListener _lifecycle;
  bool _appVisible = true;
  bool _resultShown = false;
  bool _notesMode = false;

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
    // Runs again when this route stops or starts being the top route.
    _syncTimer();
  }

  /// Continues the saved game, unless the widget asks for a new one: then
  /// the saved game leaves no record.
  SudokuController _openGame() {
    final saved = _restoreSavedGame();
    final newGame =
        widget.level != null || widget.seed != null || widget.deal != null;
    if (saved != null && !newGame) return saved;
    final level = widget.level ?? widget.stores.settings.sudokuLevel;
    if (saved != null) {
      return saved..newGame(level: level, seed: widget.seed, deal: widget.deal);
    }
    return SudokuController(
      stats: widget.stores.stats,
      saves: widget.stores.saves,
      level: level,
      seed: widget.seed,
      deal: widget.deal,
      clock: widget.clock,
    );
  }

  SudokuController? _restoreSavedGame() {
    final saved = widget.stores.saves[SudokuController.gameId];
    if (saved == null) return null;
    try {
      return SudokuController.restore(
        saved.data,
        stats: widget.stores.stats,
        saves: widget.stores.saves,
        clock: widget.clock,
      );
    } on FormatException catch (error) {
      // For example a save of a newer app version: a new game replaces it.
      debugPrint('SudokuScreen: cannot continue the saved game: $error');
      return null;
    }
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

  /// Called by the board once the win wave has played.
  Future<void> _showWinDialog() async {
    final record = _controller.result;
    if (!mounted || record == null || _resultShown) return;
    _resultShown = true;
    final stores = widget.stores;
    final l10n = AppLocalizations.of(context);
    final choice = await showWinDialog(
      context,
      stores: stores,
      record: record,
      stats: stores.stats.statsFor(
        SudokuController.gameId,
        difficulty: record.difficulty,
      ),
      rows: [(label: l10n.difficulty, value: _controller.level.label(l10n))],
    );
    if (!mounted) return;
    switch (choice) {
      case WinChoice.playAgain:
        _controller.newGame();
      case WinChoice.otherOptions:
        await _newGame();
      case WinChoice.leave:
        context.go('/');
    }
  }

  /// Opens the new game sheet with the level of the settings, then deals the
  /// chosen game and keeps its level for the next time.
  Future<void> _newGame() async {
    final settings = widget.stores.settings;
    final choice = await showSudokuNewGameSheet(
      context,
      initial: settings.sudokuLevel,
      inProgress: _controller.started && !_controller.isWon,
    );
    if (choice == null || !mounted) return;
    final (options: level, :abandon) = choice;
    unawaited(settings.setSudokuLevel(level));
    _controller.newGame(level: level, abandon: abandon);
  }

  void _openStats() => context.push('/stats/${SudokuController.gameId}');

  bool get _writesNotes => widget.stores.settings.sudokuNotes && _notesMode;

  /// Digits, erase, arrows; undo and redo with Ctrl (Cmd) + Z and Y; N for
  /// the small numbers.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final controller = _controller;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyZ) {
        keyboard.isShiftPressed ? controller.redo() : controller.undo();
      } else if (key == LogicalKeyboardKey.keyY) {
        controller.redo();
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    final digit = int.tryParse(event.character ?? '');
    if (digit != null && digit >= 1) {
      controller.enter(digit, note: _writesNotes);
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        digit == 0) {
      controller.erase();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      controller.moveSelection(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      controller.moveSelection(1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveSelection(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveSelection(0, 1);
    } else if (key == LogicalKeyboardKey.keyN &&
        widget.stores.settings.sudokuNotes) {
      setState(() => _notesMode = !_notesMode);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.stores.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _page(context, settings),
    );
  }

  Widget _page(BuildContext context, SettingsStore settings) {
    final theme = sudokuThemeById(settings.sudokuThemeId);
    final l10n = AppLocalizations.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.bar,
          title: Text(l10n.sudokuTitle),
          actions: [
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
                _StatusBar(controller: _controller),
                Expanded(child: _table(settings, theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The grid as large as it fits, with the keypad under it on a tall
  /// screen (digits in one row) or beside it on a wide one (three rows).
  Widget _table(SettingsStore settings, SudokuTheme theme) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final board = SudokuBoard(
        controller: _controller,
        theme: theme,
        showNotes: settings.sudokuNotes,
        onCelebrated: _showWinDialog,
      );
      Widget keypad(int columns) => SudokuKeypad(
        controller: _controller,
        theme: theme,
        columns: columns,
        notesEnabled: settings.sudokuNotes,
        notesMode: _notesMode,
        onNotesMode: (on) => setState(() => _notesMode = on),
      );

      if (width > height * 1.1) {
        // The keypad beside the grid, the two side by side in the middle.
        final keypadWidth = min(360.0, width * 0.38);
        final side = min(height - 24, width - keypadWidth - 40);
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: side, child: board),
              const SizedBox(width: 16),
              SizedBox(
                width: keypadWidth,
                // Square digit keys under the tools.
                height: min(side, keypadWidth + 72),
                child: keypad(3),
              ),
            ],
          ),
        );
      }
      // The keypad under the grid: three rows of large digit keys when the
      // screen is tall enough, else one row of nine.
      const tools = 64 + 8.0;
      final side = min(width - 16, height - 24 - tools - 52);
      final free = height - 24 - side - tools;
      final threeRows = free >= 3 * 60;
      final keypadWidth = threeRows ? side : min(width - 16, 640.0);
      final digits = min(free, threeRows ? 3 * 84.0 : 84.0);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: side, child: board),
            const SizedBox(height: 12),
            SizedBox(
              width: keypadWidth,
              height: tools + digits,
              child: keypad(threeRows ? 3 : 9),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusBar extends StatefulWidget {
  const _StatusBar({required this.controller});

  final SudokuController controller;

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
    const style = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    Widget item(String id, IconData icon, String value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(value, key: ValueKey('$id-value'), style: style),
        ),
      ],
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 4,
          children: [
            item(
              'time',
              Icons.timer_outlined,
              formatClock(controller.playTime),
            ),
            item(
              'difficulty',
              Icons.speed,
              '${controller.level.label(l10n)} · '
                  '${controller.level.group(l10n)}',
            ),
          ],
        ),
      ),
    );
  }
}
