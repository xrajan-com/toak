import 'package:flutter/material.dart';

class AppColors {
  // Primary theme colors
  static const Color primary = Colors.deepPurple;
  // Brand palette, recorded in project.yaml (brand.colors) and enforced by
  // tools/verify_palette.sh. The app uses exactly two reds:
  //   red       Ferrari Red, the primary accent (energy).
  //   actionRed the action bar's danger buttons and the red kingdom pill,
  //             deliberately different from the primary.
  // Any other red in lib/ fails the release gate.
  static const Color red = Color(0xFFFF2800);
  static const Color actionRed = Color(0xFFC41230);
  static const Color blue = Color(0xFF20D9FF);
  static const Color background = Colors.black;
  static const Color green = Color(0xFF2EB872);
  static const Color orange = Color(0xFFFFA500);

  // Text and surface
  static const Color text = Colors.white;
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
  static const Color white54 = Colors.white54;
  static const Color white30 = Colors.white30;
  static const Color white24 = Colors.white24;
  static const Color white10 = Colors.white10;

  // Optional: background surfaces
  static const Color darkSurface = Color(0xFF1E1E1E);
}
