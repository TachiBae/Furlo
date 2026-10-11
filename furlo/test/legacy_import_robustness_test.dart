import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/home_reminders_provider.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

const _importFailedMessage = 'The import could not finish. Please try again.';

Finder _consentDialog() => find.byType(AlertDialog);
Finder _inDialog(String text) =>
    find.descendant(of: _consentDialog(), matching: find.text(text));

/// A relaunch tears the tree down first: pumping a second FurloApp over the
/// first shares element and session state (same helper as the consent tests).
Future<void> _relaunch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

/// Device-wide, pre-account data: two pets, one with a feeding.
Future<void> _seedDeviceData() async {
  final deviceStore = WebPetRepository();
  await deviceStore.addPet(Pet(id: 'legacy-1', name: 'Rex', species: 'Dog'));
  await deviceStore.addFeedingSchedule(
    FeedingEntry(petId: 'legacy-1', name: 'Breakfast', time: '08:00'),
  );
  await deviceStore.addPet(Pet(id: 'legacy-2', name: 'Mochi', species: 'Cat'));
}

FakeAuthService _authFor(String uid) => FakeAuthService(
  initialUser: AuthUser(
    uid: uid,
    email: '$uid@example.test',
    displayName: null,
  ),
);

Future<void> _pumpAccount(
  WidgetTester tester, {
  required FakeAuthService auth,
  required PetRepository store,
}) async {
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    FurloApp(
      repository: store,
      legacyConsentEnabled: true,
      notificationService: const NoOpNotificationService(),
      accountOnboardingRepository: FakeAccountOnboardingRepository(),
      authService: auth,
    ),
  );
  await tester.pumpAndSettle();
}

/// Account target whose `addPet` throws on the configured call, staging a
/// failed import — once mid-copy (call 2, after the first pet landed) or
/// before anything is written (call 1).
class _FlakyTarget extends WebPetRepository {
  _FlakyTarget({super.storageScope, this.failOnCall});

  final int? failOnCall;
  int addPetCalls = 0;

  @override
  Future<void> addPet(Pet pet) async {
    addPetCalls += 1;
    if (addPetCalls == failOnCall) throw StateError('offline');
    return super.addPet(pet);
  }
}

