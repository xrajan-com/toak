import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class PokerCard extends StatelessWidget {
  final String cardSymbol; // e.g., '🂡', '🂪', '🂫', '🂠' (back)
  final double width;
  final double height;
  final bool faceUp;

  const PokerCard({
    super.key,
    required this.cardSymbol,
    this.width = 45,
    this.height = 70,
    this.faceUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: faceUp ? AppColors.white : Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        faceUp ? cardSymbol : '🂠',
        style: TextStyle(
          fontSize: width * 0.6,
          color: faceUp ? AppColors.black : AppColors.white,
        ),
      ),
    );
  }
}
