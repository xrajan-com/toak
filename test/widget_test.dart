// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/app.dart';

void main() {
  testWidgets('App opens on the PLAY screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.pumpWidget(const TenOfAKindApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('welcome_play')), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.textContaining('Play money only'), findsOneWidget);
  });
}
