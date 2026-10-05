import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('every unlockedBy names an existing achievement', () {
    final achievementIds = {for (final a in achievements) a.id};
    for (final skin in cardBacks) {
      if (skin.unlockedBy case final id?) {
        expect(achievementIds, contains(id), reason: skin.id);
      }
    }
  });

  test('skin ids are unique', () {
    final ids = [for (final skin in cardBacks) skin.id];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('cardBackById finds a skin, or falls back to classic', () {
    expect(cardBackById('gold').id, 'gold');
    expect(cardBackById('unknown'), same(classicCardBack));
    expect(cardBackById(''), same(classicCardBack));
  });

  for (final width in [46.0, 120.0]) {
    testWidgets('every skin renders at ${width.round()} px wide', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (final skin in cardBacks)
                SizedBox(
                  width: width,
                  height: width * 1.4,
                  child: CardBackView(skin: skin, width: width),
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CardBackView), findsNWidgets(cardBacks.length));
    });
  }
}
