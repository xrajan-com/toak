// lib/ui/screens/splash_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ for SystemChrome + rootBundle
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen.dart';
import 'package:ten_of_a_kind_poker/config/card_backs.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueTheme, internationalVenues;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final AnimationController _flagWave;

  final List<String> _images = const [
    'assets/images/splash1.png',
    'assets/images/splash2.png',
  ];
  int _current = 0;

  double _progress = 0.0; // 0..1
  String _status = 'Preparing…';
  bool _navigated = false;

  static const List<String> _flagLines = [
    'Shuffle up and deal',
    'Building your table',
    'Syncing stacks',
    'Warming up cards',
    'Locking the rail',
    'Seating players',
    'Priming the pot',
    'Almost ready',
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _flagWave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _images.length > 1) setState(() => _current = 1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final splashDelay = Future.delayed(const Duration(seconds: 4));
      try {
        await _precacheAll(context); // ✅ new impl below
      } catch (_) {
        // ignore
      } finally {
        await splashDelay;
        if (mounted) await _navigateNext();
      }
    });
  }

  Future<void> _precacheAll(BuildContext context) async {
    _setStatus('Warming up…', 0.02);

    // We render card fronts via `playing_cards` (vector/drawn), so we only
    // precache the raster assets that can otherwise pop-in (backs + splash).
    final assets = <String>[
      ..._images,
      ...kCardBackAssets,
    ];
    final total = assets.length;
    var done = 0;

    for (final asset in assets) {
      done += 1;
      _setStatus('Loading $done / $total', (done / total * 0.98));

      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {
        // Ignore precache failures (non-blocking).
      }
    }

    _setStatus('Almost there…', 1.0);
    await Future.delayed(const Duration(milliseconds: 250));
  }

  void _setStatus(String text, double p) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _progress = p.clamp(0.0, 1.0);
    });
  }

  Future<void> _navigateNext() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    final Widget next = isLoggedIn
        ? (() {
            final VenueTheme indiaVenue = internationalVenues.firstWhere(
              (v) => v.name.toLowerCase() == 'india',
              orElse: () => internationalVenues.first,
            );
            return GameScreen(
              tableName: '${indiaVenue.name} — Guest Table',
              venue: indiaVenue,
            );
          })()
        : const AuthScreen();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _flagWave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.0,
                  colors: [Color(0xFF0A0A0A), AppColors.black],
                ),
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: _BrandBlock(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _SplashImage(
                    key: ValueKey(_current),
                    path: _images[_current],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FlagWaveText(
                    lines: _flagLines,
                    controller: _flagWave,
                  ),
                ),
                const _LoadingRow(),
                const SizedBox(height: 10),
                const Text(
                  'Winner Takes All',
                  style: TextStyle(
                    color: AppColors.blue,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _ProgressText(status: _status, percent: percent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagWaveText extends StatelessWidget {
  const _FlagWaveText({required this.lines, required this.controller});
  final List<String> lines;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final double t = controller.value * 2 * math.pi;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < lines.length; i++)
              Transform.translate(
                offset: Offset(0, math.sin(t + i * 0.6) * 5.0),
                child: Text(
                  lines[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.22),
            blurRadius: 32,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 14),
            Text(
              "Ten Of A Kind",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashImage extends StatelessWidget {
  const _SplashImage({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          'assets/images/app_icon.png',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.blue,
          ),
        ),
        SizedBox(width: 10),
        Text(
          'Loading…',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProgressText extends StatelessWidget {
  const _ProgressText({required this.status, required this.percent});
  final String status;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$status  •  $percent%',
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 12.5,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
