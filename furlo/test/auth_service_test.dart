import 'package:flutter_test/flutter_test.dart';

import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/firebase_auth_service.dart';
import 'helpers/fake_auth_service.dart';

void main() {
  group('mapFirebaseAuthErrorCode', () {
    const cases = <String, AuthErrorCode>{
      'invalid-credential': AuthErrorCode.invalidCredentials,
      'wrong-password': AuthErrorCode.invalidCredentials,
      'invalid-email': AuthErrorCode.invalidCredentials,
      'user-not-found': AuthErrorCode.userNotFound,
      'email-already-in-use': AuthErrorCode.emailInUse,
      'weak-password': AuthErrorCode.weakPassword,
      'network-request-failed': AuthErrorCode.networkError,
      'too-many-requests': AuthErrorCode.tooManyRequests,
      'popup-closed-by-user': AuthErrorCode.cancelled,
      'cancelled-popup-request': AuthErrorCode.cancelled,
      'not-a-firebase-code': AuthErrorCode.unknown,
    };

    for (final entry in cases.entries) {
      test('${entry.key} maps to ${entry.value.name}', () {
        expect(mapFirebaseAuthErrorCode(entry.key), entry.value);
      });
    }
  });

  group('FakeAuthService', () {
    const firstUser = AuthUser(
      uid: 'first',
      email: 'first@example.test',
      displayName: 'First',
    );
    const secondUser = AuthUser(
      uid: 'second',
      email: 'second@example.test',
      displayName: 'Second',
    );

    test('emits the current user immediately for each listener', () async {
      final service = FakeAuthService(initialUser: firstUser);
      addTearDown(service.dispose);
      final firstEvents = <AuthUser?>[];
      final secondEvents = <AuthUser?>[];

      final firstSubscription = service.authStateChanges.listen(
        firstEvents.add,
      );
      final secondSubscription = service.authStateChanges.listen(
        secondEvents.add,
      );
      await Future<void>.delayed(Duration.zero);

      expect(firstEvents, [firstUser]);
      expect(secondEvents, [firstUser]);
      await firstSubscription.cancel();
      await secondSubscription.cancel();
    });

    test('pushes every later user change to active listeners', () async {
      final service = FakeAuthService();
      addTearDown(service.dispose);
      final events = <AuthUser?>[];
      final subscription = service.authStateChanges.listen(events.add);

      service.setUser(firstUser);
      service.setUser(secondUser);
      await Future<void>.delayed(Duration.zero);

      expect(events, [null, firstUser, secondUser]);
      await subscription.cancel();
    });

    test('signOut records the call and emits null', () async {
      final service = FakeAuthService(initialUser: firstUser);
      addTearDown(service.dispose);
      final events = <AuthUser?>[];
      final subscription = service.authStateChanges.listen(events.add);

      await service.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(service.currentUser, isNull);
      expect(events, [firstUser, null]);
      expect(service.calls, ['signOut']);
      await subscription.cancel();
    });

    test(
      'records methods and throws a chosen one-shot sign-in exception',
      () async {
        final service = FakeAuthService();
        addTearDown(service.dispose);
        const failure = AuthException(code: AuthErrorCode.networkError);
        service.failNextSignIn(failure);

        await expectLater(
          service.signInWithEmail('person@example.test', 'test-password'),
          throwsA(same(failure)),
        );
        final result = await service.registerWithEmail(
          'person@example.test',
          'test-password',
        );

        expect(result.user.uid, 'fake-user');
        expect(result.isNewAccount, isTrue);
        expect(service.calls, ['signInWithEmail', 'registerWithEmail']);
        expect(service.currentUser, result.user);

        service.failNextRegister(failure);
        await expectLater(
          service.registerWithEmail('person@example.test', 'test-password'),
          throwsA(same(failure)),
        );
        expect(service.calls, [
          'signInWithEmail',
          'registerWithEmail',
          'registerWithEmail',
        ]);
        expect(service.currentUser, result.user);
      },
    );
  });
}
