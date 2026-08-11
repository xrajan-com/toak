import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/poker_card.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/player_avatar.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final List<String> communityCards = [
    '🂠',
    '🂠',
    '🂠',
    '🂠',
    '🂠'
  ]; // Placeholder cards
  int pot = 1200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            /// Pot Display
            Text(
              'POT: $pot chips',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            /// Community Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: communityCards.map((card) {
                return PokerCard(cardSymbol: card);
              }).toList(),
            ),

            const SizedBox(height: 30),

            /// Dealer Avatar
            const Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/images/renoir_tux.png'),
                  backgroundColor: Colors.white10,
                ),
                SizedBox(height: 8),
                Text(
                  'Dealer: Renoir',
                  style: TextStyle(color: AppColors.white70),
                ),
              ],
            ),

            const Spacer(),

            /// Player Avatars Row
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return const PlayerAvatar(
                    username: 'Player',
                    chips: 1500,
                    isYou: false,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            /// Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _actionButton('Fold', AppColors.red, () {
                    debugPrint('Player folds');
                  }),
                  _actionButton('Check', AppColors.blue, () {
                    debugPrint('Player checks');
                  }),
                  _actionButton('Raise', AppColors.blue, () {
                    debugPrint('Player raises');
                  }),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
