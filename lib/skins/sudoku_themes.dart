import 'package:material_ui/material_ui.dart';

/// The colors of the Sudoku screen, grid and keypad.
class SudokuTheme {
  const SudokuTheme({
    required this.id,
    required this.table,
    required this.bar,
    required this.paper,
    required this.boxLine,
    required this.cellLine,
    required this.given,
    required this.entry,
    required this.note,
    required this.selected,
    required this.peer,
    required this.same,
    required this.conflict,
    required this.key,
    required this.keyText,
    this.unlockedBy,
  });

  final String id;

  /// The table around the grid: its center, then its edges.
  final List<Color> table;

  /// App bar.
  final Color bar;

  /// The cells.
  final Color paper;

  /// The lines around the boxes of three by three, and between the cells.
  final Color boxLine;
  final Color cellLine;

  /// The digits of the puzzle, the player's digits and small numbers.
  final Color given;
  final Color entry;
  final Color note;

  /// The selected cell, the cells of its row, column and box, and the cells
  /// with its digit.
  final Color selected;
  final Color peer;
  final Color same;

  /// A digit that is twice in a row, column or box.
  final Color conflict;

  /// The keys of the keypad and their text.
  final Color key;
  final Color keyText;

  /// Id of the achievement that unlocks this theme, null when it is free.
  final String? unlockedBy;
}

/// Blue ink on white paper, on a night blue table.
const classicSudokuTheme = SudokuTheme(
  id: 'classic',
  table: [Color(0xFF2B3A55), Color(0xFF141C2B)],
  bar: Color(0xFF182235),
  paper: Color(0xFFF7F9FC),
  boxLine: Color(0xFF1F2A44),
  cellLine: Color(0xFFB8C2D6),
  given: Color(0xFF1B2333),
  entry: Color(0xFF2F5BD3),
  note: Color(0xFF5A6B8C),
  selected: Color(0xFFB4CDFB),
  peer: Color(0xFFE3EBF8),
  same: Color(0xFFCCDCF7),
  conflict: Color(0xFFD32F2F),
  key: Color(0xFF24324D),
  keyText: Color(0xFFFFFFFF),
);

const sudokuThemes = [
  classicSudokuTheme,
  // Sepia ink on cream paper.
  SudokuTheme(
    id: 'paper',
    table: [Color(0xFF5B4636), Color(0xFF2E2219)],
    bar: Color(0xFF3A2C20),
    paper: Color(0xFFFBF3E2),
    boxLine: Color(0xFF4A3526),
    cellLine: Color(0xFFD9C8A8),
    given: Color(0xFF2E2219),
    entry: Color(0xFF8A4B1F),
    note: Color(0xFF8C7660),
    selected: Color(0xFFF0D9A8),
    peer: Color(0xFFF5EAD2),
    same: Color(0xFFEBD3A0),
    conflict: Color(0xFFC0392B),
    key: Color(0xFF4A3526),
    keyText: Color(0xFFFBF3E2),
    unlockedBy: 'sudoku.firstWin',
  ),
  // Fresh greens.
  SudokuTheme(
    id: 'mint',
    table: [Color(0xFF1F5E50), Color(0xFF0D2E27)],
    bar: Color(0xFF123A31),
    paper: Color(0xFFF1FBF7),
    boxLine: Color(0xFF1B4D42),
    cellLine: Color(0xFFB3DCCF),
    given: Color(0xFF12332B),
    entry: Color(0xFF0F8A6C),
    note: Color(0xFF4F7D71),
    selected: Color(0xFFA8E6D2),
    peer: Color(0xFFDDF3EB),
    same: Color(0xFFC2EBDD),
    conflict: Color(0xFFD84343),
    key: Color(0xFF1B4D42),
    keyText: Color(0xFFFFFFFF),
    unlockedBy: 'sudoku.level4Win',
  ),
  // Light digits on a dark grid.
  SudokuTheme(
    id: 'night',
    table: [Color(0xFF1A1F3A), Color(0xFF07091A)],
    bar: Color(0xFF0E1230),
    paper: Color(0xFF161B33),
    boxLine: Color(0xFF7C8CFF),
    cellLine: Color(0xFF2E3660),
    given: Color(0xFFE6E9FF),
    entry: Color(0xFF7FD4FF),
    note: Color(0xFF8A93C0),
    selected: Color(0xFF34407A),
    peer: Color(0xFF1F2547),
    same: Color(0xFF2A3466),
    conflict: Color(0xFFFF6B6B),
    key: Color(0xFF262E5C),
    keyText: Color(0xFFE6E9FF),
    unlockedBy: 'sudoku.level8Win',
  ),
  // White and yellow chalk on a school board.
  SudokuTheme(
    id: 'chalk',
    table: [Color(0xFF2F4A3A), Color(0xFF16241C)],
    bar: Color(0xFF1C2E24),
    paper: Color(0xFF2E4637),
    boxLine: Color(0xFFF2F2E9),
    cellLine: Color(0xFF5F7A68),
    given: Color(0xFFF7F7EF),
    entry: Color(0xFFFFE08A),
    note: Color(0xFFB8C9BC),
    selected: Color(0xFF4C6B57),
    peer: Color(0xFF365243),
    same: Color(0xFF44614F),
    conflict: Color(0xFFFF8A80),
    key: Color(0xFF3B5847),
    keyText: Color(0xFFF7F7EF),
    unlockedBy: 'sudoku.noNotesWin',
  ),
  // Glowing lines in the dark.
  SudokuTheme(
    id: 'neon',
    table: [Color(0xFF1B0B2E), Color(0xFF07020F)],
    bar: Color(0xFF12061F),
    paper: Color(0xFF0F0A1A),
    boxLine: Color(0xFFFF2BD6),
    cellLine: Color(0xFF3A1F4F),
    given: Color(0xFFF4E9FF),
    entry: Color(0xFF39FFB8),
    note: Color(0xFFA98BC9),
    selected: Color(0xFF3B1856),
    peer: Color(0xFF1C1030),
    same: Color(0xFF2C1446),
    conflict: Color(0xFFFF4F6D),
    key: Color(0xFF2A1240),
    keyText: Color(0xFFF4E9FF),
    unlockedBy: 'sudoku.fastWin',
  ),
  // Cherry blossom pinks.
  SudokuTheme(
    id: 'sakura',
    table: [Color(0xFF6B3550), Color(0xFF331828)],
    bar: Color(0xFF4A2336),
    paper: Color(0xFFFFF5F8),
    boxLine: Color(0xFF8E3B5E),
    cellLine: Color(0xFFF0C9D7),
    given: Color(0xFF4A2336),
    entry: Color(0xFFD0467F),
    note: Color(0xFF9A6A80),
    selected: Color(0xFFFFC9DC),
    peer: Color(0xFFFDE6EE),
    same: Color(0xFFFBD3E2),
    conflict: Color(0xFFB71C1C),
    key: Color(0xFF7A3556),
    keyText: Color(0xFFFFFFFF),
    unlockedBy: 'sudoku.wins25',
  ),
  // Gold on black, for the hardest level.
  SudokuTheme(
    id: 'gold',
    table: [Color(0xFF2A2418), Color(0xFF0B0904)],
    bar: Color(0xFF15110A),
    paper: Color(0xFF14110B),
    boxLine: Color(0xFFD4AF37),
    cellLine: Color(0xFF4A3F26),
    given: Color(0xFFF3E3B5),
    entry: Color(0xFFFFC94D),
    note: Color(0xFFB59E68),
    selected: Color(0xFF4A3A14),
    peer: Color(0xFF221C10),
    same: Color(0xFF3A2F14),
    conflict: Color(0xFFFF6B5B),
    key: Color(0xFF2E2614),
    keyText: Color(0xFFF3D27A),
    unlockedBy: 'sudoku.level12Win',
  ),
];

