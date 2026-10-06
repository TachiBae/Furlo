import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  FurloApp app({
    required AuthService auth,
    required FakeAccountOnboardingRepository onboarding,
    required PetRepository repository,
  }) => FurloApp(
    authService: auth,
    accountOnboardingRepository: onboarding,
    repository: repository,
    notificationService: const NoOpNotificationService(),
  );

  testWidgets('signed out shows the sign-in screen', (tester) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        repository: WebPetRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text('Cloud setup is missing or failed to start.'),
      findsNothing,
    );
  });

  testWidgets('existing user with pets goes straight to the dashboard', (
    tester,
  ) async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'returning-with-pet',
        email: 'returning@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text("Track Your Pet's Care"), findsNothing);
  });

  testWidgets('existing account with no pets goes to dashboard add-pet state', (
    tester,
  ) async {
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'returning-no-pet',
        email: 'returning@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        repository: WebPetRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text("Track Your Pet's Care"), findsNothing);
    expect(
      find.text('Add a pet to start keeping their care in one place.'),
      findsOneWidget,
    );
  });

  testWidgets('new account first sign-in routes to Add Pet', (tester) async {
    final onboarding = FakeAccountOnboardingRepository();
    await onboarding.markFirstPetRequired('new-account');
    final repository = WebPetRepository(storageScope: 'new-account');
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'new-account',
        email: 'new@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      app(auth: auth, onboarding: onboarding, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add New Pet'), findsOneWidget);
    expect(find.text("Track Your Pet's Care"), findsNothing);
  });

  testWidgets(
    'saving first pet clears account marker and later sign-in opens dashboard',
    (tester) async {
      final onboarding = FakeAccountOnboardingRepository();
      await onboarding.markFirstPetRequired('new-account');
      final repository = WebPetRepository(storageScope: 'new-account');
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: 'new-account',
          email: 'new@example.test',
          displayName: null,
        ),
      );
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        app(auth: auth, onboarding: onboarding, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Pip');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dog').last);
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 6 && find.text('Save Pet').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(find.text('Save Pet'), findsOneWidget);
      await tester.tap(find.text('Save Pet'));
      await tester.pumpAndSettle();

      expect(await onboarding.requiresFirstPet('new-account'), isFalse);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add New Pet'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(auth: auth, onboarding: onboarding, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add New Pet'), findsNothing);
    },
  );

  testWidgets('sign-out returns an existing account to sign-in', (
    tester,
  ) async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'auth-gate-user',
        email: 'auth-gate@example.test',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(
        auth: auth,
        onboarding: FakeAccountOnboardingRepository(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
  });

  testWidgets(
    'different users get isolated repositories and onboarding state',
    (tester) async {
      final onboarding = FakeAccountOnboardingRepository();
      await onboarding.markFirstPetRequired('alice');
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: 'alice',
          email: null,
          displayName: null,
        ),
      );
      final repositories = <String, WebPetRepository>{};
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        FurloApp(
          authService: auth,
          accountOnboardingRepository: onboarding,
          repositoryFactory: (uid) => repositories.putIfAbsent(
            uid,
            () => WebPetRepository(storageScope: uid),
          ),
          notificationService: const NoOpNotificationService(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add New Pet'), findsOneWidget);

      auth.setUser(const AuthUser(uid: 'bob', email: null, displayName: null));
      await tester.pumpAndSettle();
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(await repositories['bob']!.getPets(), isEmpty);
      expect(find.text('Add New Pet'), findsNothing);
    },
  );

  testWidgets('Firebase initialization error shows only fixed message', (
    tester,
  ) async {
    const rawError = 'private firebase failure details';
    final auth = FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        authService: auth,
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        firebaseInitError: rawError,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cloud setup is missing or failed to start.'),
      findsOneWidget,
    );
    expect(find.text(rawError), findsNothing);
  });
}
