import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Ten columns on a 360 px phone leave cards about 32 px wide, of which a
  // pile shows only a strip at the top.
  testWidgets('a narrow card shows an index readable in its top strip', (
    tester,
  ) async {
    const width = 32.0;
    for (final suit in [Suit.hearts, Suit.clubs]) {
      for (var rank = 1; rank <= 13; rank++) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            home: Center(
              child: CardView(
                card: PlayingCard(suit, rank, faceUp: true),
                width: width,
                cardBack: classicCardBack,
              ),
            ),
          ),
        );
        final card = tester.getRect(find.byType(CardView));
        final rankText = tester.widget<Text>(
          find.descendant(
            of: find.byType(CardView),
            matching: find.byType(Text),
          ),
        );
        final index = tester.getRect(
          find.descendant(
            of: find.byType(CardView),
            matching: find.byType(Row),
          ),
        );
        final name = PlayingCard(suit, rank).toString();
        expect(
          rankText.style!.fontSize,
          greaterThanOrEqualTo(11),
          reason: name,
        );
        expect(index.right, lessThanOrEqualTo(card.right), reason: name);
        expect(index.bottom - card.top, lessThan(width * 0.45), reason: name);
      }
    }
  });
}
