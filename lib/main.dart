// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Firebase config
import 'firebase_options.dart';

// Services
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/stat_service.dart';
import 'services/game_service.dart';
import 'services/campaign_progress_service.dart';

// Theme
import 'themes/app_theme.dart';

// Screens
import 'ui/screens/venue_screen.dart';
import 'config/card_backs.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Show red-screen errors AND forward them to the zone (so we log stacks).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };

    // Render widget build errors instead of crashing silently.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    };

    // -------- App init (log failures explicitly) --------
    try {
      await dotenv.load(fileName: ".env");
    } catch (e, st) {
      debugPrint("⚠️ .env not found / failed to load: $e\n$st");
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint("❌ Firebase init failed: $e\n$st");
    }

    runApp(const TenOfAKindApp());
  }, (Object error, StackTrace stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

class TenOfAKindApp extends StatelessWidget {
  const TenOfAKindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => StatService()),
        ChangeNotifierProvider(create: (_) => GameService()),
        ChangeNotifierProvider(create: (_) => CampaignProgressService()),
      ],
      child: MaterialApp(
        title: 'Ten of a Kind - Poker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _DisclaimerSplash(),
      ),
    );
  }
}

class _DisclaimerSplash extends StatefulWidget {
  const _DisclaimerSplash({Key? key}) : super(key: key);

  @override
  State<_DisclaimerSplash> createState() => _DisclaimerSplashState();
}

class _DisclaimerSplashState extends State<_DisclaimerSplash>
    with SingleTickerProviderStateMixin {
  static const _paragraphs = [
    'Ten of a Kind is a small passion project by a poker fan who prefers to stay anonymous. It is built for fun, polish, and learning — not as a business and not as a gambling product.',
    'This game is free to play. There are no cash deposits, no cash-outs, and no rewards with real-world value. Treat it as a mental gym: practice patience, attention, probability, and decision-making under uncertainty.',
    'Poker theory is about making the best decision with imperfect information. Instead of “Did I win this hand?”, focus on whether your choices are profitable over time. Position, pot odds, equity, and ranges matter more than any single result.',
    'Game theory shows up everywhere in poker: balancing bluffs and value, mixing strategies, and staying unpredictable while still being fundamentally sound. Even a light exposure to expected value can sharpen how you think about risk, incentives, and discipline.',
    'In India, real-money gambling and many “real-money gaming” operations are tightly regulated, and some jurisdictions restrict or ban them due to consumer harm, addiction risk, and fraud. This app intentionally avoids real-money wagering — please follow your local laws, steer clear of illegal offerings, and report suspicious operations through the appropriate channels.',
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
      MaterialPageRoute(builder: (_) => const VenueScreen()),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _warmAssets() async {
    // Preload common assets while disclaimer is shown.
    try {
      final ctx = context;
      // Banner and logo
      precacheImage(const AssetImage('assets/images/banner.png'), ctx);
      precacheImage(const AssetImage('assets/images/app_icon.png'), ctx);
      // Flags (lightweight)
      const flags = [
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
      for (final f in flags) {
        precacheImage(AssetImage(f), ctx);
      }
      // Card backs (common in game)
      for (final b in kCardBackAssets) {
        precacheImage(AssetImage(b), ctx);
      }
    } catch (_) {
      // ignore warm failures
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
                      final double t = _glow.value;
                      return ShaderMask(
                        shaderCallback: (Rect bounds) {
                          final double width = bounds.width;
                          final double glowWidth = width * 0.35;
                          final double shift =
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
                            final maxWidth = math.min(constraints.maxWidth, 560.0);
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
                                        padding: const EdgeInsets.symmetric(vertical: 6),
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
