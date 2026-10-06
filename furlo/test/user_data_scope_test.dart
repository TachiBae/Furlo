import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/user_storage_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_auth_service.dart';
import 'helpers/fake_account_onboarding_repository.dart';

class _FakeNotificationService implements NotificationService {
  bool cancelledAll = false;
  int clearScheduledCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> schedule(
    String type,
    String id,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {}

  @override
  Future<void> cancel(String type, String id) async {}

  @override
  Future<void> cancelAllOfType(String type) async {}

  @override
  Future<void> rescheduleAll() async {
    cancelledAll = true;
  }

  @override
  Future<void> clearScheduled() async {
    clearScheduledCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'each user owns a separate store while legacy records remain untouched',
    () async {
      final legacy = WebPetRepository();
      await legacy.addPet(Pet(id: '1', name: 'Legacy pet', species: 'Cat'));
      await legacy.addFeedingSchedule(
        FeedingEntry(petId: '1', name: 'Legacy meal', time: '08:00'),
      );
      await legacy.addVaccination(
        Vaccination(petId: '1', vaccineName: 'Legacy vaccine'),
      );
      await legacy.addHealthRecord(
        HealthRecord(petId: '1', title: 'Legacy visit', type: 'Checkup'),
      );
      await legacy.addWeightLog(
        WeightLog(petId: '1', date: DateTime(2026), weight: 4.0),
      );
      await legacy.addVet(Vet(name: 'Legacy vet', phone: '5550100'), ['1']);

      final alice = WebPetRepository(storageScope: 'firebase:alice');
      final bob = WebPetRepository(storageScope: 'firebase:bob');
      await alice.addPet(Pet(id: '1', name: 'Alice pet', species: 'Dog'));
      await alice.addFeedingSchedule(
        FeedingEntry(petId: '1', name: 'Alice meal', time: '09:00'),
      );
      await alice.addVaccination(
        Vaccination(petId: '1', vaccineName: 'Alice vaccine'),
      );
      await alice.addHealthRecord(
        HealthRecord(petId: '1', title: 'Alice visit', type: 'Checkup'),
      );
      await alice.addWeightLog(
        WeightLog(petId: '1', date: DateTime(2026), weight: 8.0),
      );
      await alice.addVet(Vet(name: 'Alice vet', phone: '5550111'), ['1']);

      expect((await alice.getPets()).single.name, 'Alice pet');
      expect(await bob.getPets(), isEmpty);
      expect((await bob.getFeedingSchedules('1')), isEmpty);
      expect(await bob.getVaccinationsForPet('1'), isEmpty);
      expect(await bob.getHealthRecordsForPet('1'), isEmpty);
      expect(await bob.getWeightLogsForPet('1'), isEmpty);
      expect(await bob.getAllVets(), isEmpty);

      await alice.clearAllData();
      expect(await alice.getPets(), isEmpty);
      expect((await legacy.getPets()).single.name, 'Legacy pet');
      expect(
        (await legacy.getFeedingSchedules('1')).single.name,
        'Legacy meal',
      );
      expect(
        (await legacy.getVaccinationsForPet('1')).single.vaccineName,
        'Legacy vaccine',
      );
      expect(
        (await legacy.getHealthRecordsForPet('1')).single.title,
        'Legacy visit',
      );
      expect((await legacy.getWeightLogsForPet('1')).single.weight, 4.0);
      expect((await legacy.getAllVets()).single.name, 'Legacy vet');
    },
  );

  test(
    'notification settings and profile display names are UID-specific',
    () async {
      SharedPreferences.setMockInitialValues({
        'notification.enabled.daily_feeding': false,
        'notification.permission_requested': true,
        'profile.display_name': 'Legacy display name',
      });
      final legacy = SharedPreferencesNotificationSettingsRepository();
      final alice = SharedPreferencesNotificationSettingsRepository(
        storageScope: 'firebase:alice',
      );
      final bob = SharedPreferencesNotificationSettingsRepository(
        storageScope: 'firebase:bob',
      );
      final legacySettings = SharedPreferencesNotificationSettingsRepository();
      final aliceProfile = SharedPreferencesAppSettingsRepository(
        storageScope: 'firebase:alice',
      );
      final bobProfile = SharedPreferencesAppSettingsRepository(
        storageScope: 'firebase:bob',
      );
      final legacyProfile = SharedPreferencesAppSettingsRepository();

      expect(await legacy.isEnabled(NotificationTypes.dailyFeeding), isFalse);
      expect(await alice.isEnabled(NotificationTypes.dailyFeeding), isTrue);
      expect(await alice.permissionWasRequested(), isFalse);
      await alice.setEnabled(NotificationTypes.dailyFeeding, false);
      await alice.markPermissionRequested();
      await aliceProfile.setDisplayName('Alice');

      expect(await bob.isEnabled(NotificationTypes.dailyFeeding), isTrue);
      expect(await bob.permissionWasRequested(), isFalse);
      expect(await bobProfile.getDisplayName(), isEmpty);
      expect(await aliceProfile.getDisplayName(), 'Alice');
      expect(await legacyProfile.getDisplayName(), 'Legacy display name');
      expect(
        await legacySettings.isEnabled(NotificationTypes.dailyFeeding),
        isFalse,
      );
      expect(await legacySettings.permissionWasRequested(), isTrue);

      await alice.clearAll();
      await aliceProfile.clearDisplayName();
      expect(await alice.isEnabled(NotificationTypes.dailyFeeding), isTrue);
      expect(await bob.isEnabled(NotificationTypes.dailyFeeding), isTrue);
      expect(await bobProfile.getDisplayName(), isEmpty);
      expect(await legacy.isEnabled(NotificationTypes.dailyFeeding), isFalse);
      expect(await legacy.permissionWasRequested(), isTrue);
      expect(await legacyProfile.getDisplayName(), 'Legacy display name');
    },
  );

  test('notification ownership distinguishes legacy and scoped payloads', () {
    const aliceUid = 'private-alice-uid';
    final aliceToken = userStorageScopeToken(aliceUid);
    final alicePayload = '$aliceToken|feeding|42';
    const bobPayload = 'different-token|feeding|42';
    const legacyPayload = 'feeding|42';

    expect(
      notificationPayloadIsOwnedByScope(alicePayload, storageScope: aliceUid),
      isTrue,
    );
    expect(
      notificationPayloadIsOwnedByScope(bobPayload, storageScope: aliceUid),
      isFalse,
    );
    expect(notificationPayloadIsOwnedByScope(legacyPayload), isTrue);
    expect(notificationPayloadIsOwnedByScope(alicePayload), isFalse);
  });

  test(
    'scoped notification IDs differ and scope tokens do not contain the UID',
    () {
      final alice = stableNotificationId(
        'feeding',
        42,
        scope: 'private-alice-uid',
      );
      final bob = stableNotificationId('feeding', 42, scope: 'private-bob-uid');
      expect(alice, greaterThan(0));
      expect(alice, isNot(bob));
      expect(
        userStorageScopeToken('private-alice-uid'),
        isNot(contains('private-alice-uid')),
      );
    },
  );

  testWidgets('auth UID changes rebuild the local data namespace', (
    tester,
  ) async {
    final stores = <String, WebPetRepository>{};
    final alice = WebPetRepository(storageScope: 'firebase:alice');
    stores['alice'] = alice;
    await alice.addPet(Pet(name: 'Alice pet', species: 'Dog'));
    final notificationService = _FakeNotificationService();
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'alice',
        email: 'alice@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FurloApp(
        authService: auth,
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        repositoryFactory: (uid) => stores.putIfAbsent(
          uid,
          () => WebPetRepository(storageScope: 'firebase:$uid'),
        ),
        notificationService: notificationService,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice pet'), findsOneWidget);
    expect((await alice.getPets()).single.name, 'Alice pet');

    auth.setUser(
      const AuthUser(uid: 'bob', email: 'bob@example.test', displayName: null),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(
      find.text('Add a pet to start keeping their care in one place.'),
      findsOneWidget,
    );
    expect(find.text('Alice pet'), findsNothing);
    expect(await stores['bob']!.getPets(), isEmpty);

    auth.setUser(
      const AuthUser(
        uid: 'alice',
        email: 'alice@example.test',
        displayName: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice pet'), findsOneWidget);
    expect(notificationService.clearScheduledCalls, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(notificationService.clearScheduledCalls, greaterThan(0));
  });
}
