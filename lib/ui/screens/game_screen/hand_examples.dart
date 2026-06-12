// lib/ui/screens/game_screen/hand_examples.dart
import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart' as pc;

import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'; // GCard

class HandExamplesSheet extends StatelessWidget {
  const HandExamplesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: const [
          _HandExamplesSheetHeader(),
          SizedBox(height: 12),
          _HandExamplesTabBar(),
          SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: HandExamples(),
                ),
                HandTips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandExamplesSheetHeader extends StatelessWidget {
  const _HandExamplesSheetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 42,
          child: Divider(
            thickness: 4,
            color: Colors.white24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Hand Examples',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Best hands first. Tap TIPS for actions, rules, and quick strategy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _HandExamplesTabBar extends StatelessWidget {
  const _HandExamplesTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(text: 'HANDS'),
          Tab(text: 'TIPS'),
        ],
      ),
    );
  }
}

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
                          child: _ExampleFaceCard(
                              card: cards[i], w: cardW, h: cardH),
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
          mainAxisSize: MainAxisSize.min,
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

class HandTips extends StatelessWidget {
  const HandTips({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double scale = (maxW / 420).clamp(0.90, 1.15);
        final double titleSize = (15.0 * scale).clamp(13.0, 18.0);
        final double bodySize = (12.5 * scale).clamp(11.0, 15.0);

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            _TipsSection(
              title: 'Action Bar',
              titleSize: titleSize,
              bodySize: bodySize,
              items: const [
                (
                  label: 'Check / Call',
                  body:
                      'Check if no chips are needed. Call when you need to match the current bet to stay in.'
                ),
                (
                  label: 'Raise',
                  body:
                      'Put in more chips than the current bet and apply pressure.'
                ),
                (
                  label: 'All-In',
                  body:
                      'Commit every chip you have left. You cannot bet more after that.'
                ),
                (
                  label: 'Fold / Skip',
                  body:
                      'Fold gives up the hand. Skip fast-forwards when there is nothing useful to do.'
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TipsSection(
              title: 'Basic Rules',
              titleSize: titleSize,
              bodySize: bodySize,
              items: const [
                (
                  label: 'Best 5 Cards',
                  body:
                      'Use the best 5-card hand from any mix of your 2 hole cards and the 5 community cards.'
                ),
                (
                  label: 'Betting Streets',
                  body: 'The hand moves through preflop, flop, turn, and river.'
                ),
                (
                  label: 'How You Win',
                  body:
                      'Win at showdown with the best hand, or make everyone else fold before showdown.'
                ),
                (
                  label: 'Blinds',
                  body:
                      'Small blind and big blind seed the pot before the cards are dealt.'
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TipsSection(
              title: 'Quick Tips',
              titleSize: titleSize,
              bodySize: bodySize,
              items: const [
                (
                  label: 'Start Strong',
                  body:
                      'Play better starting hands more often. Weak hands cost chips over time.'
                ),
                (
                  label: 'Respect Position',
                  body:
                      'Acting later is stronger because you get more information before deciding.'
                ),
                (
                  label: 'Do Not Drift',
                  body:
                      'If the bet is large and your hand is weak, folding is usually better than curiosity-calling.'
                ),
                (
                  label: 'Pressure Short Stacks',
                  body:
                      'Short stacks cannot defend forever. Good raises force tough decisions.'
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

typedef _TipItem = ({String label, String body});

class _TipsSection extends StatelessWidget {
  const _TipsSection({
    required this.title,
    required this.titleSize,
    required this.bodySize,
    required this.items,
  });

  final String title;
  final double titleSize;
  final double bodySize;
  final List<_TipItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: titleSize,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < items.length; i++) ...[
            _TipLine(
              label: items[i].label,
              body: items[i].body,
              bodySize: bodySize,
            ),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({
    required this.label,
    required this.body,
    required this.bodySize,
  });

  final String label;
  final String body;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: bodySize,
            ),
          ),
          TextSpan(
            text: body,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: bodySize,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleFaceCard extends StatelessWidget {
  final GCard card;
  final double w;
  final double h;

  const _ExampleFaceCard({
    required this.card,
    required this.w,
    required this.h,
  });

  pc.Suit? _toSuit(String suit) {
    switch (suit.toUpperCase()) {
      case 'S':
      case '♠':
        return pc.Suit.spades;
      case 'H':
      case '♥':
        return pc.Suit.hearts;
      case 'D':
      case '♦':
        return pc.Suit.diamonds;
      case 'C':
      case '♣':
        return pc.Suit.clubs;
    }
    return null;
  }

  pc.CardValue? _toValue(String rank) {
    switch (rank.toUpperCase()) {
      case 'A':
        return pc.CardValue.ace;
      case 'K':
        return pc.CardValue.king;
      case 'Q':
        return pc.CardValue.queen;
      case 'J':
        return pc.CardValue.jack;
      case '10':
        return pc.CardValue.ten;
      case '9':
        return pc.CardValue.nine;
      case '8':
        return pc.CardValue.eight;
      case '7':
        return pc.CardValue.seven;
      case '6':
        return pc.CardValue.six;
      case '5':
        return pc.CardValue.five;
      case '4':
        return pc.CardValue.four;
      case '3':
        return pc.CardValue.three;
      case '2':
        return pc.CardValue.two;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pc.Suit? suit = _toSuit(card.suit);
    final pc.CardValue? value = _toValue(card.rank);
    if (suit == null || value == null) {
      return SizedBox(width: w, height: h);
    }

    final ShapeBorder shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular((w < h ? w : h) * 0.30),
    );

    return SizedBox(
      width: w,
      height: h,
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: Transform.scale(
              scale: 0.95,
              child: SizedBox(
                width: w,
                height: h,
                child: pc.PlayingCardView(
                  card: pc.PlayingCard(suit, value),
                  showBack: false,
                  shape: shape,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
