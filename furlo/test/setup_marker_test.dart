import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

/// Profile marker store each test drives directly.
class _SetupMarkerRepository implements AccountProfileRepository {
  @override
  Future<void> deleteProfile(String uid) async {}

  @override
  Future<String?> getDisplayName(String uid) async => null;

  @override
  Future<void> setDisplayName(String uid, String displayName) async {}

  _SetupMarkerRepository({this.setupComplete = false});

  bool setupComplete;
  bool failNextSetupWrite = false;
  int setupWriteCalls = 0;

  @override
  Future<bool> requiresProfileCompletion(String uid) async => false;

  @override
  Future<void> markProfileRequired(String uid) async {}

  @override
  Future<void> completeProfile(
    String uid, {
    required String fullName,
    required String displayName,
  }) async {}

  @override
  Future<bool> isSetupComplete(String uid) async => setupComplete;

  @override
  Future<void> markSetupComplete(String uid) async {
    if (failNextSetupWrite) {
      failNextSetupWrite = false;
      throw StateError('setup marker write offline');
    }
    setupWriteCalls++;
    setupComplete = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const uid = 'test-user';

  FurloApp app({
    required FakeAuthService auth,
    required FakeAccountOnboardingRepository onboarding,
    required _SetupMarkerRepository profile,
    required PetRepository repository,
  }) => FurloApp(
    authService: auth,
    accountOnboardingRepository: onboarding,
    accountProfileRepository: profile,
    repository: repository,
    notificationService: const NoOpNotificationService(),
  );

  testWidgets('a new account with no pets goes to onboarding', (tester) async {
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: uid,
        email: 'person@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        profile: _SetupMarkerRepository(),
        repository: WebPetRepository(storageScope: uid),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Pet'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
  });

  testWidgets(
    'an account whose first-pet setup write failed goes to onboarding on the next launch',
    (tester) async {
      final onboarding = FakeAccountOnboardingRepository();
      final profile = _SetupMarkerRepository();
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: uid,
          email: 'person@example.test',
          displayName: null,
        ),
      );
      addTearDown(auth.dispose);

      // First launch: the account saved its first pet, but the marker write
      // failed after it, the way a dropped connection leaves setup unfinished.
      profile.failNextSetupWrite = true;
      await tester.pumpWidget(
        app(
          auth: auth,
          onboarding: onboarding,
          profile: profile,
          repository: WebPetRepository(storageScope: uid),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Pet'), findsOneWidget);

      // Second launch with the same account state: onboarding again, not the
      // dashboard's empty state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(
          auth: auth,
          onboarding: onboarding,
          profile: profile,
          repository: WebPetRepository(storageScope: uid),
        ),
      );
      await tester.pumpAndSettle();

      expect(profile.setupComplete, isFalse);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Add Pet'),
        ),
        findsOneWidget,
        reason: 'the onboarding screen owns the Add pet app bar title',
      );
      expect(find.text('Quick Actions'), findsNothing);
    },
  );

  testWidgets('an established account with zero pets stays on Home', (
    tester,
  ) async {
    final repository = WebPetRepository(storageScope: uid);
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final profile = _SetupMarkerRepository(setupComplete: true);
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: uid,
        email: 'person@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        profile: profile,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);

    // The owner deletes every pet; the marker still says setup finished.
    await repository.deletePet((await repository.getPets()).first.id!);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        profile: profile,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(await repository.getPets(), isEmpty);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Add Pet')),
      findsNothing,
    );
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(
      find.text('Add a pet to start keeping their care in one place.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'an account with pets is never sent to onboarding by a missing marker',
    (tester) async {
      final repository = WebPetRepository(storageScope: uid);
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      final profile = _SetupMarkerRepository();
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: uid,
          email: 'person@example.test',
          displayName: null,
        ),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        app(
          auth: auth,
          onboarding: FakeAccountOnboardingRepository(),
          profile: profile,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(profile.setupComplete, isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Add Pet'),
        ),
        findsNothing,
      );
      expect(find.text('Quick Actions'), findsOneWidget);
    },
  );
}
