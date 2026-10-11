import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/providers/home_reminders_provider.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

/// Pet store whose pet list read fails on demand, so a refresh failure can be
/// staged after data has already been loaded once.
class _FlakyPetRepository extends WebPetRepository {
  bool fail = false;

  @override
  Future<List<Pet>> getPets() async {
    if (fail) throw StateError('offline');
    return super.getPets();
  }
}

/// Feeding store that fails schedule reads until the test flips [fail].
class _ThrowingFeedingRepository extends WebPetRepository {
  bool fail = true;

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async {
    if (fail) throw StateError('offline');
    return super.getFeedingSchedules(petId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('startup gate (H-003)', () {
    Future<void> pumpApp(WidgetTester tester, _FlakyPetRepository repo) async {
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: 'gate-user',
          email: 'person@example.test',
          displayName: null,
        ),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        FurloApp(
          repository: repo,
          notificationService: const NoOpNotificationService(),
          accountOnboardingRepository: FakeAccountOnboardingRepository(),
          authService: auth,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a first-load failure shows the full error with Retry', (
      tester,
    ) async {
      final repo = _FlakyPetRepository()..fail = true;
      await pumpApp(tester, repo);

      expect(find.text('Your pets could not be loaded.'), findsOneWidget);
      expect(
        find.text('Check your connection, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Quick Actions'), findsNothing);

      // The retry recovers once the read works again.
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Your pets could not be loaded.'), findsNothing);
      expect(find.text('Quick Actions'), findsOneWidget);
    });

    testWidgets(
      'a failed refresh keeps the loaded pets visible with a Retry banner',
      (tester) async {
        final repo = _FlakyPetRepository();
        await repo.addPet(Pet(name: 'Mochi', species: 'Dog'));
        await pumpApp(tester, repo);
        // Pets were loaded, so the dashboard is on screen.
        expect(find.text('My Pets'), findsOneWidget);
        expect(find.text('Mochi'), findsWidgets);

        // The next read fails, the way going offline does.
        repo.fail = true;
        final furloState = tester
            .element(find.text('My Pets'))
            .read<FurloState>();
        furloState.load();
        await tester.pumpAndSettle();

        // Loaded data stays; a small banner offers the retry.
        expect(find.text('My Pets'), findsOneWidget);
        expect(find.text('Mochi'), findsWidgets);
        expect(find.text('Your pets could not be refreshed.'), findsOneWidget);
        expect(find.text('Your pets could not be loaded.'), findsNothing);

        // The banner's retry recovers once the read works again.
        repo.fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Your pets could not be refreshed.'), findsNothing);
        expect(find.text('My Pets'), findsOneWidget);
        expect(find.text('Mochi'), findsWidgets);
      },
    );
  });

  group('reminders provider (M-001)', () {
    test('one pet with a null id does not blank the dashboard', () async {
      final repository = WebPetRepository(storageScope: 'm-001');
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      final pets = await repository.getPets();
      final mochiId = pets.single.id;
      expect(mochiId, isNotNull);
      await repository.addFeedingSchedule(
        FeedingEntry(petId: mochiId!, name: 'Breakfast', time: '08:00'),
      );
      // A pet that never reached storage has no id; it must be skipped, not
      // allowed to throw and empty every other pet's reminders.
      final withNullId = <Pet>[...pets, Pet(name: 'Ghost', species: 'Cat')];

      final provider = HomeRemindersProvider(repository);
      addTearDown(provider.dispose);

      await provider.refresh(pets: withNullId);

      expect(provider.hasError, isFalse);
      expect(
        provider.reminders,
        isNotEmpty,
        reason: "Mochi's reminder still reaches the dashboard",
      );
    });
  });

  group('Feeding screen (M-002)', () {
    testWidgets('a failed load shows a working Retry', (tester) async {
      final repository = _ThrowingFeedingRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      final state = FurloState(repository);
      await state.load();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: MaterialApp(
            home: FeedingScreen(repository: repository, storageScope: 'm-002'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Feeding schedules could not be loaded.'),
        findsOneWidget,
      );
      expect(
        find.text('Check your connection, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Feeding schedules could not be loaded.'), findsNothing);
      expect(find.text('No feeding schedules yet'), findsOneWidget);
    });
  });

  group('Pet profile screen (M-003)', () {
    testWidgets('a failed load shows a working Retry', (tester) async {
      final repository = _ThrowingFeedingRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      final pets = await repository.getPets();
      final state = FurloState(repository);
      await state.load();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: MaterialApp(
            home: PetProfileScreen(
              petId: pets.single.id!,
              repository: repository,
              storageScope: 'm-003',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load this pet.'), findsOneWidget);
      expect(
        find.text('Check your connection, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load this pet.'), findsNothing);
      expect(find.text('Mochi'), findsWidgets);
    });
  });
}
