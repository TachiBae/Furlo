import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingRepository extends WebPetRepository {
  int feedingLoads = 0;

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) {
    feedingLoads++;
    return super.getFeedingSchedules(petId);
  }
}

Future<(_CountingRepository, FurloState)> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = _CountingRepository();
  await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
  await repository.addPet(Pet(id: '2', name: 'Poppy', species: 'Cat'));
  await repository.addFeedingSchedule(
    FeedingEntry(petId: '1', name: 'Breakfast', time: '00:00'),
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
  return (repository, state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a meal fed on the Feeding screen leaves the dashboard', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('Breakfast'), findsOneWidget);

    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('Feeding Schedule'), findsOneWidget);
    await tester.tap(find.text('Mark fed'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Breakfast'), findsNothing);
  });

  testWidgets('selecting a pet does not reload the reminders', (tester) async {
    final (repository, state) = await _pumpHome(tester);
    final before = repository.feedingLoads;

    state.selectPet(state.pets.firstWhere((pet) => pet.id == '2'));
    await tester.pumpAndSettle();

    expect(repository.feedingLoads, before);
  });
}
