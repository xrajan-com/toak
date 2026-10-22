import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/services/rating_prompt.dart';

class _FakeReview extends Fake implements InAppReview {
  _FakeReview({this.available = true});

  final bool available;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requests++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late _FakeReview review;
  late RatingPrompt prompt;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    now = DateTime(2026, 11, 1);
    review = _FakeReview();
    prompt = RatingPrompt(review: review, now: () => now, supported: true);
  });

  test('the first fort win asks for a rating', () async {
    expect(await prompt.afterWin(kind: 'fort'), isTrue);
    expect(review.requests, 1);
  });

  test('never twice within 30 days', () async {
    await prompt.afterWin(kind: 'fort');
    now = now.add(const Duration(days: 29));
    expect(await prompt.afterWin(kind: 'title'), isFalse);
    now = now.add(const Duration(days: 1));
    expect(await prompt.afterWin(kind: 'title'), isTrue);
    expect(review.requests, 2);
  });

  test('three asks at most, ever', () async {
    for (var i = 0; i < 5; i++) {
      await prompt.afterWin(kind: 'fort');
      now = now.add(const Duration(days: 31));
    }
    expect(review.requests, RatingPrompt.maxAsks);
  });

  test('no ask where the store has no review sheet', () async {
    final prompt = RatingPrompt(
      review: _FakeReview(available: false),
      now: () => now,
      supported: true,
    );
    expect(await prompt.afterWin(kind: 'fort'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(RatingPrompt.askedCountKey), isNull);
  });

  test('the web never asks', () async {
    final prompt = RatingPrompt(review: review, now: () => now, supported: false);
    expect(await prompt.afterWin(kind: 'fort'), isFalse);
    expect(review.requests, 0);
  });
}
