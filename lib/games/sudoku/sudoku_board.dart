import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../skins/sudoku_themes.dart';
import 'sudoku_controller.dart';
import 'sudoku_grid.dart';
import 'sudoku_state.dart';

/// The grid, as large as its room allows (a square): a tap selects a cell.
/// A won grid plays a wave of light from its center, then calls
/// [onCelebrated] (at once with reduced motion).
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({
    super.key,
    required this.controller,
    required this.theme,
    required this.showNotes,
    this.onCelebrated,
  });

  final SudokuController controller;
  final SudokuTheme theme;

  /// Draws the small numbers (the setting that turns them on).
  final bool showNotes;
  final VoidCallback? onCelebrated;

  /// How long the wave of a win takes.
  static const celebration = Duration(milliseconds: 1100);

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard>
    with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(
    vsync: this,
    duration: SudokuBoard.celebration,
  )..addStatusListener(_onWave);
  final _digits = _DigitPainters();
  late bool _won = widget.controller.isWon;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGameChanged);
  }

  @override
  void didUpdateWidget(SudokuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGameChanged);
      widget.controller.addListener(_onGameChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameChanged);
    _wave.dispose();
    _digits.clear();
    super.dispose();
  }

  void _onGameChanged() {
    final won = widget.controller.isWon;
    if (won == _won) return;
    _won = won;
    if (!won) {
      _wave.value = 0;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      widget.onCelebrated?.call();
    } else {
      _wave.forward(from: 0);
    }
  }

  void _onWave(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCelebrated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GestureDetector(
              key: const ValueKey('sudoku-board'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final cell = side / SudokuGrid.size;
                final column = (details.localPosition.dx / cell).floor();
                final row = (details.localPosition.dy / cell).floor();
                if (row < 0 || row > 8 || column < 0 || column > 8) return;
                controller.select(row * SudokuGrid.size + column);
              },
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => CustomPaint(
                  painter: _BoardPainter(
                    state: controller.state,
                    selected: controller.selected,
                    theme: widget.theme,
                    showNotes: widget.showNotes,
                    wave: _wave,
                    digits: _digits,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Laid out digits, kept between frames: the wave of a win repaints every
/// frame.
class _DigitPainters {
  final _painters = <(String, Color, FontWeight, double), TextPainter>{};

  TextPainter of(String text, Color color, FontWeight weight, double size) {
    // Old sizes after the window changed size.
    if (_painters.length > 200) clear();
    return _painters.putIfAbsent(
      (text, color, weight, size),
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  void clear() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.state,
    required this.selected,
    required this.theme,
    required this.showNotes,
    required this.wave,
    required this.digits,
  }) : super(repaint: wave);

  final SudokuState state;
  final int? selected;
  final SudokuTheme theme;
  final bool showNotes;
  final Animation<double> wave;
  final _DigitPainters digits;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / SudokuGrid.size;
    final values = state.values;
    final conflicts = state.conflicts;
    final selected = this.selected;
    final selectedDigit = selected == null ? 0 : values[selected];
    final peers = selected == null
        ? const <int>{}
        : SudokuGrid.peers[selected].toSet();
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.paper);

    for (var i = 0; i < SudokuGrid.cellCount; i++) {
      final rect = Rect.fromLTWH(
        SudokuGrid.columnOf(i) * cell,
        SudokuGrid.rowOf(i) * cell,
        cell,
        cell,
      );
      final fill = i == selected
          ? theme.selected
          : selectedDigit != 0 && values[i] == selectedDigit
          ? theme.same
          : peers.contains(i)
          ? theme.peer
          : null;
      if (fill != null) canvas.drawRect(rect, Paint()..color = fill);
      if (conflicts.contains(i)) {
        canvas.drawRect(
          rect,
          Paint()..color = theme.conflict.withValues(alpha: 0.16),
        );
      }
      final glow = _glow(i);
      if (glow > 0) {
        canvas.drawRect(
          rect,
          Paint()..color = theme.same.withValues(alpha: glow),
        );
      }

      final value = values[i];
      if (value != 0) {
        final given = state.isGiven(i);
        final painter = digits.of(
          '$value',
          given
              ? theme.given
              : conflicts.contains(i)
              ? theme.conflict
              : theme.entry,
          given ? FontWeight.w700 : FontWeight.w500,
          (cell * 0.62).roundToDouble(),
        );
        final scale = 1 + glow * 0.3;
        canvas
          ..save()
          ..translate(rect.center.dx, rect.center.dy)
          ..scale(scale);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      } else if (showNotes && state.notes[i] != 0) {
        final small = cell / 3;
        for (var digit = 1; digit <= 9; digit++) {
          if (!state.hasNote(i, digit)) continue;
          final painter = digits.of(
            '$digit',
            theme.note,
            FontWeight.w600,
            (small * 0.8).roundToDouble(),
          );
          final center = Offset(
            rect.left + ((digit - 1) % 3 + 0.5) * small,
            rect.top + ((digit - 1) ~/ 3 + 0.5) * small,
          );
          painter.paint(
            canvas,
            center - Offset(painter.width / 2, painter.height / 2),
          );
        }
      }
    }

    final thin = Paint()
      ..color = theme.cellLine
      ..strokeWidth = max(1, size.width / 400);
    final thick = Paint()
      ..color = theme.boxLine
      ..strokeWidth = max(2, size.width / 150);
    for (var i = 1; i < SudokuGrid.size; i++) {
      if (i % 3 == 0) continue;
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), thin)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), thin);
    }
    for (var i = 3; i < SudokuGrid.size; i += 3) {
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), thick)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), thick);
    }
    canvas.drawRect(
      (Offset.zero & size).deflate(thick.strokeWidth / 2),
      Paint()
        ..color = theme.boxLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick.strokeWidth,
    );
  }

  /// The light of the win wave on cell [i], 0 to 1: it leaves the center
  /// and reaches the corners at the end.
  double _glow(int i) {
    final progress = wave.value;
    if (progress == 0) return 0;
    final distance = sqrt(
      pow(SudokuGrid.rowOf(i) - 4, 2) + pow(SudokuGrid.columnOf(i) - 4, 2),
    );
    final t = (progress * 1.6 - distance / sqrt(32) * 0.9) / 0.7;
    return t <= 0 || t >= 1 ? 0 : sin(t * pi) * 0.8;
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.selected != selected ||
      oldDelegate.theme != theme ||
      oldDelegate.showNotes != showNotes;
}
