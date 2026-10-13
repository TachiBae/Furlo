import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/formatting.dart';
import 'package:furlo/widgets/record_components.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('petPossessive', () {
    expect(petPossessive('Mochi'), 'Mochi’s');
    expect(petPossessive('Max'), 'Max’s');
    expect(petPossessive('Boots'), 'Boots’');
    expect(petPossessive(null), 'your pet’s');
    expect(petPossessive('  '), 'your pet’s');
  });

  testWidgets('a retry button shows a refresh icon and stays narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: RecordEmptyState(
            title: 'Could not load',
            message: 'Please try again.',
            icon: Icons.error_outline,
            actionLabel: 'Try again',
            actionIcon: Icons.refresh,
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    final button = tester.getSize(find.byType(ElevatedButton));
    expect(button.width, lessThanOrEqualTo(480));
  });

  testWidgets('an empty vaccination list names the pet', (tester) async {
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: VaccinationScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Add Mochi’s first vaccination'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard reminder times use the 12-hour clock', (tester) async {
    tester.view.physicalSize = const Size(375, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    await repository.addFeedingSchedule(
      FeedingEntry(petId: '1', name: 'Supper', time: '23:59'),
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
    expect(find.text('11:59 PM'), findsOneWidget);
    expect(find.text('23:59'), findsNothing);
    // The longest quick-action label fits without breaking mid-word.
    expect(tester.takeException(), isNull);
  });
}
