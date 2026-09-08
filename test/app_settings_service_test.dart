import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('audio and motion preferences persist across service recreation',
      () async {
    final AppSettingsService first = AppSettingsService();
    await first.load();

    // Set to the NON-default so this still exercises a real write: the
    // setter early-returns when the value already matches.
    await first.setSoundEffectsEnabled(true);
    await first.setLoungeSoundsEnabled(true);
    await first.setDealerVoiceEnabled(false);
    await first.setReducedMotion(true);

    final AppSettingsService restored = AppSettingsService();
    await restored.load();

    expect(restored.soundEffectsEnabled, isTrue);
    expect(restored.loungeSoundsEnabled, isTrue);
    expect(restored.dealerVoiceEnabled, isFalse);
    expect(restored.reducedMotion, isTrue);
    expect(restored.loaded, isTrue);
  });

  test('first run is quiet except the dealer voice', () async {
    final AppSettingsService settings = AppSettingsService();
    await settings.load();

    expect(settings.loungeSoundsEnabled, isFalse,
        reason: 'game-screen music must not play uninvited');
    expect(settings.soundEffectsEnabled, isFalse,
        reason: 'table audio must not play uninvited');
    expect(settings.dealerVoiceEnabled, isTrue,
        reason: 'the dealer voice carries information and stays on');
  });

  testWidgets('device-level reduced motion is always respected',
      (WidgetTester tester) async {
    final AppSettingsService settings = AppSettingsService();
    await settings.load();
    bool? observed;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (BuildContext context) {
            observed = settings.reduceMotionFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(observed, isTrue);
  });
}
