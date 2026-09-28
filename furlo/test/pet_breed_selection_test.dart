import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';

class _FakePetRepository implements PetRepository {
  final schedules = <FeedingEntry>[];
  Pet? savedPet;
  var _nextId = 1;

  @override
  Future<void> addPet(Pet pet) async {
    savedPet = pet;
  }

  @override
  Future<List<Pet>> getPets() async => [];

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final saved = entry.copyWith(id: _nextId++);
    schedules.add(saved);
    return saved;
  }

  @override
  Future<void> deleteFeedingSchedule(int id, int petId) async {
    schedules.removeWhere((entry) => entry.id == id && entry.petId == petId);
  }

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(int petId) async =>
      schedules.where((entry) => entry.petId == petId).toList();

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final index = schedules.indexWhere(
      (existing) => existing.id == entry.id && existing.petId == entry.petId,
    );
    if (index >= 0) schedules[index] = entry;
  }
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
      MaterialApp(home: AddPetScreen(repository: repository)),
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
