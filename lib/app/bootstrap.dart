import 'dart:convert';
import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show immutable, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ten_of_a_kind_poker/app/app.dart';
import 'package:ten_of_a_kind_poker/app/system_ui.dart';
import 'package:ten_of_a_kind_poker/config/app_build.dart';
import 'package:ten_of_a_kind_poker/core/venue_time.dart';
import 'package:ten_of_a_kind_poker/firebase_options.dart';
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart'
    show BotLearnedPolicyRegistry, BotLearnedPolicyWeights;
import 'package:ten_of_a_kind_poker/services/ads_service.dart';
import 'package:ten_of_a_kind_poker/services/poker_bot_learning_service.dart';

enum AppErrorSeverity { warning, error, fatal }

@immutable
class AppErrorReport {
  final String category;
  final String message;
  final AppErrorSeverity severity;
  final DateTime occurredAtUtc;

  const AppErrorReport({
    required this.category,
    required this.message,
    required this.severity,
    required this.occurredAtUtc,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'category': category,
        'message': message,
        'severity': severity.name,
        'occurredAtUtc': occurredAtUtc.toIso8601String(),
      };
}

typedef AppErrorSink = FutureOr<void> Function(AppErrorReport report);

/// Structured, vendor-neutral reporting hook.
///
/// Production builds emit only the safe fields in [AppErrorReport]. A future
/// reporting provider can install [sink] without embedding service credentials
/// or personal/account data in this app.
class AppErrorReporter {
  static AppErrorSink? sink;

  static Future<void> report({
    required String category,
    required String message,
    required AppErrorSeverity severity,
    Object? debugError,
    StackTrace? debugStack,
  }) async {
    final report = AppErrorReport(
      category: category,
      message: message,
      severity: severity,
      occurredAtUtc: DateTime.now().toUtc(),
    );
    debugPrint(jsonEncode(report.toJson()));
    if (kDebugMode && debugError != null) {
      debugPrint('$debugError\n${debugStack ?? StackTrace.current}');
    }
    try {
      await sink?.call(report);
    } catch (error, stack) {
      if (kDebugMode) debugPrint('Error reporter sink failed: $error\n$stack');
    }
  }
}

Future<void> bootstrapApp() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installErrorHandlers();
    try {
      await applyAppSystemUi();
      VenueTime.initialize();
      await _loadEnvironment();
      // Account and cloud features are optional at launch. In particular, a
      // blocked FlutterFire module request in a browser must not replace the
      // entire offline-capable game with a fatal startup screen.
      await _initializeOptionalFirebase();
      _initializeAds();
      await _loadBotPolicyWeights();
      runApp(const TenOfAKindApp());
    } catch (error, stack) {
      await AppErrorReporter.report(
        category: 'startup',
        message: 'Required app services could not be initialized.',
        severity: AppErrorSeverity.fatal,
        debugError: error,
        debugStack: stack,
      );
      runApp(const _StartupFailureApp());
    }
  }, (Object error, StackTrace stack) {
    unawaited(
      AppErrorReporter.report(
        category: 'uncaught',
        message: 'An unexpected app error occurred.',
        severity: AppErrorSeverity.fatal,
        debugError: error,
        debugStack: stack,
      ),
    );
  });
}

void _initializeAds() {
  unawaited(
    adsService.init().catchError((Object error, StackTrace stack) {
      unawaited(
        AppErrorReporter.report(
          category: 'ads',
          message: 'Optional advertising services did not initialize.',
          severity: AppErrorSeverity.warning,
          debugError: error,
          debugStack: stack,
        ),
      );
    }),
  );
}

void _installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(
      AppErrorReporter.report(
        category: 'flutter',
        message: 'A screen could not be rendered.',
        severity: AppErrorSeverity.error,
        debugError: details.exception,
        debugStack: details.stack,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(
      AppErrorReporter.report(
        category: 'platform',
        message: 'An unexpected platform error occurred.',
        severity: AppErrorSeverity.error,
        debugError: error,
        debugStack: stack,
      ),
    );
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white70,
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account details are safe. Return to the start and '
                    'try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    SelectableText(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => runApp(const TenOfAKindApp()),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Start'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    await AppErrorReporter.report(
      category: 'environment',
      message: 'Optional environment configuration was not loaded.',
      severity: AppErrorSeverity.warning,
      debugError: e,
      debugStack: st,
    );
  }
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  }
  await Firebase.initializeApp();
}

Future<void> _initializeOptionalFirebase() async {
  try {
    await _initializeFirebase().timeout(const Duration(seconds: 20));
  } catch (error, stack) {
    await AppErrorReporter.report(
      category: 'firebase',
      message: 'Optional account services were not initialized.',
      severity: AppErrorSeverity.warning,
      debugError: error,
      debugStack: stack,
    );
  }
}

Future<void> _loadBotPolicyWeights() async {
  try {
    final text =
        await rootBundle.loadString('assets/ml/bot_policy_weights.json');
    if (text.trim().isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        BotLearnedPolicyRegistry.setWeights(
          BotLearnedPolicyWeights.fromJson(
            Map<String, Object?>.from(decoded),
          ),
        );
      }
    }
    if (AppBuild.current.enableBotTraining) {
      final BotLearnedPolicyWeights? persisted =
          await const PokerBotLearningService().loadPersistedWeights();
      if (persisted != null) {
        BotLearnedPolicyRegistry.setWeights(persisted);
      }
    }
  } catch (e, st) {
    await AppErrorReporter.report(
      category: 'bot_policy',
      message: 'Optional bot policy weights were not loaded.',
      severity: AppErrorSeverity.warning,
      debugError: e,
      debugStack: st,
    );
  }
}

class _StartupFailureApp extends StatefulWidget {
  const _StartupFailureApp();

  @override
  State<_StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<_StartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await bootstrapApp();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ten of a Kind could not start',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection and try again. No sign-in failure '
                      'will silently continue as a guest.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_retrying ? 'Retrying…' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
