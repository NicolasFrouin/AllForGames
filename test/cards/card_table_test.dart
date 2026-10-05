import 'package:all_for_games/app.dart';
import 'package:all_for_games/cards/card_table.dart';
import 'package:all_for_games/cards/card_view.dart';
import 'package:all_for_games/cards/playing_card.dart';
import 'package:all_for_games/skins/card_backs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ace = PlayingCard(Suit.spades, 1, faceUp: true);
const _two = PlayingCard(Suit.spades, 2, faceUp: true);
const _cardWidth = 60.0;
const _origins = {'left': Offset(20, 20), 'right': Offset(200, 20)};

/// A tiny game on a [CardTable]: cards go from the left pile to the right
/// one, by drag or by tap. A tap on the right pile cannot move anything.
class TwoPiles extends StatefulWidget {
  const TwoPiles({super.key, required this.drops, this.onCelebrated});

  final List<(String, int, String)> drops;
  final VoidCallback? onCelebrated;

  @override
  State<TwoPiles> createState() => TwoPilesState();
}

class TwoPilesState extends State<TwoPiles> {
  var piles = {
    'left': [_ace, _two],
    'right': <PlayingCard>[],
  };
  var action = const TableAction<String>(0);

  void move(
    String from,
    int index,
    String to, {
    MotionStyle style = const MotionStyle(),
  }) {
    setState(() {
      final moving = piles[from]!.sublist(index);
      piles = {
        from: piles[from]!.sublist(0, index),
        to: [...piles[to]!, ...moving],
      };
      action = TableAction(
        action.serial + 1,
        cardIds: [for (final card in moving) card.id],
        style: style,
      );
    });
  }

