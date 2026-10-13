import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/vaccine_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 10, 14, 15, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('doses and due dates in date order, with Today in between', () {
    final events = buildVaccineTimeline([
      Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        dateGiven: DateTime(2025, 10, 1),
        nextDueDate: DateTime(2026, 10, 1), // overdue
      ),
      Vaccination(
        petId: '1',
        vaccineName: 'DHPP',
        dateGiven: DateTime(2026, 3, 5),
        nextDueDate: DateTime(2027, 3, 5),
      ),
    ], today: _today);

    expect(events.map((e) => '${e.kind.name}:${e.title}'), [
      'given:Rabies',
      'given:DHPP',
      'overdue:Rabies',
      'today:Today',
      'due:DHPP',
    ]);
  });

  test('a completed record shows its dose but no due date', () {
    final events = buildVaccineTimeline([
      Vaccination(
        petId: '1',
        vaccineName: 'Lepto',
        dateGiven: DateTime(2026, 1, 1),
        nextDueDate: DateTime(2027, 1, 1),
        isCompleted: true,
      ),
    ], today: _today);
    expect(events.map((e) => e.kind), [
      VaccineEventKind.given,
      VaccineEventKind.today,
    ]);
  });

  test('records without dates give an empty timeline', () {
    expect(
      buildVaccineTimeline([
        Vaccination(petId: '1', vaccineName: 'Rabies'),
      ], today: _today),
      isEmpty,
    );
  });

  testWidgets('the toolbar switches between cards and the timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    await repository.addVaccination(
      Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        dateGiven: DateTime(2025, 10, 1),
        nextDueDate: DateTime.now().add(const Duration(days: 40)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: VaccinationScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsOneWidget);

    await tester.tap(find.byTooltip('Show as timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsNothing);
    expect(find.text('Given'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.textContaining('Today ·'), findsOneWidget);
    expect(find.text('All'), findsNothing); // filters hidden
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Show as cards'));
    await tester.pumpAndSettle();
    expect(find.text('Mark complete'), findsOneWidget);
  });
}