/// The theme with [id], or [classicSudokuTheme] when there is none (for
/// example a theme saved by a newer app version).
SudokuTheme sudokuThemeById(String id) => sudokuThemes.firstWhere(
  (theme) => theme.id == id,
  orElse: () => classicSudokuTheme,
);

/// One box of a grid in [theme], [width] pixels wide: digits of the puzzle,
/// a digit of the player, small numbers, the selected cell and a clash.
class SudokuThemePreview extends StatelessWidget {
  const SudokuThemePreview({
    super.key,
    required this.theme,
    required this.width,
  });

  final SudokuTheme theme;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: width,
    child: CustomPaint(painter: _PreviewPainter(theme)),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.theme);

  final SudokuTheme theme;

  /// Puzzle digits (`5`), player digits (`+7`), a clash (`!5`), small
  /// numbers (`n`), the selected cell (`*`).
  static const _cells = ['5', '+7', 'n', '*+3', '9', '!5', '2', 'n', '+8'];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.paper);
    for (final (i, text) in _cells.indexed) {
      final rect = Rect.fromLTWH(i % 3 * cell, i ~/ 3 * cell, cell, cell);
      if (text.startsWith('*')) {
        canvas.drawRect(rect, Paint()..color = theme.selected);
      }
      if (text == 'n') {
        for (final digit in const [1, 4, 6]) {
          final small = Rect.fromLTWH(
            rect.left + (digit - 1) % 3 * cell / 3,
            rect.top + (digit - 1) ~/ 3 * cell / 3,
            cell / 3,
            cell / 3,
          );
          _digit(canvas, small, '$digit', theme.note, FontWeight.w500);
        }
        continue;
      }
      final digit = text.replaceAll(RegExp('[^0-9]'), '');
      final color = text.contains('!')
          ? theme.conflict
          : text.contains('+')
          ? theme.entry
          : theme.given;
      _digit(
        canvas,
        rect,
        digit,
        color,
        text.contains('+') ? FontWeight.w500 : FontWeight.w700,
      );
    }
    final thin = Paint()
      ..color = theme.cellLine
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), thin)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), thin);
    }
    canvas.drawRect(
      (Offset.zero & size).deflate(1),
      Paint()
        ..color = theme.boxLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  static void _digit(
    Canvas canvas,
    Rect rect,
    String digit,
    Color color,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: digit,
        style: TextStyle(
          color: color,
          fontSize: rect.height * 0.62,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter
      ..paint(
        canvas,
        rect.center - Offset(painter.width / 2, painter.height / 2),
      )
      ..dispose();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => oldDelegate.theme != theme;
}
