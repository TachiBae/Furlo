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
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:provider/provider.dart';

class _FakePetRepository implements PetRepository {
  final schedules = <FeedingEntry>[];
  Pet? savedPet;
  var _nextId = 1;

  @override
  Future<void> addPet(Pet pet) async {
    savedPet = pet;
  }

  @override
  Future<void> updatePet(Pet pet) async {
    savedPet = pet;
  }

  @override
  Future<void> deletePet(String id) async {}

  @override
  Future<void> clearAllData() async {}

  @override
  Future<List<Pet>> getPets() async => [];

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final saved = entry.copyWith(id: '${_nextId++}');
    schedules.add(saved);
    return saved;
  }

  @override
  Future<void> deleteFeedingSchedule(String id, String petId) async {
    schedules.removeWhere((entry) => entry.id == id && entry.petId == petId);
  }

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async =>
      schedules.where((entry) => entry.petId == petId).toList();

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final index = schedules.indexWhere(
      (existing) => existing.id == entry.id && existing.petId == entry.petId,
    );
    if (index >= 0) schedules[index] = entry;
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async => [];

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async =>
      vaccination;

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {}

  @override
  Future<void> deleteVaccination(String id, String petId) async {}

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId) async => [];

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async => record;

  @override
  Future<void> updateHealthRecord(HealthRecord record) async {}

  @override
  Future<void> deleteHealthRecord(String id, String petId) async {}

  @override
  Future<List<Vet>> getAllVets() async => [];
  @override
  Future<List<Vet>> getVetsForPet(String petId) async => [];
  @override
  Future<Vet?> getVetById(String id) async => null;
  @override
  Future<List<Pet>> getPetsForVet(String vetId) async => [];
  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId) async =>
      [];
  @override
  Future<Vet> addVet(Vet vet, List<String> petIds) async => vet;
  @override
  Future<void> updateVet(Vet vet, List<String> petIds) async {}
  @override
  Future<void> deleteVet(String id) async {}
  @override
  Future<void> setNextAppointment(
    String vetId,
    String petId,
    DateTime? date,
  ) async {}

  @override
  Future<List<WeightLog>> getWeightLogsForPet(String petId) async => [];
  @override
  Future<WeightLog> addWeightLog(WeightLog log) async => log;
  @override
  Future<void> updateWeightLog(WeightLog log) async {}
  @override
  Future<void> deleteWeightLog(String id, String petId) async {}
}

void main() {
  testWidgets('new pet name is saved with its first letter capitalized', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakePetRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FurloState(repository),
        child: MaterialApp(home: AddPetScreen(repository: repository)),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'mochi');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Pet'));
    await tester.pumpAndSettle();

    expect(repository.savedPet?.name, 'Mochi');
  });

  testWidgets('breed search filters by species and clears on species change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AddPetScreen(repository: _FakePetRepository())),
    );

    final speciesPicker = find.byType(DropdownButtonFormField<String>);
    await tester.tap(speciesPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();
    expect(find.text('Dog'), findsOneWidget);

    await _openBreedPicker(tester);
    await tester.enterText(find.byType(TextField).last, 'Siamese');
    await tester.pumpAndSettle();
    expect(find.text('No breeds found'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'gOlD');
    await tester.pumpAndSettle();
    expect(find.text('Golden Retriever'), findsOneWidget);
    expect(find.text('Golden Doodle'), findsOneWidget);
    expect(find.text('Labrador Retriever'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'retriever');
    await tester.pumpAndSettle();
    expect(find.text('Golden Retriever'), findsOneWidget);
    expect(find.text('Labrador Retriever'), findsOneWidget);
    await tester.tap(find.text('Golden Retriever'));
    await tester.pumpAndSettle();

    await tester.tap(speciesPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();
    await _openBreedPicker(tester);
    await tester.enterText(find.byType(TextField).last, 'sIaM');
    await tester.pumpAndSettle();
    expect(find.text('Siamese'), findsOneWidget);
    expect(find.text('Maine Coon'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'no-such-breed');
    await tester.pumpAndSettle();
    expect(find.text('No breeds found'), findsOneWidget);
  });
}

Future<void> _openBreedPicker(WidgetTester tester) async {
  final selectorHint = find.text('Select breed');
  final selector = find.ancestor(
    of: selectorHint,
    matching: find.byType(InkWell),
  );
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
}
