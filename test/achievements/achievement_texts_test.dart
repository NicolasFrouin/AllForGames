import 'package:all_for_games/achievements/achievement_texts.dart';
import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/l10n/app_localizations.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:all_for_games/skins/minesweeper_themes.dart';
import 'package:all_for_games/skins/tile_styles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not empty, and not the id that an id without texts shows.
Matcher isTextOf(String id) => isNot(anyOf(isEmpty, id));

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final language = locale.languageCode;
    final l10n = lookupAppLocalizations(locale);

    test('every achievement has a title and a description in $language', () {
      for (final Achievement(:id) in achievements) {
        expect(achievementTitle(id, l10n), isTextOf(id), reason: id);
        expect(achievementDescription(id, l10n), isTextOf(id), reason: id);
      }
    });

    test('every card back has a name in $language', () {
      for (final CardBackSkin(:id) in cardBacks) {
        expect(cardBackName(id, l10n), isTextOf(id), reason: id);
      }
    });

    test('every tile style has a name in $language', () {
      for (final TileStyle(:id) in tileStyles) {
        expect(tileStyleName(id, l10n), isTextOf(id), reason: id);
      }
    });

    test('every Minesweeper theme has a name in $language', () {
      for (final MinesweeperTheme(:id) in minesweeperThemes) {
        expect(minesweeperThemeName(id, l10n), isTextOf(id), reason: id);
      }
    });
  }
}
