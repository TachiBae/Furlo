import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/providers/session_controller.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

const _alice = AuthUser(uid: 'alice', email: 'a@x.test', displayName: null);
const _bob = AuthUser(uid: 'bob', email: 'b@x.test', displayName: null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  (SessionController, FakeAuthService, List<FurloState?>) build({
    AuthUser? user,
  }) {
    final auth = FakeAuthService(initialUser: user);
    final published = <FurloState?>[];
    final session = SessionController(
      authService: auth,
      accountOnboardingRepository: FakeAccountOnboardingRepository(),
      accountProfileRepository: null,
      firebaseInitError: null,
      repositoryOverride: null,
      repositoryFactory: (scope) => WebPetRepository(storageScope: scope),
      notificationServiceOverride: const NoOpNotificationService(),
      legacyConsentEnabled: false,
      onFurloState: published.add,
    );
    addTearDown(session.dispose);
    addTearDown(auth.dispose);
    return (session, auth, published);
  }

  test('a backend that failed to start cannot start a session', () {
    final session = SessionController(
      authService: null,
      accountOnboardingRepository: null,
      accountProfileRepository: null,
      firebaseInitError: 'boom',
      repositoryOverride: null,
      repositoryFactory: null,
      notificationServiceOverride: null,
      legacyConsentEnabled: null,
      onFurloState: (_) {},
    );
    addTearDown(session.dispose);
    expect(session.cannotStart, isTrue);
    expect(session.isLoading, isFalse);
  });

  test(
    'signing in builds that account\'s stores and loads its status',
    () async {
      final (session, auth, published) = build();
      auth.setUser(_alice);
      await pumpEventQueue();

      expect(session.user?.uid, 'alice');
      expect(session.repository, isA<WebPetRepository>());
      expect((session.repository! as WebPetRepository).storageScope, 'alice');
      expect(session.accountStatusLoaded, isTrue);
      expect(published.single, same(session.furloState));
    },
  );

  test('switching accounts starts a fresh session for the new one', () async {
    final (session, auth, published) = build(user: _alice);
    await pumpEventQueue();
    await session.repository!.addPet(
      Pet(id: '1', name: 'Mochi', species: 'Cat'),
    );
    final aliceGeneration = session.sessionGeneration;
    final aliceState = session.furloState;

    auth.setUser(_bob);
    await pumpEventQueue();

    expect(session.user?.uid, 'bob');
    expect(session.sessionGeneration, greaterThan(aliceGeneration));
    expect(session.furloState, isNot(same(aliceState)));
    expect(await session.repository!.getPets(), isEmpty); // Bob's own store
    expect(published, contains(null)); // the old state was withdrawn
  });

  test('signing out clears the session', () async {
    final (session, auth, _) = build(user: _alice);
    await pumpEventQueue();
    auth.setUser(null);
    await pumpEventQueue();
    expect(session.user, isNull);
    expect(session.repository, isNull);
    expect(session.furloState, isNull);
  });
}
