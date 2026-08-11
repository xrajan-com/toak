import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/services/profile_service.dart';

void main() {
  test('profile completion requires a name and kingdom', () {
    expect(
      ProfileService.inferProfileComplete(
        displayName: 'Ada',
        kingdom: 'Mysore',
      ),
      isTrue,
    );
    expect(
      ProfileService.inferProfileComplete(
        displayName: 'Ada',
        kingdom: '',
      ),
      isFalse,
    );
  });

  test('late profile hydration cannot overwrite a switched account', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'profile.name.account-a': 'Account A',
      'profile.kingdom.account-a': 'Baroda',
      'profile.complete.account-a': true,
      'profile.name.account-b': 'Account B',
      'profile.kingdom.account-b': 'Mysore',
      'profile.complete.account-b': true,
    });
    final profile = ProfileService();

    profile.bindUserId('account-a');
    profile.bindUserId('account-b');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(profile.userId, 'account-b');
    expect(profile.displayName, 'Account B');
    expect(profile.kingdom, 'Mysore');
    expect(profile.profileComplete, isTrue);

    profile.dispose();
  });
}
