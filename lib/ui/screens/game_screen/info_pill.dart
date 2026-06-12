import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.child,
    this.minWidth = 200,
    this.maxWidth = 320,
    this.backgroundColor,
    this.borderColor,
    this.glowColor,
    this.glowStrength = 1.0,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? glowColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withOpacity(0.08);
    final bc = borderColor ?? Colors.white70;
    final gc = glowColor;
    final double strength = glowStrength.clamp(0.0, 1.0);
    final List<BoxShadow>? shadows = gc == null
        ? null
        : <BoxShadow>[
            BoxShadow(
              color: gc.withValues(alpha: 0.28 + 0.55 * strength),
              blurRadius: 14 + 12 * strength,
              spreadRadius: 0.6 + 1.6 * strength,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.10 + 0.22 * strength),
              blurRadius: 8 + 10 * strength,
              spreadRadius: 0.4 + 0.9 * strength,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: gc.withValues(alpha: 0.18 + 0.35 * strength),
              blurRadius: 24 + 18 * strength,
              spreadRadius: 2 + 6 * strength,
              offset: Offset.zero,
            ),
          ];
    return Container(
      // Extra horizontal padding so text/odometers don’t hug the pill edges.
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: bc, width: 1)),
        color: bg,
        shadows: shadows,
      ),
      child: child,
    );
  }
}

class WinnerPillPalette {
  final Color background;
  final Color border;
  final Color glow;
  final Color foreground;
  const WinnerPillPalette({
    required this.background,
    required this.border,
    required this.glow,
    required this.foreground,
  });
}

WinnerPillPalette winnerPillPalette({
  required bool isHero,
  required double blinkStrength,
}) {
  final Color base = isHero ? AppColors.blue : AppColors.red;
  final Color fg = isHero ? Colors.black : Colors.white;
  final double t = blinkStrength.clamp(0.0, 1.0);
  final Color background = Color.lerp(
    base.withValues(alpha: 0.28),
    base.withValues(alpha: 0.60),
    t,
  )!;
  final Color border = Color.lerp(
    base.withValues(alpha: 0.55),
    base.withValues(alpha: 0.98),
    t,
  )!;
  return WinnerPillPalette(
    background: background,
    border: border,
    glow: base,
    foreground: fg,
  );
}
