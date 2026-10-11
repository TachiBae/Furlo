import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/auth/complete_profile_screen.dart';
import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/firebase_auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/auth_error_messages.dart';
import 'package:furlo/utils/user_storage_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

/// Profile marker store whose behaviour each test drives.
class _FakeAccountProfileRepository implements AccountProfileRepository {
  _FakeAccountProfileRepository({this.requiresCompletion = false});

  bool requiresCompletion;
  bool failNextRequire = false;
  bool failNextComplete = false;
  bool setupComplete =
      true; // the fake models an established account by default
  String? completedFullName;
  String? completedDisplayName;

  @override
  Future<bool> requiresProfileCompletion(String uid) async {
    if (failNextRequire) {
      failNextRequire = false;
      throw StateError('profile read offline');
    }
    return requiresCompletion;
  }

  @override
  Future<void> markProfileRequired(String uid) async {
    requiresCompletion = true;
  }

  @override
  Future<void> completeProfile(
    String uid, {
    required String fullName,
    required String displayName,
  }) async {
    if (failNextComplete) {
      failNextComplete = false;
      throw StateError('profile write offline');
    }
    completedFullName = fullName;
    completedDisplayName = displayName;
    requiresCompletion = false;
  }

  @override
  Future<bool> isSetupComplete(String uid) async => setupComplete;

  @override
  Future<void> markSetupComplete(String uid) async {
    setupComplete = true;
  }
}

/// App display-name store whose failure each test can trigger.
class _FailingAppSettings implements AppSettingsRepository {
  bool failNextSet = false;
  String? value;

  @override
  Future<String> getDisplayName() async => value ?? '';

  @override
  Future<void> setDisplayName(String value) async {
    if (failNextSet) {
      failNextSet = false;
      throw StateError('settings write offline');
    }
    this.value = value.trim();
  }

