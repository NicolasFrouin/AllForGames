import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../skins/card_backs.dart';
import 'playing_card.dart';
import 'suit_icon.dart';

/// The rank printed in the card corner: `K` in English, `R` (Roi) in French.
String rankIndex(int rank, AppLocalizations l10n) => switch (rank) {
  1 => l10n.rankIndexAce,
  11 => l10n.rankIndexJack,
  12 => l10n.rankIndexQueen,
  13 => l10n.rankIndexKing,
  _ => '$rank',
};

/// The name of a face-up card for screen readers: `Ace of hearts`.
String cardName(PlayingCard card, AppLocalizations l10n) {
  final rank = switch (card.rank) {
    1 => l10n.rankAce,
    11 => l10n.rankJack,
    12 => l10n.rankQueen,
    13 => l10n.rankKing,
    final number => '$number',
  };
  final suit = switch (card.suit) {
    Suit.clubs => l10n.suitClubs,
    Suit.diamonds => l10n.suitDiamonds,
    Suit.hearts => l10n.suitHearts,
    Suit.spades => l10n.suitSpades,
  };
  return l10n.cardName(rank, suit);
}

class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    required this.width,
    required this.cardBack,
  });

  /// Narrower cards (ten columns on a phone) show a compact face: a bigger
  /// corner index that stays readable.
  static const compactWidth = 56.0;

  final PlayingCard card;
  final double width;

  /// The look of the card when it is face down.
  final CardBackSkin cardBack;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.1);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: card.faceUp ? cardName(card, l10n) : l10n.cardFaceDown,
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
          child: !card.faceUp
              ? CardBackView(skin: cardBack, width: width)
              : width < compactWidth
              ? _CompactFace(card: card, width: width)
              : _Face(card: card, width: width),
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
                    rankIndex(card.rank, AppLocalizations.of(context)),
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

/// The face of a narrow card: the corner index takes most of the width, so it
/// stays readable in the strip that a pile leaves visible.
class _CompactFace extends StatelessWidget {
  const _CompactFace({required this.card, required this.width});

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
              left: width * 0.05,
              top: width * 0.05,
              child: Row(
                children: [
                  Text(
                    rankIndex(card.rank, AppLocalizations.of(context)),
                    style: TextStyle(
                      color: card.suit.isRed ? SuitIcon.red : SuitIcon.black,
                      fontSize: width * 0.36,
                      fontWeight: FontWeight.w800,
                      // Keeps a 10 within the card.
                      letterSpacing: -width * 0.03,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: width * 0.02),
                  SuitIcon(card.suit, size: width * 0.26),
                ],
              ),
            ),
            Positioned(
              left: width * 0.2,
              bottom: width * 0.1,
              child: SuitIcon(card.suit, size: width * 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
