import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _systemUiChangeCallbackInstalled = false;

Future<void> applyGameSystemUi() async {
  if (!kIsWeb) {
    _installSystemUiChangeCallback();
  }

  await _hideSystemBars();
}

void _installSystemUiChangeCallback() {
  if (_systemUiChangeCallbackInstalled) return;
  _systemUiChangeCallbackInstalled = true;
  SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
    if (!systemOverlaysAreVisible) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _hideSystemBars();
  });
}

Future<void> _hideSystemBars() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}
