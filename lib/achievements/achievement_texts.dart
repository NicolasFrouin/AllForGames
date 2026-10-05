import '../l10n/app_localizations.dart';

// Ids are strings, so a switch cannot be checked for every id at compile
// time: a test checks that each achievement and card back has its texts.
// An id without texts shows the id itself.

String achievementTitle(String id, AppLocalizations l10n) => switch (id) {
  'klondike.firstWin' => l10n.achievementKlondikeFirstWinTitle,
  'klondike.wins10' => l10n.achievementKlondikeWins10Title,
  'klondike.wins50' => l10n.achievementKlondikeWins50Title,
  'klondike.draw3Win' => l10n.achievementKlondikeDraw3WinTitle,
  'klondike.fastWin' => l10n.achievementKlondikeFastWinTitle,
  'klondike.noUndoWin' => l10n.achievementKlondikeNoUndoWinTitle,
  'klondike.streak3' => l10n.achievementKlondikeStreak3Title,
  _ => id,
};

String achievementDescription(String id, AppLocalizations l10n) => switch (id) {
  'klondike.firstWin' => l10n.achievementKlondikeFirstWinDescription,
  'klondike.wins10' => l10n.achievementKlondikeWins10Description,
  'klondike.wins50' => l10n.achievementKlondikeWins50Description,
  'klondike.draw3Win' => l10n.achievementKlondikeDraw3WinDescription,
  'klondike.fastWin' => l10n.achievementKlondikeFastWinDescription,
  'klondike.noUndoWin' => l10n.achievementKlondikeNoUndoWinDescription,
  'klondike.streak3' => l10n.achievementKlondikeStreak3Description,
  _ => id,
};

String cardBackName(String id, AppLocalizations l10n) => switch (id) {
  'classic' => l10n.cardBackClassic,
  'crimson' => l10n.cardBackCrimson,
  'emerald' => l10n.cardBackEmerald,
  'ocean' => l10n.cardBackOcean,
  'sunset' => l10n.cardBackSunset,
  'midnight' => l10n.cardBackMidnight,
  'royal' => l10n.cardBackRoyal,
  'gold' => l10n.cardBackGold,
  _ => id,
};
