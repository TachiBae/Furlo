import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/user_storage_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

const _dialogTitle = 'Import pets from this device?';
const _legacyPetId = 'legacy-1';
const _oldPhoto = 'data:image/png;base64,OLDDEVICEPHOTO';

/// The consent dialog, found through its AlertDialog so the finders cannot
/// collide with other screens' text.
Finder _consentDialog() => find.byType(AlertDialog);
Finder _inDialog(String text) =>
    find.descendant(of: _consentDialog(), matching: find.text(text));

Future<void> _pumpAccount(
  WidgetTester tester, {
  required String uid,
  required WebPetRepository accountStore,
}) async {
  final auth = FakeAuthService(
    initialUser: AuthUser(
      uid: uid,
      email: '$uid@example.test',
      displayName: null,
    ),
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    FurloApp(
      repository: accountStore,
      legacyConsentEnabled: true,
      notificationService: const NoOpNotificationService(),
      accountOnboardingRepository: FakeAccountOnboardingRepository(),
      authService: auth,
    ),
  );
  await tester.pumpAndSettle();
}

/// Simulates ending one launch before the next: a real relaunch tears the
/// whole tree down, and pumping a second FurloApp over the first would share
/// its element tree and session state.
Future<void> _relaunch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

/// Writes a pet (and optionally a photo) into the device-wide, pre-account
/// store — the data H-001 is about.
Future<void> _seedDeviceData({bool withPhoto = false}) async {
  if (withPhoto) {
    SharedPreferences.setMockInitialValues({
      'photo.pet.$_legacyPetId': _oldPhoto,
    });
  }
  final deviceStore = WebPetRepository();
  await deviceStore.addPet(Pet(id: _legacyPetId, name: 'Rex', species: 'Dog'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('legacy import consent (H-001)', () {
    testWidgets('no legacy data means no dialog', (tester) async {
      await _pumpAccount(
        tester,
        uid: 'user-a',
        accountStore: WebPetRepository(storageScope: 'user-a'),
      );

      expect(_consentDialog(), findsNothing);
    });

    testWidgets('legacy data and Import imports it once', (tester) async {
      await _seedDeviceData(withPhoto: true);
      final accountStore = WebPetRepository(storageScope: 'user-a');

      await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
      expect(_consentDialog(), findsOneWidget);
      expect(_inDialog(_dialogTitle), findsOneWidget);

      await tester.tap(_inDialog('Import'));
      await tester.pumpAndSettle();

      expect(_consentDialog(), findsNothing);
      expect(await accountStore.getPets(), hasLength(1));
      expect((await accountStore.getPets()).single.name, 'Rex');
      // Device data survives the copy untouched.
      expect(await WebPetRepository().getPets(), hasLength(1));
      // Consent given: the imported pet's old photo resolves for this account.
      final photo = await LocalPetPhotoStore(
        storageScope: 'user-a',
      ).read(_legacyPetId);
      expect(photo, _oldPhoto);

      // Second launch for the same account: no question, no duplicate copy.
      await _relaunch(tester);
      await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
      expect(_consentDialog(), findsNothing);
      expect(await accountStore.getPets(), hasLength(1));
    });

    testWidgets('Not now imports nothing and keeps the old data', (
      tester,
    ) async {
      await _seedDeviceData();
      final accountStore = WebPetRepository(storageScope: 'user-a');

      await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
      expect(_consentDialog(), findsOneWidget);

      await tester.tap(_inDialog('Not now'));
      await tester.pumpAndSettle();

      expect(_consentDialog(), findsNothing);
      expect(await accountStore.getPets(), isEmpty);
      // The old data is neither imported nor deleted.
      expect(await WebPetRepository().getPets(), hasLength(1));
    });

    testWidgets('the answer is remembered per account', (tester) async {
      await _seedDeviceData();
      final accountStore = WebPetRepository(storageScope: 'user-a');

      await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
      await tester.tap(_inDialog('Not now'));
      await tester.pumpAndSettle();

      // Relaunch: the same account is never asked twice…
      await _relaunch(tester);
      await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
      expect(_consentDialog(), findsNothing);
      // …and it still imported nothing.
      expect(await accountStore.getPets(), isEmpty);
      expect(await WebPetRepository().getPets(), hasLength(1));
    });

    testWidgets('a second account gets its own question', (tester) async {
      await _seedDeviceData();
      final storeA = WebPetRepository(storageScope: 'user-a');
      final storeB = WebPetRepository(storageScope: 'user-b');

      await _pumpAccount(tester, uid: 'user-a', accountStore: storeA);
      await tester.tap(_inDialog('Not now'));
      await tester.pumpAndSettle();
      expect(_consentDialog(), findsNothing);

      // A different account on the same device is asked fresh — it neither
      // inherits A's answer nor A's data.
      await _relaunch(tester);
      await _pumpAccount(tester, uid: 'user-b', accountStore: storeB);
      expect(_consentDialog(), findsOneWidget);

      await tester.tap(_inDialog('Import'));
      await tester.pumpAndSettle();

      expect(await storeB.getPets(), hasLength(1));
      expect(await storeA.getPets(), isEmpty);
      expect(await WebPetRepository().getPets(), hasLength(1));
    });

    testWidgets(
      "a new account's pet never picks up an old photo without Import",
      (tester) async {
        await _seedDeviceData(withPhoto: true);
        final accountStore = WebPetRepository(storageScope: 'user-a');

        await _pumpAccount(tester, uid: 'user-a', accountStore: accountStore);
        await tester.tap(_inDialog('Not now'));
        await tester.pumpAndSettle();

        // Nothing from the device entered the account…
        expect(await accountStore.getPets(), isEmpty);
        final preferences = await SharedPreferences.getInstance();
        final scopedLegacyPhotoKey =
            'photo.user.${userStorageScopeToken('user-a')}.pet.$_legacyPetId';
        expect(preferences.getString(scopedLegacyPhotoKey), isNull);

        // …so a pet the account creates itself cannot display the old photo.
        await accountStore.addPet(Pet(name: 'Newbie', species: 'Cat'));
        final created = (await accountStore.getPets()).single;
        final photo = await LocalPetPhotoStore(
          storageScope: 'user-a',
        ).read(created.id!);
        expect(photo, isNull);
        // The device-wide photo key is still there, untouched, for an
        // account that chooses Import later.
        expect(preferences.getString('photo.pet.$_legacyPetId'), _oldPhoto);
      },
    );
  });
}
