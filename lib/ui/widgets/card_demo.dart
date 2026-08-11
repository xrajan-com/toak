import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

class LightCardExample extends StatelessWidget {
  const LightCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    final card = PlayingCard(Suit.spades, CardValue.ace);

    // Build a style with custom pip colors and a custom back.
    final style = PlayingCardViewStyle(
      suitStyles: {
        Suit.spades: SuitStyle(
          // Scale the pip nicely within the slot
          builder: (context) => const FittedBox(
            fit: BoxFit.fitHeight,
            child: Text('♠',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        Suit.clubs: SuitStyle(
          builder: (context) => const FittedBox(
            fit: BoxFit.fitHeight,
            child: Text('♣',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
        Suit.hearts: SuitStyle(
          builder: (context) => const FittedBox(
            fit: BoxFit.fitHeight,
            child: Text('♥',
                style: TextStyle(
                    color: Color(0xFFFF2800), fontWeight: FontWeight.w600)),
          ),
        ),
        Suit.diamonds: SuitStyle(
          builder: (context) => const FittedBox(
            fit: BoxFit.fitHeight,
            child: Text('♦',
                style: TextStyle(
                    color: Color(0xFF24B6FF), fontWeight: FontWeight.w600)),
          ),
        ),
        // Optional, in case a joker is ever created:
        Suit.joker: SuitStyle(),
      },
      cardBackContentBuilder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFF2800),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Center(
          child: Text('TOAK',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayingCardView(card: card, showBack: false, style: style),
            const SizedBox(width: 32),
            PlayingCardView(card: card, showBack: true, style: style),
          ],
        ),
      ),
    );
  }
}
