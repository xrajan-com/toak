import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class AuthorFlashOverlay extends StatelessWidget {
  const AuthorFlashOverlay({super.key});

  static const String _renoirAsset = 'assets/images/renoir_tux.png';

  static const String _bodyText =
      'The author would like to stay anonymous. You can reach out through the Instagram page "x_of_a_kind".';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale content down on short view heights to avoid pixel overflow.
            double clampDouble(double v, double min, double max) =>
                v.clamp(min, max).toDouble();
            final double h = constraints.maxHeight;
            final double scale = clampDouble(h / 640, 0.72, 1.0);
            final double imageW =
                clampDouble(190 * scale, 120, constraints.maxWidth * 0.32);
            final double titleSize = 26 * clampDouble(scale, 0.82, 1.0);
            final double bodySize = 15.5 * clampDouble(scale, 0.82, 1.0);
            final double spinner = 42 * clampDouble(scale, 0.75, 1.0);

            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: clampDouble(constraints.maxWidth * 0.9, 520, 820),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About the Author',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: titleSize,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 10 * scale),
                            Text(
                              _bodyText,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: bodySize,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            SizedBox(
                              width: spinner,
                              height: spinner,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3.2,
                                color: AppColors.blue,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 18 * scale),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            _renoirAsset,
                            width: imageW,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
