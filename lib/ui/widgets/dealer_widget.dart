import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class DealerWidget extends StatelessWidget {
  final String? speech; // Optional speech bubble text
  final double size;

  const DealerWidget({
    super.key,
    this.speech,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Dealer Avatar
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.white10,
          backgroundImage: const AssetImage('assets/images/renoir_avatar.png'),
        ),
        const SizedBox(height: 8),

        /// Label
        const Text(
          'Dealer: Renoir',
          style: TextStyle(
            color: AppColors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        /// Optional Speech Bubble
        if (speech != null && speech!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: AppColors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.white30),
            ),
            child: Text(
              speech!,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}