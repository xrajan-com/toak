import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/services/app_check.dart';

void main() {
  test('App Check stays off outside release phone builds', () async {
    expect(AppCheckService.supported, isFalse);
    await AppCheckService.start();
    expect(AppCheckService.active, isFalse);
    expect(await AppCheckService.token(), isNull);
  });
}
