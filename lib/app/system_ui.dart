import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _systemUiChangeCallbackInstalled = false;
bool _gameSystemUiActive = false;

const List<DeviceOrientation> _landscapeOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

const List<DeviceOrientation> _allOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Applies the default orientation before the first app screen is rendered.
///
/// Phones are landscape-only. Tablets keep their normal orientation choices;
/// the poker table still switches every device to landscape while it is open.
Future<void> applyAppSystemUi() async {
  _gameSystemUiActive = false;
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(_defaultAppOrientations());
  await _showSystemBars();
}

Future<void> applyGameSystemUi() async {
  _gameSystemUiActive = true;
  if (kIsWeb) return;
  _installSystemUiChangeCallback();
  await SystemChrome.setPreferredOrientations(_landscapeOrientations);

  await _hideSystemBars();
}

Future<void> restoreAppSystemUi() async {
  _gameSystemUiActive = false;
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(_defaultAppOrientations());
  await _showSystemBars();
}

List<DeviceOrientation> _defaultAppOrientations() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return _landscapeOrientations;
  final view = views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  return logicalSize.shortestSide < 600
      ? _landscapeOrientations
      : _allOrientations;
}

Future<void> _showSystemBars() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

void _installSystemUiChangeCallback() {
  if (_systemUiChangeCallbackInstalled) return;
  _systemUiChangeCallbackInstalled = true;
  SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
    if (!systemOverlaysAreVisible || !_gameSystemUiActive) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!_gameSystemUiActive) return;
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
