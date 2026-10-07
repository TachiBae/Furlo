import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/health/health_records_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('feeding schedule avoids short-viewport overflows', (
    tester,
  ) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      if (filled) {
        await repository.addFeedingSchedule(
          FeedingEntry(petId: pets.first.id!, name: 'Breakfast', time: '08:00'),
        );
      }
      final state = FurloState(repository);
      await state.load();
      return ChangeNotifierProvider.value(
        value: state,
        child: FeedingScreen(repository: repository),
      );
    });
  });

  testWidgets('vaccinations avoid short-viewport overflows', (tester) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      if (filled) {
        await repository.addVaccination(
          Vaccination(
            petId: pets.first.id!,
            vaccineName: 'Rabies',
            dateGiven: DateTime(2026, 1, 1),
            nextDueDate: DateTime(2027, 1, 1),
          ),
        );
      }
      return VaccinationScreen(
        repository: repository,
        pets: pets,
        selectedPet: pets.first,
      );
    });
  });

  testWidgets('health records avoid short-viewport overflows', (tester) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      if (filled) {
        await repository.addHealthRecord(
          HealthRecord(
            petId: pets.first.id!,
            title: 'Annual checkup',
            date: DateTime(2026, 1, 1),
            type: 'Vet Visit',
          ),
        );
      }
      return HealthRecordsScreen(
        repository: repository,
        pets: pets,
        selectedPet: pets.first,
      );
    });
  });

  testWidgets('vet contacts avoid short-viewport overflows', (tester) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      if (filled) {
        await repository.addVet(Vet(name: 'Dr. Lee', phone: '555-0100'), [
          pets.first.id!,
        ]);
      }
      final state = FurloState(repository);
      await state.load();
      return ChangeNotifierProvider.value(
        value: state,
        child: VetContactsScreen(repository: repository),
      );
    });
  });

  testWidgets('weight tracking avoids short-viewport overflows', (
    tester,
  ) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      if (filled) {
        await repository.addWeightLog(
          WeightLog(
            petId: pets.first.id!,
            date: DateTime(2026, 1, 1),
            weight: 8.2,
          ),
        );
      }
      return WeightTrackingScreen(
        repository: repository,
        pets: pets,
        selectedPet: pets.first,
      );
    });
  });

  testWidgets('vet details avoid short-viewport overflows', (tester) async {
    await _checkShortViewport(tester, (repository, pets, filled) async {
      final vet = await repository.addVet(
        Vet(
          name: 'Dr. Lee',
          clinic: 'Northside Animal Clinic',
          phone: '555-0100',
          email: 'lee@example.com',
          address: '123 Main Street',
          notes: 'Annual checkup and routine care.',
        ),
        filled ? [pets.first.id!] : const [],
      );
      if (filled) {
        await repository.setNextAppointment(
          vet.id!,
          pets.first.id!,
          DateTime(2026, 12, 1),
        );
      }
      return VetDetailsScreen(repository: repository, vet: vet);
    });
  });

  testWidgets('feeding dialog avoids overflow at 400x300 and text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2.0)),
          child: child!,
        ),
        home: ChangeNotifierProvider.value(
          value: state,
          child: FeedingScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pets, isNotEmpty);
    await tester.ensureVisible(find.text('Add feeding schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add feeding schedule'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'open dialog at 2.0 scale');
    expect(find.text('Save'), findsOneWidget);
  });
}

Future<void> _checkShortViewport(
  WidgetTester tester,
  Future<Widget> Function(
    WebPetRepository repository,
    List<Pet> pets,
    bool filled,
  )
  createScreen,
) async {
  tester.view.physicalSize = const Size(400, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  for (final textScale in [1.0, 1.5, 2.0]) {
    for (final filled in [false, true]) {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(id: '2', name: 'Miso', species: 'Cat'));
      final pets = await repository.getPets();
      final screen = await createScreen(repository, pets, filled);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            '${screen.runtimeType}, filled=$filled, text scale=$textScale at 400x300',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }
}
