import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/auth/sign_in_screen.dart';
import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/auth_error_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

/// Stands in for an account whose first-pet write fails, e.g. while offline.
class _FailingOnboardingRepository implements AccountOnboardingRepository {
  @override
  Future<void> deleteAccountRecord(String uid) async {}

  @override
  Future<bool> requiresFirstPet(String uid) async => false;

  @override
  Future<void> markFirstPetRequired(String uid) =>
      throw StateError('setup write offline');

  @override
  Future<void> markFirstPetComplete(String uid) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> submitNewAccount(WidgetTester tester) async {
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.test',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'password8');
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'password8',
    );
    await tester.tap(find.byKey(const Key('create-account-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a new Google account from Create account is never signed out', (
    tester,
  ) async {
    final onboarding = FakeAccountOnboardingRepository();
    final service = FakeAuthService(accountOnboardingRepository: onboarding);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'fake-google-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: onboarding,
        authService: service,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(await onboarding.requiresFirstPet('fake-google-user'), isTrue);
    expect(service.calls, isNot(contains('signOut')));
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Add Pet'), findsOneWidget);
  });

  testWidgets(
    'registration lands on sign-in with the email prefilled and a notice',
    (tester) async {
      final service = FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: service)),
      );
      await submitNewAccount(tester);

      expect(find.text('Account created. Please sign in.'), findsOneWidget);
      expect(find.text('person@example.test'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(service.calls, contains('signOut'));
    },
  );

  testWidgets(
    'a failed setup write lands on sign-in with the email and a clear retry',
    (tester) async {
      final service = FakeAuthService(
        accountOnboardingRepository: _FailingOnboardingRepository(),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: service)),
      );
      await submitNewAccount(tester);

      // The account exists, so the user is handed to sign-in with their email
      // instead of meeting a duplicate-registration error.
      expect(
        service.calls.where((call) => call == 'registerWithEmail'),
        hasLength(1),
      );
      expect(
        find.text('An account already exists for that email.'),
        findsNothing,
      );
      expect(find.text('Account created. Please sign in.'), findsOneWidget);
      expect(find.text('person@example.test'), findsOneWidget);
      expect(service.calls, contains('signOut'));

      // The retry is a sign-in, not a second registration.
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password8',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();
      expect(
        service.calls.where((call) => call == 'signInWithEmail'),
        hasLength(1),
      );
    },
  );

  testWidgets('auth error messages are announced to screen readers', (
    tester,
  ) async {
    final service = FakeAuthService()
      ..failNextSignIn(
        const AuthException(code: AuthErrorCode.invalidCredentials),
      );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(authService: service)),
    );
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret123');
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();

    final message = find.text(
      authErrorMessage(AuthErrorCode.invalidCredentials),
    );
    expect(message, findsOneWidget);
    final liveRegions = tester
        .widgetList<Semantics>(
          find.ancestor(of: message, matching: find.byType(Semantics)),
        )
        .where((widget) => widget.properties.liveRegion == true);
    expect(liveRegions, isNotEmpty);
  });
}