  @override
  Future<void> clearDisplayName() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('profile-full-name')),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const Key('profile-password')),
      'password8',
    );
    await tester.enterText(
      find.byKey(const Key('profile-confirm-password')),
      'password8',
    );
    await tester.tap(find.byKey(const Key('complete-profile-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a new Google account is gated on the completion step', (
    tester,
  ) async {
    final onboarding = FakeAccountOnboardingRepository();
    final profile = _FakeAccountProfileRepository();
    final auth = FakeAuthService(
      accountOnboardingRepository: onboarding,
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'fake-google-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: onboarding,
        accountProfileRepository: profile,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.byKey(const Key('complete-profile-submit')), findsOneWidget);
    expect(find.byKey(const Key('complete-profile-sign-out')), findsOneWidget);
  });

  testWidgets('an existing account is never gated on the completion step', (
    tester,
  ) async {
    final onboarding = FakeAccountOnboardingRepository();
    final profile = _FakeAccountProfileRepository();
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'returning-user',
        email: 'person@example.test',
        displayName: 'Ada',
      ),
      accountOnboardingRepository: onboarding,
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'returning-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: onboarding,
        accountProfileRepository: profile,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsNothing);
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  testWidgets('a Google sign-in for an existing account is not gated', (
    tester,
  ) async {
    final onboarding = FakeAccountOnboardingRepository();
    final profile = _FakeAccountProfileRepository();
    final auth = FakeAuthService(
      accountOnboardingRepository: onboarding,
      accountProfileRepository: profile,
    )..googleCreatesNewAccount = false;
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'fake-google-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: onboarding,
        accountProfileRepository: profile,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsNothing);
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  testWidgets(
    'submitting links the password, saves both names, then marks the profile',
    (tester) async {
      const uid = 'new-google-user';
      final onboarding = FakeAccountOnboardingRepository();
      final profile = _FakeAccountProfileRepository(requiresCompletion: true);
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: uid,
          email: 'person@example.test',
          displayName: null,
        ),
        accountOnboardingRepository: onboarding,
        accountProfileRepository: profile,
      );
      addTearDown(auth.dispose);
      // A brand-new Google account also carries the first-pet marker, so the
      // step after completion is the Add pet onboarding.
      await onboarding.markFirstPetRequired(uid);
      await tester.pumpWidget(
        FurloApp(
          repository: WebPetRepository(storageScope: uid),
          notificationService: const NoOpNotificationService(),
          accountOnboardingRepository: onboarding,
          accountProfileRepository: profile,
          authService: auth,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsOneWidget);

      await fillAndSubmit(tester);

      // Order: link the password, then the account name, then the app display
      // name, and the profile marker is written last.
      final linkIndex = auth.calls.indexOf('linkPassword');
      final nameIndex = auth.calls.indexOf('updateFullName');
      expect(linkIndex, greaterThanOrEqualTo(0));
      expect(nameIndex, greaterThan(linkIndex));
      expect(auth.passwordLinked, isTrue);
      expect(auth.currentUser?.displayName, 'Ada Lovelace');
      // The gate stores the app display name in the account's own scope.
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(
          'profile.user.${userStorageScopeToken(uid)}.display_name',
        ),
        'Ada',
      );
      expect(profile.completedFullName, 'Ada Lovelace');
      expect(profile.completedDisplayName, 'Ada');

      // The startup flow takes over: this account still needs its first pet.
      expect(find.text('Add Pet'), findsOneWidget);
      expect(find.text('Complete your profile'), findsNothing);
    },
  );

  testWidgets('a failed password link keeps the user on the step and retries', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true);
    final auth =
        FakeAuthService(
          initialUser: const AuthUser(
            uid: 'new-google-user',
            email: 'person@example.test',
            displayName: null,
          ),
          accountProfileRepository: profile,
        )..failNextLinkPassword(
          const AuthException(code: AuthErrorCode.networkError),
        );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteProfileScreen(
          authService: auth,
          profileRepository: profile,
          appSettings: _FailingAppSettings(),
          uid: 'new-google-user',
          onCompleted: () async {},
        ),
      ),
    );
    await fillAndSubmit(tester);

    expect(
      find.text(authErrorMessage(AuthErrorCode.networkError)),
      findsOneWidget,
    );
    expect(find.text('Complete your profile'), findsOneWidget);
    // Entries are kept so the retry does not start over.
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(profile.completedFullName, isNull);

    await tester.tap(find.byKey(const Key('complete-profile-submit')));
    await tester.pumpAndSettle();
    expect(auth.passwordLinked, isTrue);
    expect(profile.completedFullName, 'Ada Lovelace');
  });

  testWidgets('a failed account-name update keeps the user on the step', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true);
    final auth =
        FakeAuthService(
          initialUser: const AuthUser(
            uid: 'new-google-user',
            email: 'person@example.test',
            displayName: null,
          ),
          accountProfileRepository: profile,
        )..failNextUpdateFullName(
          const AuthException(code: AuthErrorCode.networkError),
        );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteProfileScreen(
          authService: auth,
          profileRepository: profile,
          appSettings: _FailingAppSettings(),
          uid: 'new-google-user',
          onCompleted: () async {},
        ),
      ),
    );
    await fillAndSubmit(tester);

    expect(
      find.text(authErrorMessage(AuthErrorCode.networkError)),
      findsOneWidget,
    );
    expect(find.text('Complete your profile'), findsOneWidget);
    // The password step had already succeeded before this one failed.
    expect(auth.passwordLinked, isTrue);
    expect(profile.completedFullName, isNull);

    await tester.tap(find.byKey(const Key('complete-profile-submit')));
    await tester.pumpAndSettle();
    expect(auth.currentUser?.displayName, 'Ada Lovelace');
    expect(profile.completedFullName, 'Ada Lovelace');
  });

  testWidgets('a failed display-name save keeps the user on the step', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true);
    final appSettings = _FailingAppSettings()..failNextSet = true;
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'new-google-user',
        email: 'person@example.test',
        displayName: null,
      ),
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteProfileScreen(
          authService: auth,
          profileRepository: profile,
          appSettings: appSettings,
          uid: 'new-google-user',
          onCompleted: () async {},
        ),
      ),
    );
    await fillAndSubmit(tester);

    expect(find.text(authErrorMessage(AuthErrorCode.unknown)), findsOneWidget);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(profile.completedFullName, isNull);

    await tester.tap(find.byKey(const Key('complete-profile-submit')));
    await tester.pumpAndSettle();
    expect(appSettings.value, 'Ada');
    expect(profile.completedFullName, 'Ada Lovelace');
  });

  testWidgets('a failed profile write keeps the user on the step and retries', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true)
      ..failNextComplete = true;
    final appSettings = _FailingAppSettings();
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'new-google-user',
        email: 'person@example.test',
        displayName: null,
      ),
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteProfileScreen(
          authService: auth,
          profileRepository: profile,
          appSettings: appSettings,
          uid: 'new-google-user',
          onCompleted: () async {},
        ),
      ),
    );
    await fillAndSubmit(tester);

    expect(find.text(authErrorMessage(AuthErrorCode.unknown)), findsOneWidget);
    expect(find.text('Complete your profile'), findsOneWidget);
    // Everything before the marker succeeded, so only the marker is retried.
    expect(appSettings.value, 'Ada');
    expect(profile.completedFullName, isNull);

    await tester.tap(find.byKey(const Key('complete-profile-submit')));
    await tester.pumpAndSettle();
    expect(profile.completedFullName, 'Ada Lovelace');
    expect(profile.completedDisplayName, 'Ada');
  });

  testWidgets('sign out from the completion step returns to sign in', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true);
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'new-google-user',
        email: 'person@example.test',
        displayName: null,
      ),
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'new-google-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        accountProfileRepository: profile,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-profile-sign-out')));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signOut'));
    expect(find.text('Complete your profile'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a profile read failure surfaces the account setup error', (
    tester,
  ) async {
    final profile = _FakeAccountProfileRepository(requiresCompletion: true)
      ..failNextRequire = true;
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'new-google-user',
        email: 'person@example.test',
        displayName: null,
      ),
      accountProfileRepository: profile,
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        repository: WebPetRepository(storageScope: 'new-google-user'),
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        accountProfileRepository: profile,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsNothing);
    expect(
      find.text('Your account setup could not be loaded.'),
      findsOneWidget,
    );
  });

  test(
    'link-password error codes map to friendly messages, retries succeed',
    () {
      // A retry after a half-finished submit must not fail as "already linked".
      expect(mapLinkPasswordErrorCode('provider-already-linked'), isNull);
      expect(
        mapLinkPasswordErrorCode('credential-already-in-use'),
        AuthErrorCode.emailInUse,
      );
      expect(
        mapLinkPasswordErrorCode('weak-password'),
        AuthErrorCode.weakPassword,
      );
      expect(
        mapLinkPasswordErrorCode('invalid-credential'),
        AuthErrorCode.invalidCredentials,
      );
      expect(
        mapLinkPasswordErrorCode('network-request-failed'),
        AuthErrorCode.networkError,
      );
      expect(
        mapLinkPasswordErrorCode('too-many-requests'),
        AuthErrorCode.tooManyRequests,
      );
      expect(
        mapLinkPasswordErrorCode('requires-recent-login'),
        AuthErrorCode.unknown,
      );
      expect(mapLinkPasswordErrorCode('anything-else'), AuthErrorCode.unknown);
    },
  );
}
