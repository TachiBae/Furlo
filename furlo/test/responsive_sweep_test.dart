import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/health_record_types.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/auth/create_account_screen.dart';
import 'package:furlo/screens/auth/forgot_password_screen.dart';
import 'package:furlo/screens/auth/sign_in_screen.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/health/health_records_screen.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/pets/pet_form_screen.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:furlo/screens/settings/notifications_screen.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_service.dart';

/// Responsive sweep: every screen at every supported width and text scale.
///
/// Both predecessor audits left runtime layout unverified because the shared
/// browser could not reach authenticated screens. This closes that gap in the
/// test runner instead, which can drive every screen deterministically.
///
/// A screen that overflows raises through `takeException`, so the assertion
/// below fails with the offending screen, viewport and text scale named.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Viewports the app is expected to hold together at. 375 is the narrow
  // phone the graded web build is previewed at; 1440 is the wide desktop.
  const viewports = <String, Size>{
    'phone 375x667': Size(375, 667),
    'tablet 768x1024': Size(768, 1024),
    'desktop 1440x900': Size(1440, 900),
  };
  const textScales = <double>[1.0, 1.3, 2.0];

  Future<Map<String, Widget>> buildScreens() async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    await repository.addPet(Pet(id: '2', name: 'Miso', species: 'Cat'));
    final pets = await repository.getPets();
    final pet = pets.first;
    await repository.addFeedingSchedule(
      FeedingEntry(
        petId: '1',
        name: 'Breakfast',
        time: '08:00',
        frequency: 'Weekly',
        daysOfWeek: const [1, 3, 5],
        portionSize: '1 cup',
      ),
    );
    await repository.addFeedingSchedule(
      FeedingEntry(petId: '1', name: 'Dinner', time: '18:30'),
    );
    await repository.addVaccination(
      Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        dateGiven: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2027, 1, 1),
      ),
    );
    await repository.addHealthRecord(
      HealthRecord(
        petId: '1',
        title: 'Annual checkup',
        date: DateTime(2026, 1, 1),
        type: HealthRecordTypes.checkup,
        notes: 'All good.',
      ),
    );
    await repository.addVet(Vet(name: 'Dr. Lee', phone: '555-0100'), ['1']);
    final vet = (await repository.getAllVets()).single;
    await repository.addWeightLog(
      WeightLog(petId: '1', date: DateTime(2026, 1, 1), weight: 8.2),
    );
    await repository.addWeightLog(
      WeightLog(petId: '1', date: DateTime(2026, 2, 1), weight: 8.6),
    );

    final state = FurloState(repository);
    await state.load();
    final notifications = SharedPreferencesNotificationSettingsRepository();
    final settings = ThemeSettings();
    final auth = FakeAuthService();

    // Named so a failure names the screen a reader would recognise, and so the
    // run doubles as the per-screen grid for the audit's sign-off matrix.
    return <String, Widget>{
      'Home': ChangeNotifierProvider.value(
        value: state,
        child: HomeScreen(
          repository: repository,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
      'Pet profile': ChangeNotifierProvider.value(
        value: state,
        child: PetProfileScreen(petId: '1', repository: repository),
      ),
      'Feeding': ChangeNotifierProvider.value(
        value: state,
        child: FeedingScreen(repository: repository),
      ),
      'Vaccinations': VaccinationScreen(
        repository: repository,
        pets: pets,
        selectedPet: pet,
      ),
      'Health records': HealthRecordsScreen(
        repository: repository,
        pets: pets,
        selectedPet: pet,
      ),
      'Vet contacts': ChangeNotifierProvider.value(
        value: state,
        child: VetContactsScreen(repository: repository),
      ),
      'Vet details': VetDetailsScreen(repository: repository, vet: vet),
      'Weight': WeightTrackingScreen(
        repository: repository,
        pets: pets,
        selectedPet: pet,
      ),
      'Notifications': NotificationsScreen(
        settings: notifications,
        service: const NoOpNotificationService(),
      ),
      'Notification settings': NotificationSettingsScreen(
        settings: notifications,
        service: const NoOpNotificationService(),
      ),
      'Profile': ChangeNotifierProvider.value(
        value: settings,
        child: ProfileScreen(
          repository: repository,
          appSettings: SharedPreferencesAppSettingsRepository(),
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
      'Pet onboarding': OnboardingScreen(
        repository: repository,
        notificationSettings: notifications,
        notificationService: const NoOpNotificationService(),
      ),
      'Sign in': SignInScreen(authService: auth),
      'Create account': CreateAccountScreen(authService: auth),
      'Forgot password': ForgotPasswordScreen(authService: auth),
    };
  }

  for (final viewport in viewports.entries) {
    testWidgets(
      '${viewport.key} holds at 1.0, 1.3 and 2.0 text scale',
      (tester) async {
        tester.view.physicalSize = viewport.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Collect every offender rather than aborting on the first one, so a
        // single run reports the whole overflow set for this viewport.
        final failures = <String>[];
        for (final scale in textScales) {
          SharedPreferences.setMockInitialValues({});
          final screens = await buildScreens();
          for (final entry in screens.entries) {
            final screen = entry.value;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.defaultTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            final exception = tester.takeException();
            if (exception != null) {
              failures.add('${entry.key} @ x$scale: $exception');
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
        expect(
          failures,
          isEmpty,
          reason:
              '${failures.length} screen/scale combinations overflow at '
              '${viewport.key}:\n${failures.join('\n')}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
