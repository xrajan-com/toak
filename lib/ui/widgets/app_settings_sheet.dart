import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';

Future<void> showAppSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF15161A),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const _AppSettingsSheet(),
  );
}

class _AppSettingsSheet extends StatelessWidget {
  const _AppSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final AppSettingsService settings = context.watch<AppSettingsService>();
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Sound effects'),
                    subtitle: const Text('Cards, chips and table sounds'),
                    value: settings.soundEffectsEnabled,
                    onChanged: (bool value) {
                      unawaited(settings.setSoundEffectsEnabled(value));
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Dealer voice'),
                    subtitle:
                        const Text('Spoken check, call, raise and fold cues'),
                    value: settings.dealerVoiceEnabled,
                    onChanged: (bool value) {
                      unawaited(settings.setDealerVoiceEnabled(value));
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Reduce motion'),
                    subtitle: const Text(
                      'Limits repeating glows, pulses and celebration effects',
                    ),
                    value: settings.reducedMotion,
                    onChanged: (bool value) {
                      unawaited(settings.setReducedMotion(value));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Text(
                      'Your device accessibility preference is respected even '
                      'when Reduce motion is off here.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
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
