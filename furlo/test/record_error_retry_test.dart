import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/health/health_records_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingVaccinationRepository extends WebPetRepository {
  bool fail = true;

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    if (fail) throw StateError('offline');
    return super.getVaccinationsForPet(petId);
  }
}

class _ThrowingHealthRepository extends WebPetRepository {
  bool fail = true;

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId) async {
    if (fail) throw StateError('offline');
    return super.getHealthRecordsForPet(petId);
  }
}

class _ThrowingWeightRepository extends WebPetRepository {
  bool fail = true;

  @override
  Future<List<WeightLog>> getWeightLogsForPet(String petId) async {
    if (fail) throw StateError('offline');
    return super.getWeightLogsForPet(petId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<Pet>> seedPets(WebPetRepository repository) async {
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    return repository.getPets();
  }

  testWidgets('vaccination error state offers a working retry', (tester) async {
    final repository = _ThrowingVaccinationRepository();
    final pets = await seedPets(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: VaccinationScreen(
          repository: repository,
          pets: pets,
          selectedPet: pets.single,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vaccinations could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Vaccinations could not be loaded.'), findsNothing);
    expect(find.text('No vaccinations yet'), findsOneWidget);
  });

  testWidgets('health records error state offers a working retry', (
    tester,
  ) async {
    final repository = _ThrowingHealthRepository();
    final pets = await seedPets(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: HealthRecordsScreen(
          repository: repository,
          pets: pets,
          selectedPet: pets.single,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health records could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Health records could not be loaded.'), findsNothing);
    expect(find.text('No health records yet'), findsOneWidget);
  });

  testWidgets('weight error state offers a working retry', (tester) async {
    final repository = _ThrowingWeightRepository();
    final pets = await seedPets(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackingScreen(
          repository: repository,
          pets: pets,
          selectedPet: pets.single,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weight entries could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Weight entries could not be loaded.'), findsNothing);
    expect(find.text('No weight entries yet'), findsOneWidget);
  });
}
