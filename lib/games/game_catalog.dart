import 'package:material_ui/material_ui.dart';

import 'klondike/klondike_controller.dart';

class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    this.route,
    this.variants = const {},
    this.detailLabels = const {},
  });

  final String id;
  final String title;
  final String tagline;
  final IconData icon;
  final Color color;

  /// Null while the game is not available yet.
  final String? route;

  /// Variant id (as saved in records) to display name.
  final Map<String, String> variants;

  /// Labels of the game-specific counters in `GameRecord.details`.
  final Map<String, String> detailLabels;

  bool get isAvailable => route != null;
}

const gameCatalog = [
  GameInfo(
    id: KlondikeController.gameId,
    title: 'Klondike',
    tagline: 'The classic solitaire. Build the four suits from Ace to King.',
    icon: Icons.style,
    color: Color(0xFF2E7D32),
    route: '/klondike',
    variants: {'draw1': 'Draw 1', 'draw3': 'Draw 3'},
    detailLabels: KlondikeStatKeys.labels,
  ),
  GameInfo(
    id: 'freecell',
    title: 'FreeCell',
    tagline: 'Every card is visible. Use the four free cells well.',
    icon: Icons.view_column,
    color: Color(0xFF1565C0),
  ),
  GameInfo(
    id: 'spider',
    title: 'Spider',
    tagline: 'Build full suits in eight piles.',
    icon: Icons.layers,
    color: Color(0xFF6A1B9A),
  ),
  GameInfo(
    id: 'mahjong',
    title: 'Mahjong',
    tagline: 'Match free tiles in pairs to clear the board.',
    icon: Icons.grid_view,
    color: Color(0xFFC62828),
  ),
];

GameInfo? gameById(String id) {
  for (final game in gameCatalog) {
    if (game.id == id) return game;
  }
  return null;
}
