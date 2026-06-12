import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ten_of_a_kind_poker/app/app.dart';
import 'package:ten_of_a_kind_poker/app/system_ui.dart';
import 'package:ten_of_a_kind_poker/config/app_build.dart';
import 'package:ten_of_a_kind_poker/firebase_options.dart';
import 'package:ten_of_a_kind_poker/game/bot/policy_model.dart'
    show BotLearnedPolicyRegistry, BotLearnedPolicyWeights;
import 'package:ten_of_a_kind_poker/services/ads_service.dart';
import 'package:ten_of_a_kind_poker/services/poker_bot_learning_service.dart';

Future<void> bootstrapApp() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await applyGameSystemUi();

    _installErrorHandlers();
    await _loadEnvironment();
    await _initializeFirebase();
    _initializeAds();
    await _loadBotPolicyWeights();

    runApp(const TenOfAKindApp());
  }, (Object error, StackTrace stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

void _initializeAds() {
  unawaited(adsService.init());
}

void _installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

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
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    debugPrint('⚠️ .env not found / failed to load: $e\n$st');
  }
}

Future<void> _initializeFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return;
    }
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('❌ Firebase init failed: $e\n$st');
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
    debugPrint('⚠️ Bot policy weights not loaded: $e\n$st');
  }
}
