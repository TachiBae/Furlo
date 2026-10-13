import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/repositories/account_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(WebPetRepository, FakeAuthService, FakeAccountOnboardingRepository)>
  openSettings(WidgetTester tester, {bool passwordAccount = true}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    final auth =
        FakeAuthService(
            initialUser: const AuthUser(
              uid: 'del-user',
              email: 'person@example.com',
              displayName: null,
            ),
          )
          ..acceptedPassword = 'right-password'
          ..passwordAccount = passwordAccount;
    addTearDown(auth.dispose);
    final onboarding = FakeAccountOnboardingRepository();
    await tester.pumpWidget(
      FurloApp(
        repository: repository,
        notificationService: const NoOpNotificationService(),
        accountOnboardingRepository: onboarding,
        authService: auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    return (repository, auth, onboarding);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();
  }

  testWidgets('a wrong password deletes nothing', (tester) async {
    final (repository, auth, _) = await openSettings(tester);
    await tester.enterText(find.byType(TextField), 'wrong');
    await confirm(tester);

    expect(
      find.text(authErrorText(AuthErrorCode.invalidCredentials)),
      findsOneWidget,
    );
    expect(await repository.getPets(), hasLength(1));
    expect(auth.calls, isNot(contains('deleteAccount')));
    expect(find.text('Profile & Settings'), findsOneWidget);
  });

  testWidgets('a blank password is asked for', (tester) async {
    final (repository, auth, _) = await openSettings(tester);
    await confirm(tester);
    expect(
      find.text('Enter your password to delete your account.'),
      findsOneWidget,
    );
    expect(auth.calls, isNot(contains('reauthenticate')));
    expect(await repository.getPets(), hasLength(1));
  });

  testWidgets('the right password deletes data, records and the account', (
    tester,
  ) async {
    final (repository, auth, onboarding) = await openSettings(tester);
    await tester.enterText(find.byType(TextField), 'right-password');
    await confirm(tester);

    expect(auth.calls, containsAllInOrder(['reauthenticate', 'deleteAccount']));
    expect(await repository.getPets(), isEmpty);
    expect(onboarding.deletedRecords, ['del-user']);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsNothing);
  });

  testWidgets('Google accounts confirm without a password field', (
    tester,
  ) async {
    final (_, auth, _) = await openSettings(tester, passwordAccount: false);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('You will confirm with Google first.'), findsOneWidget);
    await confirm(tester);
    expect(auth.calls, containsAllInOrder(['reauthenticate', 'deleteAccount']));
  });

  test('the profile and onboarding documents are deleted', () async {
    final firestore = FakeFirebaseFirestore();
    final profile = FirestoreAccountProfileRepository(firestore: firestore);
    final onboarding = FirestoreAccountOnboardingRepository(
      firestore: firestore,
    );
    await profile.setDisplayName('alice', 'Jo');
    await onboarding.markFirstPetRequired('alice');

    await profile.deleteProfile('alice');
    await onboarding.deleteAccountRecord('alice');

    expect(await profile.getDisplayName('alice'), isNull);
    expect(
      (await firestore.collection('accountMetadata').doc('alice').get()).exists,
      isFalse,
    );
  });
}
