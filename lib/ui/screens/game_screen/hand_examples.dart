// lib/ui/screens/game_screen/hand_examples.dart
import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'; // GCard
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart'
    show FaceCard;

class HandExamples extends StatelessWidget {
  const HandExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double scale = (maxW / 420).clamp(0.85, 1.6);
        final double labelWidth = (140 * scale).clamp(110, 220);
        final double fontSize = (12.5 * scale).clamp(11.0, 16.0);
        final double cardW = (46.0 * scale).clamp(38.0, 76.0);
        final double cardH = cardW * (64.0 / 46.0);

        Widget row(String label, List<GCard> cards) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        cards.length,
                        (i) => Padding(
                          padding: EdgeInsets.only(
                              right: i == cards.length - 1 ? 0 : 6),
                          child: FaceCard(
                            cards[i],
                            w: cardW,
                            h: cardH,
                            zoom:
                                0.95, // slight inset to prevent any edge clipping
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Royal / Straight Flush', [
              GCard('10', '♠'),
              GCard('J', '♠'),
              GCard('Q', '♠'),
              GCard('K', '♠'),
              GCard('A', '♠')
            ]),
            const SizedBox(height: 2),
            row('Four of a Kind', [
              GCard('Q', '♣'),
              GCard('Q', '♦'),
              GCard('Q', '♥'),
              GCard('Q', '♠'),
              GCard('7', '♣')
            ]),
            const SizedBox(height: 2),
            row('Full House', [
              GCard('10', '♠'),
              GCard('10', '♥'),
              GCard('10', '♦'),
              GCard('7', '♠'),
              GCard('7', '♥')
            ]),
            const SizedBox(height: 2),
            row('Flush', [
              GCard('A', '♥'),
              GCard('9', '♥'),
              GCard('7', '♥'),
              GCard('4', '♥'),
              GCard('2', '♥')
            ]),
            const SizedBox(height: 2),
            row('Straight', [
              GCard('5', '♣'),
              GCard('6', '♦'),
              GCard('7', '♠'),
              GCard('8', '♥'),
              GCard('9', '♣')
            ]),
            const SizedBox(height: 2),
            row('Three of a Kind', [
              GCard('8', '♠'),
              GCard('8', '♥'),
              GCard('8', '♦'),
              GCard('K', '♣'),
              GCard('2', '♦')
            ]),
            const SizedBox(height: 2),
            row('Two Pair', [
              GCard('J', '♠'),
              GCard('J', '♦'),
              GCard('3', '♣'),
              GCard('3', '♥'),
              GCard('A', '♦')
            ]),
            const SizedBox(height: 2),
            row('One Pair', [
              GCard('A', '♠'),
              GCard('A', '♦'),
              GCard('9', '♣'),
              GCard('5', '♥'),
              GCard('2', '♠')
            ]),
            const SizedBox(height: 2),
            row('High Card', [
              GCard('A', '♣'),
              GCard('9', '♦'),
              GCard('7', '♠'),
              GCard('4', '♥'),
              GCard('2', '♦')
            ]),
          ],
        );
      },
    );
  }
}
