import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/utils/author_flash_gate.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/author_flash_overlay.dart';

Future<void> showAuthorFlashOverlay({
  required BuildContext context,
  required Future<void> Function() startWork,
  Duration minDuration = const Duration(seconds: 3),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (overlay == null) {
    await startWork();
    return;
  }

  final entry = OverlayEntry(builder: (_) => const AuthorFlashOverlay());
  overlay.insert(entry);
  AuthorFlashGate.enter();

  final sw = Stopwatch()..start();
  try {
    await startWork();
    await WidgetsBinding.instance.endOfFrame;
  } finally {
    final remaining = minDuration - sw.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    entry.remove();
    AuthorFlashGate.exit();
  }
}
