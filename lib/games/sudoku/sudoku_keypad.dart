import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../skins/sudoku_themes.dart';
import 'sudoku_controller.dart';

/// The commands under or beside the grid: undo, redo, erase, the small
/// numbers switch (when the setting turns them on), then the digits 1 to 9:
/// in one row ([columns] 9) or in three rows of three ([columns] 3).
class SudokuKeypad extends StatelessWidget {
  const SudokuKeypad({
    super.key,
    required this.controller,
    required this.theme,
    required this.columns,
    required this.notesEnabled,
    required this.notesMode,
    required this.onNotesMode,
  });

  final SudokuController controller;
  final SudokuTheme theme;
  final int columns;
  final bool notesEnabled;

  /// The digits write small numbers.
  final bool notesMode;
  final ValueChanged<bool> onNotesMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final digitRows = [
          for (var row = 0; row < 9 ~/ columns; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < columns; column++)
                    Expanded(child: _digitKey(row * columns + column + 1)),
                ],
              ),
            ),
        ];
        return Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  _Tool(
                    id: 'undo',
                    icon: Icons.undo,
                    label: l10n.undo,
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  _Tool(
                    id: 'redo',
                    icon: Icons.redo,
                    label: l10n.redo,
                    onPressed: controller.canRedo ? controller.redo : null,
                  ),
                  _Tool(
                    id: 'erase',
                    icon: Icons.backspace_outlined,
                    label: l10n.sudokuErase,
                    onPressed: controller.canErase ? controller.erase : null,
                  ),
                  if (notesEnabled)
                    _Tool(
                      id: 'notes',
                      icon: Icons.edit_outlined,
                      label: l10n.sudokuNotes,
                      selected: notesMode,
                      selectedColor: theme.key,
                      onPressed: controller.isWon
                          ? null
                          : () => onNotesMode(!notesMode),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: Column(children: digitRows)),
          ],
        );
      },
    );
  }

  Widget _digitKey(int digit) {
    final writesNotes = notesEnabled && notesMode;
    // Nine of a digit fill the grid: one more would break a rule.
    final enabled = !controller.isWon && controller.state.countOf(digit) < 9;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: theme.key.withValues(alpha: enabled ? 1 : 0.45),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('digit-$digit'),
          onTap: enabled
              ? () => controller.enter(digit, note: writesNotes)
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide;
              final text = Text(
                '$digit',
                style: TextStyle(
                  color: theme.keyText.withValues(alpha: enabled ? 1 : 0.5),
                  fontSize: size * (writesNotes ? 0.32 : 0.55),
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              );
              // A small number sits where it goes in its cell.
              return writesNotes
                  ? Align(
                      alignment: Alignment(
                        (digit - 1) % 3 - 1.0,
                        (digit - 1) ~/ 3 - 1.0,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(size * 0.12),
                        child: text,
                      ),
                    )
                  : Center(child: text);
            },
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.selectedColor,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? Colors.white38 : Colors.white;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey(id),
            onTap: onPressed,
            child: Tooltip(
              message: label,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