  /// A new deal of the same cards, from the right pile, the ace first.
  void deal() {
    setState(() {
      action = TableAction(
        action.serial + 1,
        cardIds: [_ace.id, _two.id],
        style: const MotionStyle(stagger: 100, duration: 200),
        dealFrom: 'right',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CardTable<String>(
        size: const Size(400, 400),
        cardWidth: _cardWidth,
        cardBack: classicCardBack,
        piles: [
          for (final MapEntry(key: id, value: origin) in _origins.entries)
            TablePile(
              id: id,
              cards: piles[id]!,
              offsets: [
                for (var i = 0; i < piles[id]!.length; i++)
                  origin.translate(0, 30.0 * i),
              ],
              rect: origin & const Size(_cardWidth, _cardWidth * 1.4),
              slot: CardSlot(key: ValueKey(id), width: _cardWidth),
              dropRect: (origin & const Size(_cardWidth, _cardWidth * 1.4))
                  .inflate(10),
            ),
        ],
        action: action,
        canDrag: (pile, _) => pile == 'left',
        canTap: (_, _) => true,
        onTap: (pile, index) {
          if (pile != 'left') return false;
          move(pile, index, 'right');
          return true;
        },
        canDrop: (from, _, to) => from == 'left' && to == 'right',
        onDrop: (from, index, to) {
          widget.drops.add((from, index, to));
          move(from, index, to);
        },
        celebration: piles['left']!.isEmpty ? const ['right'] : null,
        onCelebrated: widget.onCelebrated,
      ),
    );
  }
}

Future<GlobalKey<TwoPilesState>> pumpTable(
  WidgetTester tester, {
  List<(String, int, String)>? drops,
  VoidCallback? onCelebrated,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey<TwoPilesState>();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(
        body: TwoPiles(
          key: key,
          drops: drops ?? [],
          onCelebrated: onCelebrated,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Offset at(WidgetTester tester, PlayingCard card) =>
    tester.getTopLeft(find.byKey(ValueKey(card.id)));

Offset slot(WidgetTester tester, String pile) =>
    tester.getTopLeft(find.byKey(ValueKey(pile)));

void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Drags [card] by its visible top strip and lets it go at [target].
Future<void> drag(WidgetTester tester, PlayingCard card, Offset target) async {
  final gesture = await tester.startGesture(
    at(tester, card) + const Offset(10, 6),
  );
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
}

void main() {
  testWidgets('a card dropped on a pile that takes it glides there', (
    tester,
  ) async {
    final drops = <(String, int, String)>[];
    await pumpTable(tester, drops: drops);

    await drag(tester, _two, tester.getCenter(find.byKey(const Key('right'))));
    await tester.pumpAndSettle();

    expect(drops, [('left', 1, 'right')]);
    expect(at(tester, _two), slot(tester, 'right'));
    expect(at(tester, _ace), slot(tester, 'left'));
  });

  testWidgets('a drop that the game refuses flies back to the pile', (
    tester,
  ) async {
    final drops = <(String, int, String)>[];
    await pumpTable(tester, drops: drops);
    final home = at(tester, _ace);

    // Both cards, where no pile takes them.
    await drag(tester, _ace, home + const Offset(30, 150));
    await tester.pump(const Duration(milliseconds: 60));
    expect(at(tester, _ace), isNot(home), reason: 'on its way back');

    await tester.pumpAndSettle();
    expect(at(tester, _ace), home);
    expect(at(tester, _two), home.translate(0, 30));
    expect(drops, isEmpty);
  });

  testWidgets('a tap that moves nothing shakes the card on the spot', (
    tester,
  ) async {
    final key = await pumpTable(tester);
    key.currentState!.move('left', 1, 'right');
    await tester.pumpAndSettle();
    final home = at(tester, _two);

    await tester.tap(find.byKey(ValueKey(_two.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(at(tester, _two).dx, isNot(home.dx));
    expect(at(tester, _two).dy, home.dy);

    await tester.pumpAndSettle();
    expect(at(tester, _two), home);
  });

  testWidgets('the cards of an action leave one after the other', (
    tester,
  ) async {
    final key = await pumpTable(tester);
    final right = slot(tester, 'right');
    final home = at(tester, _two);

    key.currentState!.move(
      'left',
      0,
      'right',
      style: const MotionStyle(stagger: 200, duration: 100),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(at(tester, _ace), right, reason: 'the first card has landed');
    expect(at(tester, _two), home, reason: 'the second one still waits');

    await tester.pumpAndSettle();
    expect(at(tester, _two), right.translate(0, 30));
  });

  testWidgets('with reduced motion, cards move at once', (tester) async {
    useReducedMotion(tester);
    final key = await pumpTable(tester);

    key.currentState!.move('left', 0, 'right');
    await tester.pump();

    expect(at(tester, _ace), slot(tester, 'right'));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a deal flies in face down and turns over on landing', (
    tester,
  ) async {
    final key = await pumpTable(tester);
    key.currentState!.deal();
    bool faceUp(PlayingCard card) => tester
        .widget<CardView>(
          find.descendant(
            of: find.byKey(ValueKey(card.id)),
            matching: find.byType(CardView),
          ),
        )
        .card
        .faceUp;

    await tester.pump();
    expect(at(tester, _two), slot(tester, 'right'));
    expect(faceUp(_two), isFalse);

    // Landed at 300 ms, it starts to turn: the old face shows until half time.
    await tester.pump(const Duration(milliseconds: 320));
    final landing = slot(tester, 'left').translate(0, 30);
    expect((at(tester, _two) - landing).distance, lessThan(1));
    expect(faceUp(_two), isFalse);

    await tester.pumpAndSettle();
    expect(faceUp(_ace), isTrue);
    expect(faceUp(_two), isTrue);
  });

  testWidgets('a win plays its celebration, then calls onCelebrated once', (
    tester,
  ) async {
    var celebrated = 0;
    await pumpTable(tester, onCelebrated: () => celebrated++);

    // On the strip that the 2 leaves visible: both cards go.
    await tester.tapAt(at(tester, _ace) + const Offset(10, 6));
    await tester.pump(const Duration(milliseconds: 600));
    expect(celebrated, 0, reason: 'the top card still hops');

    await tester.pumpAndSettle();
    expect(celebrated, 1);
    expect(at(tester, _two), slot(tester, 'right').translate(0, 30));
  });

  testWidgets('with reduced motion, a win calls onCelebrated at once', (
    tester,
  ) async {
    useReducedMotion(tester);
    var celebrated = 0;
    await pumpTable(tester, onCelebrated: () => celebrated++);

    // On the strip that the 2 leaves visible: both cards go.
    await tester.tapAt(at(tester, _ace) + const Offset(10, 6));
    await tester.pump();

    expect(celebrated, 1);
  });
}
