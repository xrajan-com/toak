import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class PlayerAvatar extends StatelessWidget {
  final String username;
  final int chips;
  final bool isYou;
  final bool isTurn;
  final String? imagePath;

  const PlayerAvatar({
    super.key,
    required this.username,
    required this.chips,
    this.isYou = false,
    this.isTurn = false,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final String displayInitial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isTurn ? AppColors.blue : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: isYou ? AppColors.red : AppColors.white,
            backgroundImage: imagePath != null ? AssetImage(imagePath!) : null,
            child: imagePath == null
                ? Text(
                    displayInitial,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isYou ? AppColors.white : AppColors.black,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),

        // Username
        SizedBox(
          width: 60,
          child: Text(
            isYou ? '$username (You)' : username,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.white,
            ),
          ),
        ),

        // Tournament chips are play-only and are deliberately not presented
        // with a real-world currency symbol.
        Semantics(
          label: '$chips chips',
          child: Text(
            '$chips chips',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
