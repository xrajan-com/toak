import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ten_of_a_kind_poker/app/startup/auth_gate.dart';
import 'package:ten_of_a_kind_poker/config/card_backs.dart';

class DisclaimerSplash extends StatefulWidget {
  const DisclaimerSplash({super.key});

  @override
  State<DisclaimerSplash> createState() => _DisclaimerSplashState();
}

class _DisclaimerSplashState extends State<DisclaimerSplash>
    with SingleTickerProviderStateMixin {
  static const _paragraphs = [
    'Ten of a Kind is just a passion project of a former poker player (prefer to stay anonymous). It is built for fun and learning - not as a gambling product.',
    'This game is free to play. There are no cash deposits, no cash-outs, and no rewards with real-world value. Treat it as a mental gym: practice patience, attention, probability, and decision-making under uncertainty.',
    'Leave your valuable feedback here:- +91 953 7654321.',
    'Poker theory is about making the best decision with imperfect information. Instead of "Did I win this hand?", focus on whether your choices are profitable over time. Position, pot odds, equity, and ranges matter more than any single result.',
    'Game theory shows up everywhere in poker: balancing bluffs and value, mixing strategies, and staying unpredictable while still being fundamentally sound. Even a light exposure to expected value can sharpen how you think about risk, incentives, and discipline.',
    'In India, real-money gambling and many "real-money gaming" operations are tightly regulated, and some jurisdictions restrict or ban them due to consumer harm, addiction risk, and fraud. This app intentionally avoids real-money wagering - please follow your local laws, steer clear of illegal offerings, and report suspicious operations through the appropriate channels.',
  ];

  static const _bannerAsset = 'assets/images/banner.png';
  static const _appIconAsset = 'assets/images/app_icon.png';
  static const _flags = [
    'assets/images/flags/baroda.png',
    'assets/images/flags/hyderabad.png',
    'assets/images/flags/indore.png',
    'assets/images/flags/jaipur.png',
    'assets/images/flags/maratha_empire.png',
    'assets/images/flags/mysore.png',
    'assets/images/flags/new_delhi.png',
    'assets/images/flags/sikh_empire.png',
    'assets/images/flags/sikkim.png',
    'assets/images/flags/travancore.png',
    'assets/images/flags/africa.png',
    'assets/images/flags/amazon.png',
    'assets/images/flags/america.png',
    'assets/images/flags/arabia.png',
    'assets/images/flags/australia.png',
    'assets/images/flags/china.png',
    'assets/images/flags/europe.png',
    'assets/images/flags/india.png',
    'assets/images/flags/russia.png',
    'assets/images/flags/asean.png',
  ];

  Timer? _navTimer;
  bool _navigated = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _warmAssets();
    _navTimer = Timer(const Duration(seconds: 6), _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _warmAssets() async {
    try {
      final ctx = context;
      precacheImage(const AssetImage(_bannerAsset), ctx);
      precacheImage(const AssetImage(_appIconAsset), ctx);
      for (final asset in _flags) {
        precacheImage(AssetImage(asset), ctx);
      }
      for (final asset in kCardBackAssets) {
        precacheImage(AssetImage(asset), ctx);
      }
    } catch (_) {
      // Ignore warmup failures. Startup should still continue.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'DISCLAIMER',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFF2800),
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (_, __) {
                      final t = _glow.value;
                      return ShaderMask(
                        shaderCallback: (Rect bounds) {
                          final width = bounds.width;
                          final glowWidth = width * 0.35;
                          final shift =
                              (t * (width + glowWidth * 2)) - glowWidth;
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Colors.white24,
                              Colors.white,
                              Colors.white24,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            transform: _TranslateGradient(Offset(shift, 0)),
                          ).createShader(
                            Rect.fromLTWH(
                              -glowWidth,
                              0,
                              width + glowWidth * 2,
                              bounds.height,
                            ),
                          );
                        },
                        blendMode: BlendMode.srcATop,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth =
                                math.min(constraints.maxWidth, 560.0);
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: maxWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    for (final paragraph in _paragraphs)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          paragraph,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Recreational / Educational Only',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslateGradient extends GradientTransform {
  const _TranslateGradient(this.offset);

  final Offset offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset.dx, offset.dy, 0.0);
  }
}
