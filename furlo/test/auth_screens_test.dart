import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/auth/create_account_screen.dart';
import 'package:furlo/screens/auth/forgot_password_screen.dart';
import 'package:furlo/screens/auth/sign_in_screen.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/auth_error_messages.dart';
import 'package:furlo/utils/auth_validators.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_service.dart';
import 'helpers/fake_account_onboarding_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('auth validators', () {
    test(
      'email validator accepts a valid address and rejects invalid input',
      () {
        expect(validateEmail('person@example.com'), isNull);
        expect(validateEmail('  person@example.com  '), isNull);
        expect(validateEmail(null), 'Enter your email');
        expect(validateEmail('not-an-email'), 'Enter a valid email address');
        expect(
          validateEmail('person@localhost'),
          'Enter a valid email address',
        );
      },
    );

    test('password validator requires at least eight characters', () {
      expect(validatePassword(null), 'Enter a password');
      expect(validatePassword('short7'), 'Use at least 8 characters');
      expect(validatePassword('long-enough'), isNull);
    });

    test('sign-in password validator only requires presence', () {
      expect(validateSignInPassword(null), 'Enter a password');
      expect(validateSignInPassword(''), 'Enter a password');
      expect(validateSignInPassword('short'), isNull);
    });

    test('confirmation validator requires matching passwords', () {
      expect(
        validateConfirmPassword(null, 'long-enough'),
        'Confirm your password',
      );
      expect(
        validateConfirmPassword('', 'long-enough'),
        'Confirm your password',
      );
      expect(
        validateConfirmPassword('different', 'long-enough'),
        'Passwords do not match',
      );
      expect(validateConfirmPassword('long-enough', 'long-enough'), isNull);
    });
  });

  test('every AuthErrorCode has a centralized friendly message', () {
    expect(AuthErrorCode.values.map(authErrorMessage).toList(), [
      'Check your email and password, then try again.',
      'No account was found for those credentials.',
      'An account already exists for that email.',
      'Choose a stronger password and try again.',
      'Check your internet connection and try again.',
      'Too many attempts. Please wait and try again.',
      'Sign-in was cancelled.',
      'Pop-ups are blocked for this site. Allow them, then try again.',
      'Something went wrong. Please try again.',
    ]);
  });

  testWidgets('sign-in maps every auth error and suppresses cancellation', (
    tester,
  ) async {
    for (final code in AuthErrorCode.values) {
      final service = FakeAuthService()
        ..failNextSignIn(AuthException(code: code));
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: service)),
      );
      await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();

      expect(find.text(authErrorMessage(code)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'sign-in accepts existing passwords shorter than eight characters',
    (tester) async {
      final service = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: service)),
      );
      await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
      await tester.enterText(find.byKey(const Key('auth-password')), 'abc');
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters'), findsNothing);
      expect(service.calls, contains('signInWithEmail'));
    },
  );

  testWidgets('unknown exceptions show only the generic auth message', (
    tester,
  ) async {
    final service = FakeAuthService()
      ..failNextSignInWith(StateError('sensitive exception details'));
    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(authService: service)),
    );
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret123');
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();
    expect(find.text(authErrorMessage(AuthErrorCode.unknown)), findsOneWidget);
    expect(find.text('sensitive exception details'), findsNothing);
  });

  testWidgets(
    'password reset response is the same for existing and missing accounts',
    (tester) async {
      const response =
          'If an account exists for that email, a reset link has been sent.';
      final successService = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(authService: successService)),
      );
      await tester.enterText(find.byKey(const Key('reset-email')), 'a@b.test');
      await tester.tap(find.byKey(const Key('send-reset-link')));
      await tester.pumpAndSettle();
      expect(find.text(response), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(response)).style?.color,
        AppPalette.light.accent,
        reason: 'success messages render in the accent color, not danger',
      );

      final missingService = FakeAuthService()
        ..failNextPasswordReset(
          const AuthException(code: AuthErrorCode.userNotFound),
        );
      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(authService: missingService)),
      );
      await tester.enterText(find.byKey(const Key('reset-email')), 'a@b.test');
      await tester.tap(find.byKey(const Key('send-reset-link')));
      await tester.pumpAndSettle();
      expect(find.text(response), findsOneWidget);
    },
  );

  testWidgets('password reset shows a network error message', (tester) async {
    final service = FakeAuthService()
      ..failNextPasswordReset(
        const AuthException(code: AuthErrorCode.networkError),
      );
    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordScreen(authService: service)),
    );
    await tester.enterText(find.byKey(const Key('reset-email')), 'a@b.test');
    await tester.tap(find.byKey(const Key('send-reset-link')));
    await tester.pumpAndSettle();
    expect(
      find.text(authErrorMessage(AuthErrorCode.networkError)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.text(authErrorMessage(AuthErrorCode.networkError)))
          .style
          ?.color,
      AppPalette.light.danger,
      reason: 'error messages stay in the danger color',
    );
  });

  testWidgets(
    'cancelled Google sign-in has no message on sign-in or registration',
    (tester) async {
      final signInService = FakeAuthService()
        ..failNextGoogleSignIn(
          const AuthException(code: AuthErrorCode.cancelled),
        );
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: signInService)),
      );
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(
        find.text(authErrorMessage(AuthErrorCode.cancelled)),
        findsNothing,
      );

      final registerService = FakeAuthService()
        ..failNextGoogleSignIn(
          const AuthException(code: AuthErrorCode.cancelled),
        );
      await tester.pumpWidget(
        MaterialApp(home: CreateAccountScreen(authService: registerService)),
      );
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(
        find.text(authErrorMessage(AuthErrorCode.cancelled)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'busy sign-in ignores repeated submissions and disables controls',
    (tester) async {
      final release = Completer<void>();
      final service = FakeAuthService()..beforeNextSignIn(() => release.future);
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: service)),
      );
      await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      expect(
        service.calls.where((call) => call == 'signInWithEmail'),
        hasLength(1),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('sign-in-submit')))
            .onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      release.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('sign-in success returns to the signed-in app', (tester) async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    await tester.pumpWidget(
      FurloApp(
        repository: repository,
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        authService: FakeAuthService(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret123');
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets(
    'registration success returns to app root and shows signed-in app',
    (tester) async {
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      final onboarding = FakeAccountOnboardingRepository();
      final service = FakeAuthService(accountOnboardingRepository: onboarding);
      await tester.pumpWidget(
        FurloApp(
          repository: repository,
          notificationService: const NoOpNotificationService(),
          accountOnboardingRepository: onboarding,
          authService: service,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password8',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'password8',
      );
      await tester.tap(find.byKey(const Key('create-account-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Quick Actions'), findsNothing);
      expect(find.text('Create account'), findsOneWidget);
      expect(service.calls, contains('signOut'));
      expect(await onboarding.requiresFirstPet('fake-user'), isTrue);

      await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.test');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password8',
      );
      await tester.tap(find.byKey(const Key('sign-in-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Add pet'), findsOneWidget);
    },
  );

  testWidgets(
    'new Google account returns to sign-in and first later sign-in prompts Add Pet',
    (tester) async {
      final onboarding = FakeAccountOnboardingRepository();
      final service = FakeAuthService(accountOnboardingRepository: onboarding);
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

      expect(find.text('Sign in'), findsOneWidget);
      expect(await onboarding.requiresFirstPet('fake-google-user'), isTrue);

      service.googleCreatesNewAccount = false;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Add pet'), findsOneWidget);
    },
  );

  testWidgets('sign-out from a pushed Profile route returns to sign-in root', (
    tester,
  ) async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final service = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'profile-user',
        email: 'person@example.com',
        displayName: null,
      ),
    );
    await tester.pumpWidget(
      FurloApp(
        repository: repository,
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        authService: service,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    // Signing out asks for confirmation first.
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsNothing);
  });

  testWidgets('auth screens do not overflow at 400x300 in all app themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final choice in AppThemeChoice.values) {
      final service = FakeAuthService();
      final screens = <Widget>[
        SignInScreen(authService: service),
        CreateAccountScreen(authService: service),
        ForgotPasswordScreen(authService: service),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.forChoice(choice), home: screen),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} in $choice',
        );
      }
    }
  });
}
