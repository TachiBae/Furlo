import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts schedule reads so a pull-to-refresh can be proven to re-query.
class _CountingFeedingRepository extends WebPetRepository {
  int scheduleLoads = 0;

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) {
    scheduleLoads++;
    return super.getFeedingSchedules(petId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(WebPetRepository, FurloState, List<Pet>)> pumpReady() async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    final state = FurloState(repository);
    await state.load();
    return (repository, state, pets);
  }

  testWidgets('weight, vets, and feeding screens expose pull-to-refresh', (
    tester,
  ) async {
    var (repository, state, pets) = await pumpReady();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: FeedingScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    SharedPreferences.setMockInitialValues({});
    (repository, state, pets) = await pumpReady();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: VetContactsScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    SharedPreferences.setMockInitialValues({});
    (repository, state, pets) = await pumpReady();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: WeightTrackingScreen(
          repository: repository,
          pets: pets,
          selectedPet: pets.first,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pulling down on feeding reloads its schedules', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _CountingFeedingRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    // Enough cards that the list scrolls at the default 800x600 test size.
    for (var i = 0; i < 8; i++) {
      await repository.addFeedingSchedule(
        FeedingEntry(petId: pets.first.id!, name: 'Meal $i', time: '08:00'),
      );
    }
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ChangeNotifierProvider<FurloState>.value(
          value: state,
          child: FeedingScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final loadsBefore = repository.scheduleLoads;
    expect(loadsBefore, greaterThan(0), reason: 'initial load happened');

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pump(); // refresh indicator engages
    await tester.pump(const Duration(seconds: 1)); // onRefresh runs
    await tester.pumpAndSettle(); // indicator snaps back

    expect(
      repository.scheduleLoads,
      greaterThan(loadsBefore),
      reason: 'pull-to-refresh must re-query feeding schedules',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
