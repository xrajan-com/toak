import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class ChipStack extends StatelessWidget {
  final int chipAmount; // e.g., 1200
  final bool showAmount;
  final double size; // Base chip diameter

  const ChipStack({
    super.key,
    required this.chipAmount,
    this.showAmount = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final chipCount = (chipAmount / 100).clamp(1, 6).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// Stack of Chips
        SizedBox(
          width: size + 8,
          height: size + (chipCount * 6),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: List.generate(chipCount, (i) {
              return Positioned(
                bottom: i * 6,
                child: _buildChip(i),
              );
            }),
          ),
        ),

        /// ₹ Value Label
        if (showAmount)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '₹$chipAmount',
              style: const TextStyle(
                color: AppColors.white70,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChip(int index) {
    final colors = [AppColors.red, AppColors.blue, AppColors.white];
    final chipColor = colors[index % colors.length];

    return Container(
      width: size,
      height: size / 2,
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.black, width: 1),
      ),
    );
  }
}