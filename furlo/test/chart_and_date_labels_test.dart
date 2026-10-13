import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/providers/theme_settings.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/formatting.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('weight chart axis labels are never drawn twice', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    final now = DateTime.now();
    for (final (i, kg) in [8.1, 8.3, 8.4, 8.6, 8.7, 8.9].indexed) {
      await repository.addWeightLog(
        WeightLog(
          petId: '1',
          date: now.subtract(Duration(days: 30 * (5 - i))),
          weight: kg,
        ),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: WeightTrackingScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();

    final axis = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => RegExp(r'^\d+\.\d$').hasMatch(t))
        .toList();
    expect(axis, isNotEmpty);
    expect(axis.toSet().length, axis.length, reason: 'duplicates: $axis');
  });

  testWidgets('reminder dates read like the rest of the app', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    final due = DateTime.now().subtract(const Duration(days: 3));
    await repository.addVaccination(
      Vaccination(petId: '1', vaccineName: 'Bordetella', nextDueDate: due),
    );
    final state = FurloState(repository);
    await state.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: ChangeNotifierProvider<ThemeSettings>(
          create: (_) => ThemeSettings(),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: HomeScreen(
              repository: repository,
              notificationSettings:
                  SharedPreferencesNotificationSettingsRepository(),
              notificationService: const NoOpNotificationService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(formatMonthDay(due)), findsOneWidget);
    expect(find.text('${due.month}/${due.day}'), findsNothing);
  });

  testWidgets('the pet profile writes the birthdate with the month name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = WebPetRepository();
    await repository.addPet(
      Pet(
        id: '1',
        name: 'Mochi',
        species: 'Dog',
        birthDate: DateTime(2021, 3, 14),
      ),
    );
    final state = FurloState(repository);
    await state.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: PetProfileScreen(petId: '1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mar 14, 2021'), findsOneWidget);
    expect(find.text('3/14/2021'), findsNothing);
  });
}