/// Reminders store whose first feeding read never answers on its own, so the
/// load can still be pending when the provider is disposed.
class _HangingFeedingsRepository extends WebPetRepository {
  final feedings = Completer<List<FeedingEntry>>();
  int _calls = 0;

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) {
    if (_calls++ == 0) return feedings.future;
    return super.getFeedingSchedules(petId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('consent dialog session binding (Gap 1)', () {
    testWidgets(
      'a session switch while the dialog is open saves nothing for either account',
      (tester) async {
        await _seedDeviceData();
        final auth = _authFor('user-a');
        await _pumpAccount(
          tester,
          auth: auth,
          store: WebPetRepository(storageScope: 'user-a'),
        );
        expect(_consentDialog(), findsOneWidget);

        // The signed-in account changes while the question is on screen.
        auth.setUser(
          const AuthUser(
            uid: 'user-b',
            email: 'user-b@example.test',
            displayName: null,
          ),
        );
        await tester.pumpAndSettle();

        final settingsA = SharedPreferencesAppSettingsRepository(
          storageScope: 'user-a',
        );
        final settingsB = SharedPreferencesAppSettingsRepository(
          storageScope: 'user-b',
        );
        // Nothing was answered for the old or the new account…
        expect(await settingsA.getLegacyImportChoice(), isNull);
        expect(await settingsB.getLegacyImportChoice(), isNull);
        // …the orphaned question was closed rather than left stacked (exactly
        // one dialog: the new account's own question)…
        expect(_consentDialog(), findsOneWidget);
        // …and answering it records only under the new account.
        await tester.tap(_inDialog('Not now'));
        await tester.pumpAndSettle();
        expect(await settingsA.getLegacyImportChoice(), isNull);
        expect(
          await settingsB.getLegacyImportChoice(),
          SharedPreferencesAppSettingsRepository.legacyImportDeclined,
        );
      },
    );
  });

  group('reminders provider dispose guard (Gap 2)', () {
    test('dispose with a pending load never notifies or throws', () async {
      final repository = _HangingFeedingsRepository();
      final provider = HomeRemindersProvider(repository);
      final pending = provider.refresh(
        pets: [Pet(id: '1', name: 'Mochi', species: 'Dog')],
      );

      provider.dispose();
      repository.feedings.complete([]);

      // Before the disposed guard this threw "A HomeRemindersProvider was
      // used after being disposed" from refresh's finally. State writes are
      // deliberately skipped on the dead object; only the throw matters.
      await pending;
    });
  });

  group('failed Import (Gap 3)', () {
    testWidgets(
      'a failure midway leaves the account unanswered and a retry imports once',
      (tester) async {
        await _seedDeviceData();
        final target = _FlakyTarget(storageScope: 'user-a', failOnCall: 2);
        final settings = SharedPreferencesAppSettingsRepository(
          storageScope: 'user-a',
        );
        await _pumpAccount(tester, auth: _authFor('user-a'), store: target);
        expect(_consentDialog(), findsOneWidget);

        // First attempt dies while adding the second pet: one pet landed.
        await tester.tap(_inDialog('Import'));
        await tester.pumpAndSettle();

        expect(await settings.getLegacyImportChoice(), isNull);
        expect(await settings.isLegacyImportInProgress(), isTrue);
        expect(_consentDialog(), findsOneWidget);
        expect(find.text(_importFailedMessage), findsOneWidget);
        expect(await target.getPets(), hasLength(1));
        // Flush the snackbar's auto-dismiss timer before continuing.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Retry resumes the same copy and finishes exactly once.
        await tester.tap(_inDialog('Import'));
        await tester.pumpAndSettle();

        expect(_consentDialog(), findsNothing);
        expect(
          await settings.getLegacyImportChoice(),
          SharedPreferencesAppSettingsRepository.legacyImportApproved,
        );
        expect(await settings.isLegacyImportInProgress(), isFalse);
        final pets = await target.getPets();
        expect(pets, hasLength(2));
        expect(pets.map((pet) => pet.id).toSet(), hasLength(2));
        expect(await target.getFeedingSchedules('legacy-1'), hasLength(1));

        // Relaunch after success: no new question, no duplicates.
        await _relaunch(tester);
        await _pumpAccount(tester, auth: _authFor('user-a'), store: target);
        expect(_consentDialog(), findsNothing);
        expect(await target.getPets(), hasLength(2));
        expect(await target.getFeedingSchedules('legacy-1'), hasLength(1));
      },
    );

    testWidgets('the answer is saved only after a successful Import', (
      tester,
    ) async {
      await _seedDeviceData();
      final target = _FlakyTarget(storageScope: 'user-a', failOnCall: 1);
      final settings = SharedPreferencesAppSettingsRepository(
        storageScope: 'user-a',
      );
      await _pumpAccount(tester, auth: _authFor('user-a'), store: target);

      // Fails before writing anything: still unanswered, nothing imported.
      await tester.tap(_inDialog('Import'));
      await tester.pumpAndSettle();
      expect(await settings.getLegacyImportChoice(), isNull);
      expect(await target.getPets(), isEmpty);
      expect(_consentDialog(), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // The successful attempt is what records the answer.
      await tester.tap(_inDialog('Import'));
      await tester.pumpAndSettle();
      expect(_consentDialog(), findsNothing);
      expect(
        await settings.getLegacyImportChoice(),
        SharedPreferencesAppSettingsRepository.legacyImportApproved,
      );
      expect(await target.getPets(), hasLength(2));
    });
  });
}
