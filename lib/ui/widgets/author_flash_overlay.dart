import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class AuthorFlashOverlay extends StatelessWidget {
  const AuthorFlashOverlay({super.key});

  static const String _renoirAsset = 'assets/images/renoir_tux.png';

  static const String _bodyText =
      'The author would like to stay anonymous. However, you can reach out to him @ +91 953 7654321 or Instagram page "x_of_a_kind".';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _renoirAsset,
                    width: 190,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'About the Author',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    _bodyText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      color: AppColors.blue,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

