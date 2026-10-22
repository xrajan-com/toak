import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:ten_of_a_kind_poker/game/hand_evaluator.dart'
    show HandCategory;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart'
    show PlayingCard;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart'
    show GCard;
import 'package:ten_of_a_kind_poker/ui/widgets/card_sheet.dart';

/// The hand worth sharing from a game: a big pot won at showdown, or a bad
/// beat. Everything the share card shows, captured when the hand ended.
@immutable
class ShareMoment {
  final List<GCard> board;
  final List<GCard> heroHole;
  final List<GCard> opponentHole;
  final String opponentName;
  final bool heroWon;
  final int pot;
  final HandCategory heroHand;
  final HandCategory? opponentHand;

  const ShareMoment({
    required this.board,
    required this.heroHole,
    required this.opponentHole,
    required this.opponentName,
    required this.heroWon,
    required this.pot,
    required this.heroHand,
    required this.opponentHand,
  });

  /// Lost holding two pair or better: the hands people love to share.
  bool get badBeat =>
      !heroWon && heroHand.index >= HandCategory.twoPair.index;

  /// How share-worthy this hand is: pot size, with bad beats and strong
  /// winning hands counted up.
  double get score {
    final double strength = 1.0 + heroHand.index * 0.08;
    if (heroWon) return pot * strength;
    return badBeat ? pot * 1.3 * strength : pot * 0.4;
  }

  /// The headline on the card.
  String get headline {
    final String chips = NumberFormat.decimalPattern('en_IN').format(pot);
    if (heroWon) {
      return 'WON $chips CHIPS WITH ${handName(heroHand).toUpperCase()}';
    }
    final String theirs = opponentHand == null
        ? 'A BETTER HAND'
        : handName(opponentHand!).toUpperCase();
    return badBeat
        ? 'BAD BEAT: ${handName(heroHand).toUpperCase()} LOST TO $theirs'
        : 'LOST $chips CHIPS TO $theirs';
  }

  static String handName(HandCategory c) => switch (c) {
        HandCategory.highCard => 'High card',
        HandCategory.pair => 'One pair',
        HandCategory.twoPair => 'Two pair',
        HandCategory.threeKind => 'Three of a kind',
        HandCategory.straight => 'A straight',
        HandCategory.flush => 'A flush',
        HandCategory.fullHouse => 'A full house',
        HandCategory.fourKind => 'Four of a kind',
        HandCategory.straightFlush => 'A straight flush',
      };
}

/// Opens the share card for [moment]: a preview, with Save (to the phone's
/// photos) and Share, as a 1080 x 1350 image (Instagram's portrait size).
Future<void> showShareHandSheet(
  BuildContext context, {
  required ShareMoment moment,
  required String placeLine,
  String kingdomTitle = '',
}) {
  return showCardSheet(
    context,
    card: ShareHandCard(
      moment: moment,
      placeLine: placeLine,
      kingdomTitle: kingdomTitle,
    ),
    fileStem: moment.heroWon ? 'big-win' : 'hand',
    shareText: 'My hand at X Poker · tenofakind.com',
  );
}

/// The card itself, laid out at 360 x 450 (4:5).
class ShareHandCard extends StatelessWidget {
  const ShareHandCard({
    super.key,
    required this.moment,
    required this.placeLine,
    this.kingdomTitle = '',
  });

  final ShareMoment moment;
  final String placeLine;
  final String kingdomTitle;

  static const Color _red = Color(0xFFFF2800);
  static const Color _blue = Color(0xFF00B5C8);

  @override
  Widget build(BuildContext context) {
    final Color accent = moment.heroWon ? _blue : _red;
    return SizedBox(
      width: 360,
      height: 450,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0B0F), Color(0xFF14202A)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/x_poker_logo.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'X POKER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  if (moment.badBeat)
                    _Tag(text: 'BAD BEAT', color: _red)
                  else if (moment.heroWon)
                    _Tag(text: 'BIG WIN', color: _blue),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                placeLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (kingdomTitle.isNotEmpty)
                Text(
                  kingdomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD76E),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const Spacer(),
              _HandRow(label: 'YOU', cards: moment.heroHole),
              const SizedBox(height: 14),
              Center(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final c in moment.board) _card(c, 50),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _HandRow(
                label: moment.opponentName.toUpperCase(),
                cards: moment.opponentHole,
              ),
              const Spacer(),
              Text(
                moment.headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'tenofakind.com',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _card(GCard c, double w) =>
      PlayingCard(rank: c.rank, suit: c.suit, w: w, h: w * 1.4);
}

class _HandRow extends StatelessWidget {
  const _HandRow({required this.label, required this.cards});

  final String label;
  final List<GCard> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final c in cards) ...[
          const SizedBox(width: 6),
          ShareHandCard._card(c, 44),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
