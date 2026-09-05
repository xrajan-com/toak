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

    await first.setSoundEffectsEnabled(false);
    await first.setLoungeSoundsEnabled(true);
    await first.setDealerVoiceEnabled(false);
    await first.setReducedMotion(true);

    final AppSettingsService restored = AppSettingsService();
    await restored.load();

    expect(restored.soundEffectsEnabled, isFalse);
    expect(restored.loungeSoundsEnabled, isTrue);
    expect(restored.dealerVoiceEnabled, isFalse);
    expect(restored.reducedMotion, isTrue);
    expect(restored.loaded, isTrue);
  });

  test('lounge sounds are muted by default', () async {
    final AppSettingsService settings = AppSettingsService();
    await settings.load();

    expect(settings.loungeSoundsEnabled, isFalse);
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
