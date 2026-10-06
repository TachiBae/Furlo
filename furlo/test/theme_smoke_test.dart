import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
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
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/health/health_records_screen.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:furlo/screens/settings/notifications_screen.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'helpers/fake_auth_service.dart';
import 'helpers/fake_account_onboarding_repository.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved light and dark choices are applied on first app frame', (
    tester,
  ) async {
    for (final choice in [AppThemeChoice.light, AppThemeChoice.dark]) {
      SharedPreferences.setMockInitialValues({
        ThemeSettings.preferenceKey: choice.name,
      });
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await tester.pumpWidget(
        FurloApp(
          repository: repository,
          notificationService: const NoOpNotificationService(),
          accountOnboardingRepository: FakeAccountOnboardingRepository(),
          authService: FakeAuthService(
            initialUser: const AuthUser(
              uid: 'theme-test-user',
              email: 'theme@example.test',
              displayName: null,
            ),
          ),
        ),
      );
      await tester.pump();
      final materialApps = tester.widgetList<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(
        materialApps.first.theme!.brightness,
        choice == AppThemeChoice.light ? Brightness.light : Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('requested screens build in both themes at phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
      final pets = await repository.getPets();
      final pet = pets.single;
      await repository.addFeedingSchedule(
        FeedingEntry(petId: '1', name: 'Breakfast', time: '08:00'),
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
          title: 'Checkup',
          date: DateTime(2026, 1, 1),
          type: HealthRecordTypes.checkup,
        ),
      );
      await repository.addVet(Vet(name: 'Dr. Lee', phone: '555-0100'), ['1']);
      final vet = (await repository.getAllVets()).single;
      await repository.addWeightLog(
        WeightLog(petId: '1', date: DateTime(2026, 1, 1), weight: 8.2),
      );
      final state = FurloState(repository);
      await state.load();
      final notifications = SharedPreferencesNotificationSettingsRepository();
      final settings = ThemeSettings();
      await settings.setThemeMode(
        theme.brightness == Brightness.light
            ? AppThemeChoice.light
            : AppThemeChoice.dark,
      );

      final screens = <Widget>[
        OnboardingScreen(
          repository: repository,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
        ChangeNotifierProvider.value(
          value: state,
          child: HomeScreen(
            repository: repository,
            notificationSettings: notifications,
            notificationService: const NoOpNotificationService(),
          ),
        ),
        ChangeNotifierProvider.value(
          value: state,
          child: PetProfileScreen(petId: '1', repository: repository),
        ),
        ChangeNotifierProvider.value(
          value: state,
          child: FeedingScreen(repository: repository),
        ),
        VaccinationScreen(repository: repository, pets: pets, selectedPet: pet),
        HealthRecordsScreen(
          repository: repository,
          pets: pets,
          selectedPet: pet,
        ),
        ChangeNotifierProvider.value(
          value: state,
          child: VetContactsScreen(repository: repository),
        ),
        VetDetailsScreen(repository: repository, vet: vet),
        WeightTrackingScreen(
          repository: repository,
          pets: pets,
          selectedPet: pet,
        ),
        NotificationsScreen(
          settings: notifications,
          service: const NoOpNotificationService(),
        ),
        NotificationSettingsScreen(
          settings: notifications,
          service: const NoOpNotificationService(),
        ),
        ChangeNotifierProvider.value(
          value: settings,
          child: ProfileScreen(
            repository: repository,
            appSettings: SharedPreferencesAppSettingsRepository(),
            notificationSettings: notifications,
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} in ${theme.brightness}',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      settings.dispose();
    }
  });
}
