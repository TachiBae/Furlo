import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/health_record_types.dart';
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
import 'package:furlo/providers/theme_settings.dart';

/// Accessibility guards.
///
/// An icon-only control with no tooltip is announced as nothing useful, and a
/// control smaller than 48dp is hard to hit. Both are invisible in a
/// screenshot, so they are asserted here on the rendered tree instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The tap target Flutter's own guidelines ask for.
  const minTapTarget = 48.0;

  Future<Map<String, Widget>> buildScreens() async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    final pet = pets.single;
    await repository.addVaccination(
      Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        dateGiven: DateTime(2026, 1, 1),
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
    await repository.addWeightLog(
      WeightLog(petId: '1', date: DateTime(2026, 1, 1), weight: 8.2),
    );

    final vet = (await repository.getAllVets()).single;

    final state = FurloState(repository);
    await state.load();
    final notifications = SharedPreferencesNotificationSettingsRepository();
    final themeSettings = ThemeSettings();

    // Home renders a first-pet card only when there are no pets, so that
    // branch needs its own state or its controls are never inspected. It also
    // needs its own storage scope: every WebPetRepository reads the same
    // SharedPreferences store, so an unscoped "empty" repo above still sees
    // the pet added for the populated screens.
    final emptyRepository = WebPetRepository(storageScope: 'a11y-empty-user');
    final emptyState = FurloState(emptyRepository);
    await emptyState.load();
    assert((await emptyRepository.getPets()).isEmpty);

    return <String, Widget>{
      'Home': ChangeNotifierProvider.value(
        value: state,
        child: HomeScreen(
          repository: repository,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
      'Home (no pets)': ChangeNotifierProvider.value(
        value: emptyState,
        child: HomeScreen(
          repository: emptyRepository,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
      'Pet profile': ChangeNotifierProvider.value(
        value: state,
        child: PetProfileScreen(petId: '1', repository: repository),
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
      'Weight': WeightTrackingScreen(
        repository: repository,
        pets: pets,
        selectedPet: pet,
      ),
      'Notifications': NotificationsScreen(
        settings: notifications,
        service: const NoOpNotificationService(),
      ),
      'Onboarding': OnboardingScreen(
        repository: repository,
        notificationSettings: notifications,
        notificationService: const NoOpNotificationService(),
      ),
      'Feeding': ChangeNotifierProvider.value(
        value: state,
        child: FeedingScreen(repository: repository),
      ),
      'Vet details': VetDetailsScreen(repository: repository, vet: vet),
      'Notification settings': NotificationSettingsScreen(
        settings: notifications,
        service: const NoOpNotificationService(),
      ),
      'Profile': ChangeNotifierProvider.value(
        value: themeSettings,
        child: ProfileScreen(
          repository: repository,
          appSettings: SharedPreferencesAppSettingsRepository(),
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
    };
  }

  testWidgets('every icon-only control carries an accessible label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final unlabelled = <String>[];
    for (final scale in const [1.0, 2.0]) {
      SharedPreferences.setMockInitialValues({});
      final screens = await buildScreens();
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.defaultTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: entry.value,
          ),
        );
        await tester.pumpAndSettle();

        // A screen that threw while building renders an error widget with no
        // controls at all, so this guard would pass while inspecting nothing.
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${entry.key} threw while building, so its controls were '
              'never inspected',
        );

        for (final button in tester.widgetList<IconButton>(
          find.byType(IconButton),
        )) {
          final icon = button.icon;
          final labelled =
              button.tooltip != null ||
              (icon is Icon && icon.semanticLabel != null);
          if (!labelled) {
            unlabelled.add('${entry.key} @ x$scale: icon button');
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }

    expect(
      unlabelled,
      isEmpty,
      reason:
          'an icon-only control with no tooltip is announced as nothing '
          'useful:\n${unlabelled.join('\n')}',
    );
  });

  testWidgets('every icon-only control meets the minimum tap target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final undersized = <String>[];
    var inspected = 0;
    SharedPreferences.setMockInitialValues({});
    final screens = await buildScreens();
    for (final entry in screens.entries) {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.defaultTheme, home: entry.value),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            '${entry.key} threw while building, so its tap targets were '
            'never inspected',
      );

      final buttons = find.byType(IconButton);
      inspected += buttons.evaluate().length;
      for (var i = 0; i < buttons.evaluate().length; i++) {
        final size = tester.getSize(buttons.at(i));
        if (size.width < minTapTarget || size.height < minTapTarget) {
          undersized.add(
            '${entry.key}: ${size.width.toStringAsFixed(1)}'
            'x${size.height.toStringAsFixed(1)}',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }

    // Without this the test passes trivially if the screens render no icon
    // buttons at all (a crash, a renamed widget, a branch that never built).
    expect(
      inspected,
      greaterThan(0),
      reason: 'no icon-only controls were found, so nothing was measured',
    );
    expect(
      undersized,
      isEmpty,
      reason:
          'controls smaller than ${minTapTarget}dp are hard to hit:\n'
          '${undersized.join('\n')}',
    );
  });
}
