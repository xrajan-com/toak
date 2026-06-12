import 'package:flutter/material.dart';

class StadiumBanner extends StatelessWidget {
  final String asset;
  final double maxWidth;
  final double maxHeight;

  const StadiumBanner({
    super.key,
    required this.asset,
    this.maxWidth = 420,
    this.maxHeight = 88,
  });

  static const StadiumBorder _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: _shape),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            alignment: Alignment.center,
            child: Image.asset(
              asset,
              isAntiAlias: true,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
