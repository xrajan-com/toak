import 'dart:async';

import 'package:flutter/foundation.dart';

class AuthorFlashGate {
  static final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  static bool get visible => activeCount.value > 0;

  static void enter() {
    activeCount.value = activeCount.value + 1;
  }

  static void exit() {
    final v = activeCount.value;
    if (v <= 0) return;
    activeCount.value = v - 1;
  }

  static Future<void> waitUntilHidden() async {
    if (activeCount.value == 0) return;

    final done = Completer<void>();
    void listener() {
      if (activeCount.value == 0 && !done.isCompleted) {
        activeCount.removeListener(listener);
        done.complete();
      }
    }

    activeCount.addListener(listener);
    if (activeCount.value == 0 && !done.isCompleted) {
      activeCount.removeListener(listener);
      done.complete();
    }

    await done.future;
  }
}
