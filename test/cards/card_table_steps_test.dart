import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_table.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _two = PlayingCard(Suit.spades, 2, faceUp: true);
const _ace = PlayingCard(Suit.spades, 1, faceUp: true);
const _hidden = PlayingCard(Suit.hearts, 9);
const _cardWidth = 60.0;
const _step = Offset(0, 30);
const _origins = {
  'source': Offset(20, 20),
  'column': Offset(120, 20),
  'home': Offset(220, 20),
};

/// A table where the ace goes from the source onto the 2 of the column (its
/// stop), then both leave for home, the ace first, and the hidden card under
/// the 2 turns over last.
class Steps extends StatefulWidget {
  const Steps({super.key});

  @override
  State<Steps> createState() => StepsState();
}

class StepsState extends State<Steps> {
  var piles = {
    'source': [_ace],
    'column': [_hidden, _two],
    'home': <PlayingCard>[],
  };
  var action = const TableAction<String>(0);

  void play() {
    setState(() {
      piles = {
        'source': [],
        'column': [_hidden.turned(faceUp: true)],
        'home': [_ace, _two],
      };
      action = TableAction(
        1,
        cardIds: [_ace.id],
        style: const MotionStyle(duration: 100),
        stops: {
          _two.id: CardStop('column', 1, _origins['column']! + _step),
          _ace.id: CardStop('column', 2, _origins['column']! + _step * 2.0),
        },
        thenIds: [_ace.id, _two.id, _hidden.id],
        thenStyle: const MotionStyle(stagger: 200, duration: 100),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CardTable<String>(
        size: const Size(400, 300),
        cardWidth: _cardWidth,
        cardBack: classicCardBack,
        piles: [
          for (final id in ['home', 'column', 'source'])
            TablePile(
              id: id,
              cards: piles[id]!,
              offsets: [
                for (var i = 0; i < piles[id]!.length; i++)
                  id == 'home'
                      ? _origins[id]!
                      : _origins[id]! + _step * i.toDouble(),
              ],
              rect: _origins[id]! & const Size(_cardWidth, _cardWidth * 1.4),
              slot: CardSlot(key: ValueKey(id), width: _cardWidth),
            ),
        ],
        action: action,
      ),
    );
  }
}

void main() {
  testWidgets('a two-step action stops the cards, then moves them on one '
      'after the other', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<StepsState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: Steps(key: key)),
      ),
    );
    Offset at(PlayingCard card) =>
        tester.getTopLeft(find.byKey(ValueKey(card.id)));
    final column = at(_hidden);
    final home = tester.getTopLeft(find.byKey(const ValueKey('home')));

    /// The card ids in paint order, the top one last.
    List<String> paintOrder() => [
      for (final element
          in find
              .byWidgetPredicate(
                (widget) =>
                    widget is KeyedSubtree &&
                    widget.key is ValueKey<String> &&
                    widget.key != null,
              )
              .evaluate())
        ((element.widget as KeyedSubtree).key! as ValueKey<String>).value,
    ];

    key.currentState!.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(at(_ace), column + _step * 2.0, reason: 'on its stop');
    expect(at(_two), column + _step, reason: 'waits on the column');
    expect(paintOrder(), [
      _hidden.id,
      _two.id,
      _ace.id,
    ], reason: 'the ace stays above the 2 on the column');

    // The second step starts 80 ms after the first one landed (100 ms).
    await tester.pump(const Duration(milliseconds: 150));
    expect(at(_ace), home, reason: 'the ace left first');
    expect(at(_two), column + _step, reason: 'the 2 still waits');

    await tester.pump(const Duration(milliseconds: 200));
    expect(at(_two), home);

    await tester.pumpAndSettle();
    expect(at(_ace), home);
    expect(paintOrder(), [_ace.id, _two.id, _hidden.id]);
  });
}
