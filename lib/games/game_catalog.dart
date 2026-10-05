import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'klondike/klondike_controller.dart';
import 'klondike/klondike_difficulty.dart';
import 'klondike/klondike_difficulty_texts.dart';

/// A text in the language of the app.
typedef LocalizedText = String Function(AppLocalizations l10n);

class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    this.route,
    this.variants = const {},
    this.difficulties = const {},
    this.detailLabels = const {},
  });

  final String id;
  final LocalizedText title;
  final LocalizedText tagline;
  final IconData icon;
  final Color color;

  /// Null while the game is not available yet.
  final String? route;

  /// Variant id (as saved in records) to display name.
  final Map<String, LocalizedText> variants;

  /// Difficulty (as saved in `GameRecord.difficulty`) to display name, from
  /// the easiest.
  final Map<String, LocalizedText> difficulties;

  /// Labels of the game-specific counters in `GameRecord.details`.
  final Map<String, LocalizedText> detailLabels;

  bool get isAvailable => route != null;
}

final gameCatalog = [
  GameInfo(
    id: KlondikeController.gameId,
    title: (l10n) => l10n.klondikeTitle,
    tagline: (l10n) => l10n.klondikeTagline,
    icon: Icons.style,
    color: const Color(0xFF2E7D32),
    route: '/klondike',
    variants: {
      'draw1': (l10n) => l10n.klondikeDraw(1),
      'draw3': (l10n) => l10n.klondikeDraw(3),
    },
    difficulties: {
      for (final difficulty in KlondikeDifficulty.values)
        difficulty.name: difficulty.label,
    },
    detailLabels: KlondikeStatKeys.labels,
  ),
  GameInfo(
    id: 'freecell',
    title: (l10n) => l10n.freecellTitle,
    tagline: (l10n) => l10n.freecellTagline,
    icon: Icons.view_column,
    color: const Color(0xFF1565C0),
  ),
  GameInfo(
    id: 'spider',
    title: (l10n) => l10n.spiderTitle,
    tagline: (l10n) => l10n.spiderTagline,
    icon: Icons.layers,
    color: const Color(0xFF6A1B9A),
  ),
  GameInfo(
    id: 'mahjong',
    title: (l10n) => l10n.mahjongTitle,
    tagline: (l10n) => l10n.mahjongTagline,
    icon: Icons.grid_view,
    color: const Color(0xFFC62828),
  ),
];

GameInfo? gameById(String id) {
  for (final game in gameCatalog) {
    if (game.id == id) return game;
  }
  return null;
}
