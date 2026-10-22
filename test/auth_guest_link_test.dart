import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({required this.isAnonymous});

  @override
  final bool isAnonymous;
}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.tag);

  final String tag;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.currentUser);

  @override
  final User? currentUser;

  final List<AuthCredential> signedInWith = <AuthCredential>[];

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signedInWith.add(credential);
    return _FakeCredential('existing account');
  }
}

String _tag(UserCredential credential) => (credential as _FakeCredential).tag;

void main() {
  test('a guest is linked, keeping the same account', () async {
    final auth = _FakeAuth(_FakeUser(isAnonymous: true));
    var signedIn = false;

    final result = await keepGuestProgress(
      auth,
      link: (guest) async => _FakeCredential('linked guest'),
      signIn: () async {
        signedIn = true;
        return _FakeCredential('new sign-in');
      },
    );

    expect(_tag(result), 'linked guest');
    expect(signedIn, isFalse);
  });

  test('no guest account: a plain sign-in', () async {
    for (final User? user in <User?>[null, _FakeUser(isAnonymous: false)]) {
      var linked = false;
      final result = await keepGuestProgress(
        _FakeAuth(user),
        link: (guest) async {
          linked = true;
          return _FakeCredential('linked guest');
        },
        signIn: () async => _FakeCredential('new sign-in'),
      );

      expect(_tag(result), 'new sign-in');
      expect(linked, isFalse);
    }
  });

  test('a Google account that already plays wins over the guest', () async {
    final auth = _FakeAuth(_FakeUser(isAnonymous: true));
    final AuthCredential existing =
        GoogleAuthProvider.credential(idToken: 'existing');

    final result = await keepGuestProgress(
      auth,
      link: (guest) => throw FirebaseAuthException(
        code: 'credential-already-in-use',
        credential: existing,
      ),
      signIn: () async => _FakeCredential('popup sign-in'),
      switchAccountOn: const <String>{'credential-already-in-use'},
    );

    expect(_tag(result), 'existing account');
    expect(auth.signedInWith, <AuthCredential>[existing]);
  });

  test('other errors still reach the player', () async {
    final auth = _FakeAuth(_FakeUser(isAnonymous: true));

    await expectLater(
      keepGuestProgress(
        auth,
        link: (guest) =>
            throw FirebaseAuthException(code: 'email-already-in-use'),
        signIn: () async => _FakeCredential('new sign-in'),
      ),
      throwsA(
        isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'email-already-in-use'),
      ),
    );
    expect(auth.signedInWith, isEmpty);
  });
}
