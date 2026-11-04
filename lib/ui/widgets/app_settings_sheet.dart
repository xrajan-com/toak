import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/services/app_settings_service.dart';
import 'package:ten_of_a_kind_poker/services/return_reminders.dart';

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
                    title: const Text('Lounge sounds'),
                    subtitle: const Text(
                      'Music in the lobby; at the table only at big moments',
                    ),
                    value: settings.loungeSoundsEnabled,
                    onChanged: (bool value) {
                      unawaited(settings.setLoungeSoundsEnabled(value));
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Dealer voice'),
                    subtitle: const Text('Calls all-ins, like a live dealer'),
                    value: settings.dealerVoiceEnabled,
                    onChanged: (bool value) {
                      unawaited(settings.setDealerVoiceEnabled(value));
                    },
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey<String>('settings_voice_every_action'),
                    contentPadding: const EdgeInsets.only(left: 24, right: 8),
                    title: const Text('Call every action'),
                    subtitle: const Text('Check, call, raise and fold too'),
                    value: settings.dealerVoiceEnabled &&
                        settings.dealerVoiceEveryAction,
                    onChanged: settings.dealerVoiceEnabled
                        ? (bool value) {
                            unawaited(
                              settings.setDealerVoiceEveryAction(value),
                            );
                          }
                        : null,
                  ),
                  if (ReturnReminders.instance.supported)
                    const _RemindersSwitch(),
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

/// Daily tribute and comeback reminders. Kept by [ReturnReminders] rather
/// than [AppSettingsService]: it is phone-only, and saying yes also asks the
/// system for notification permission.
class _RemindersSwitch extends StatefulWidget {
  const _RemindersSwitch();

  @override
  State<_RemindersSwitch> createState() => _RemindersSwitchState();
}

class _RemindersSwitchState extends State<_RemindersSwitch> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ReturnReminders reminders = ReturnReminders.instance;
    final bool offered = !await reminders.shouldOffer();
    final bool enabled = await reminders.isEnabled();
    if (mounted) setState(() => _on = offered && enabled);
  }

  Future<void> _set(bool value) async {
    setState(() => _on = value);
    await ReturnReminders.instance.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: const ValueKey<String>('settings_reminders'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: const Text('Reminders'),
      subtitle: const Text('When your daily tribute is ready'),
      value: _on ?? false,
      onChanged: _on == null ? null : (bool value) => unawaited(_set(value)),
    );
  }
}
