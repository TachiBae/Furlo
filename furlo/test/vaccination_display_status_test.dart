import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vaccinationDisplayStatus', () {
    test('no due date and not marked complete reads "no due date"', () {
      final v = Vaccination(petId: '1', vaccineName: 'Rabies');
      expect(v.status, VaccinationStatuses.completed); // stored, unchanged
      expect(vaccinationDisplayStatus(v), VaccinationStatuses.noDueDate);
    });

    test('marked complete still reads completed', () {
      final v = Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        isCompleted: true,
      );
      expect(vaccinationDisplayStatus(v), VaccinationStatuses.completed);
    });

    test('a due date keeps its derived status', () {
      final v = Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        nextDueDate: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(vaccinationDisplayStatus(v), VaccinationStatuses.overdue);
    });
  });

  testWidgets('the card says No Due Date and Completed filters it out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    await repository.addVaccination(
      Vaccination(petId: '1', vaccineName: 'Rabies'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: VaccinationScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Due Date'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Rabies'), findsNothing);
  });
}
