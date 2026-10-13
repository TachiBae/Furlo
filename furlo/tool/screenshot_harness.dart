// Temporary capture harness for the final-project presentation.
//
// It renders one real Furlo screen per page load so a headless browser can
// screenshot it without signing in:
//
//   flutter build web -t tool/screenshot_harness.dart --no-pub
//   open /?screen=dashboard&w=375&h=812
//
// screen: dashboard | feeding | vaccinations | health | weight | vets |
//         settings | privacy | export
// theme:  default | light | dark   (default when omitted)
// The sample data below is seeded through the real repository API and is
// cleared and re-seeded on every load, so captures are reproducible.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:furlo/data/health_record_types.dart';
import 'package:furlo/firebase_options.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/health/health_records_screen.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/providers/theme_settings.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/screens/settings/privacy_screen.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';

const String _scope = 'screenshot-harness';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('HARNESS FLUTTER ERROR: ${details.exception}');
    debugPrint('${details.stack}');
  };
  try {
    // Some screens transitively import the auth service, whose web plugin needs
    // an initialized Firebase app even though this harness never signs in.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('HARNESS: Firebase init unavailable, continuing: $error');
    }

    // Deliberately the local implementation, not createPetRepository: the
    // production repository is Firestore under users/{uid} and needs a signed-in
    // account, which this headless capture does not have.
    final repository = WebPetRepository();
    await _seed(repository);

    final state = FurloState(repository);
    await state.load();
    if (state.pets.isNotEmpty) state.selectPet(state.pets.first);

    final settings = SharedPreferencesNotificationSettingsRepository(
      storageScope: _scope,
    );

    final query = Uri.base.queryParameters;
    debugPrint('HARNESS: rendering screen=${query['screen']}');
    runApp(
      _HarnessApp(
        state: state,
        repository: repository,
        settings: settings,
        screen: query['screen'] ?? 'dashboard',
        theme: switch (query['theme']) {
          'light' => AppThemeChoice.light,
          'dark' => AppThemeChoice.dark,
          _ => AppThemeChoice.defaultTheme,
        },
        size: Size(
          double.tryParse(query['w'] ?? '') ?? 375,
          double.tryParse(query['h'] ?? '') ?? 812,
        ),
        // Renders the same logical layout at a larger device scale, so a
        // capture is crisp without changing how anything lays out.
        renderScale: double.tryParse(query['scale'] ?? '') ?? 1,
      ),
    );
  } catch (error, stack) {
    debugPrint('HARNESS STARTUP ERROR: $error');
    debugPrint('$stack');
    runApp(_FailureApp(message: '$error'));
  }
}

/// Shown instead of a screen when the harness itself fails, so a capture can
/// never be silently blank.
class _FailureApp extends StatelessWidget {
  const _FailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'HARNESS FAILURE\n\n$message',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    ),
  );
}

class _HarnessApp extends StatelessWidget {
  const _HarnessApp({
    required this.state,
    required this.repository,
    required this.settings,
    required this.screen,
    required this.theme,
    required this.size,
    required this.renderScale,
  });

  final FurloState state;
  final PetRepository repository;
  final NotificationSettingsRepository settings;
  final String screen;
  final AppThemeChoice theme;
  final Size size;
  final double renderScale;

