import 'package:material_ui/material_ui.dart';

import 'playing_card.dart';
import 'suit_icon.dart';

class CardView extends StatelessWidget {
  const CardView({super.key, required this.card, required this.width});

  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.1);
    return Semantics(
      label: card.faceUp ? card.name : 'Face-down card',
      child: Container(
        width: width,
        height: width * 1.4,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: card.faceUp
              ? _Face(card: card, width: width)
              : _Back(width: width),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.card, required this.width});

  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFDFBF7),
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              left: width * 0.07,
              top: width * 0.06,
              child: Row(
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      color: card.suit.isRed ? SuitIcon.red : SuitIcon.black,
                      fontSize: width * 0.26,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: width * 0.03),
                  SuitIcon(card.suit, size: width * 0.2),
                ],
              ),
            ),
            Positioned(
              right: width * 0.08,
              bottom: width * 0.08,
              child: SuitIcon(card.suit, size: width * 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF283593), Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.07),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x66FFFFFF), width: 1),
            borderRadius: BorderRadius.circular(width * 0.06),
          ),
          child: Center(
            child: Icon(
              Icons.diamond_outlined,
              color: const Color(0x55FFFFFF),
              size: width * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