  Widget _screenFor(BuildContext context) {
    switch (screen) {
      case 'feeding':
        return FeedingScreen(repository: repository, storageScope: _scope);
      case 'health':
        return HealthRecordsScreen(
          repository: repository,
          pets: state.pets,
          selectedPet: state.selectedPet,
        );
      case 'weight':
        return WeightTrackingScreen(
          repository: repository,
          pets: state.pets,
          selectedPet: state.selectedPet,
        );
      case 'vaccinations':
        return VaccinationScreen(
          repository: repository,
          pets: state.pets,
          selectedPet: state.selectedPet,
        );
      case 'vets':
        return VetContactsScreen(repository: repository, storageScope: _scope);
      case 'settings':
        return ChangeNotifierProvider<ThemeSettings>(
          create: (_) => ThemeSettings(),
          child: ProfileScreen(
            repository: repository,
            appSettings: SharedPreferencesAppSettingsRepository(
              storageScope: _scope,
            ),
            notificationSettings: settings,
            notificationService: const NoOpNotificationService(),
            storageScope: _scope,
          ),
        );
      case 'privacy':
        return const PrivacyScreen();
      case 'export':
        return PetProfileScreen(
          petId: state.pets.first.id!,
          repository: repository,
          storageScope: _scope,
        );
      case 'dashboard':
      default:
        return HomeScreen(
          repository: repository,
          notificationSettings: settings,
          notificationService: const NoOpNotificationService(),
          storageScope: _scope,
        );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.forChoice(theme),
    // Pin the app to a fixed logical size anchored top-left, so a screenshot
    // of that region is a clean phone-shaped capture.
    builder: (context, child) => Align(
      alignment: Alignment.topLeft,
      child: Transform.scale(
        scale: renderScale,
        alignment: Alignment.topLeft,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: ClipRect(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
    home: ChangeNotifierProvider<FurloState>.value(
      value: state,
      child: Builder(builder: _screenFor),
    ),
  );
}

Future<void> _seed(PetRepository repository) async {
  await repository.clearAllData();
  final now = DateTime.now();

  await repository.addPet(
    Pet(
      name: 'Mochi',
      species: 'Dog',
      breed: 'Shiba Inu',
      birthDate: DateTime(2021, 3, 14),
    ),
  );
  await repository.addPet(
    Pet(
      name: 'Poppy',
      species: 'Cat',
      breed: 'Domestic Shorthair',
      birthDate: DateTime(2019, 6, 2),
    ),
  );

  final pets = await repository.getPets();
  final mochi = pets.firstWhere((pet) => pet.name == 'Mochi');
  final poppy = pets.firstWhere((pet) => pet.name == 'Poppy');

  // Feedings: one checked off today, one still due, one weekly, one overdue.
  await repository.addFeedingSchedule(
    FeedingEntry(
      petId: mochi.id!,
      name: 'Breakfast kibble',
      time: '07:30',
      frequency: 'Daily',
      portionSize: '1 cup',
      remindMe: true,
      lastFedAt: DateTime(now.year, now.month, now.day, 7, 32),
    ),
  );
  await repository.addFeedingSchedule(
    FeedingEntry(
      petId: mochi.id!,
      name: 'Dinner kibble',
      time: '18:30',
      frequency: 'Daily',
      portionSize: '1 cup',
      remindMe: true,
    ),
  );
  await repository.addFeedingSchedule(
    FeedingEntry(
      petId: mochi.id!,
      name: 'Joint supplement',
      time: '12:00',
      frequency: 'Weekly',
      daysOfWeek: const [1, 4],
      portionSize: '1 chew',
    ),
  );
  await repository.addFeedingSchedule(
    FeedingEntry(
      petId: poppy.id!,
      name: 'Wet food',
      time: '08:00',
      frequency: 'Daily',
      portionSize: 'half can',
      lastFedAt: DateTime(now.year, now.month, now.day, 8, 5),
    ),
  );
  await repository.addFeedingSchedule(
    FeedingEntry(
      petId: poppy.id!,
      name: 'Dry food refill',
      time: '20:00',
      frequency: 'Daily',
      portionSize: 'half cup',
    ),
  );

  // Health records: a checkup, a medication reminder, and an illness note.
  await repository.addHealthRecord(
    HealthRecord(
      petId: mochi.id!,
      title: 'Annual wellness exam',
      date: now.subtract(const Duration(days: 61)),
      type: HealthRecordTypes.checkup,
      notes: 'Vitals normal. Slight tartar — dental cleaning suggested.',
    ),
  );
  await repository.addHealthRecord(
    HealthRecord(
      petId: mochi.id!,
      title: 'Flea and tick prevention',
      date: now.subtract(const Duration(days: 12)),
      type: HealthRecordTypes.medication,
      notes: 'Topical treatment, one dose each month.',
      reminderFrequency: HealthReminderFrequencies.monthly,
      reminderActive: true,
    ),
  );
  await repository.addHealthRecord(
    HealthRecord(
      petId: mochi.id!,
      title: 'Upset stomach',
      date: now.subtract(const Duration(days: 34)),
      type: HealthRecordTypes.illnessInjury,
      notes: 'Bland diet for three days, settled without further treatment.',
    ),
  );
  await repository.addHealthRecord(
    HealthRecord(
      petId: mochi.id!,
      title: 'Dental cleaning',
      date: now.add(const Duration(days: 21)),
      type: HealthRecordTypes.surgery,
      notes: 'Scheduled with the vet clinic.',
    ),
  );

  // Vaccinations: upcoming, due soon, and overdue.
  await repository.addVaccination(
    Vaccination(
      petId: mochi.id!,
      vaccineName: 'Rabies',
      dateGiven: now.subtract(const Duration(days: 400)),
      nextDueDate: now.add(const Duration(days: 320)),
    ),
  );
  await repository.addVaccination(
    Vaccination(
      petId: mochi.id!,
      vaccineName: 'DHPP',
      dateGiven: now.subtract(const Duration(days: 350)),
      nextDueDate: now.add(const Duration(days: 12)),
    ),
  );
  await repository.addVaccination(
    Vaccination(
      petId: mochi.id!,
      vaccineName: 'Bordetella',
      dateGiven: now.subtract(const Duration(days: 420)),
      nextDueDate: now.subtract(const Duration(days: 9)),
    ),
  );

  // Weight history so the chart shows a trend.
  const weights = <double>[8.1, 8.3, 8.4, 8.6, 8.7, 8.9];
  for (var i = 0; i < weights.length; i++) {
    await repository.addWeightLog(
      WeightLog(
        petId: mochi.id!,
        date: now.subtract(Duration(days: 30 * (weights.length - 1 - i))),
        weight: weights[i],
        notes: i == weights.length - 1 ? 'Steady gain, healthy range.' : null,
      ),
    );
  }
  await repository.addWeightLog(
    WeightLog(
      petId: poppy.id!,
      date: now.subtract(const Duration(days: 45)),
      weight: 4.2,
    ),
  );
  await repository.addWeightLog(
    WeightLog(
      petId: poppy.id!,
      date: now.subtract(const Duration(days: 5)),
      weight: 4.3,
    ),
  );

  // Vet contact plus the next appointment.
  final vet = await repository.addVet(
    Vet(
      name: 'Dr. Ana Reyes',
      clinic: 'Bayview Animal Clinic',
      phone: '(555) 014-2288',
      email: 'care@bayviewvet.example',
      address: '410 Harbor Street',
    ),
    [mochi.id!, poppy.id!],
  );
  await repository.setNextAppointment(
    vet.id!,
    mochi.id!,
    now.add(const Duration(days: 21)),
  );
}
