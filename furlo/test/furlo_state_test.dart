import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late WebPetRepository repository;
  late FurloState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = WebPetRepository();
    state = FurloState(repository);
  });

  test('load reads pets and initializes selection', () async {
    final pet = Pet(id: '1', name: 'Milo', species: 'Dog');
    await repository.addPet(pet);
    var notifications = 0;
    state.addListener(() => notifications++);

    await state.load();

    expect(state.isLoading, isFalse);
    expect(state.loadError, isNull);
    expect(state.pets.single.name, 'Milo');
    expect(state.selectedPet?.id, '1');
    expect(notifications, 2);
  });

  test('add writes through repository and publishes the new pet', () async {
    await state.load();
    var notifications = 0;
    state.addListener(() => notifications++);

    await state.addPet(Pet(name: 'Mochi', species: 'Cat'));

    expect((await repository.getPets()).single.name, 'Mochi');
    expect(state.pets.single.name, 'Mochi');
    expect(state.selectedPet?.name, 'Mochi');
    expect(notifications, 1);
  });

  test(
    'update writes through repository and updates selected pet data',
    () async {
      await repository.addPet(Pet(id: '1', name: 'Milo', species: 'Dog'));
      await state.load();
      var notifications = 0;
      state.addListener(() => notifications++);
      final updatedPet = Pet(id: '1', name: 'Milo Jr', species: 'Dog');

      await state.updatePet(updatedPet);

      expect((await repository.getPets()).single.name, 'Milo Jr');
      expect(state.pets.single.name, 'Milo Jr');
      expect(state.selectedPet?.name, 'Milo Jr');
      expect(notifications, 1);
    },
  );

  test(
    'delete chooses a remaining pet or null and publishes changes',
    () async {
      await repository.addPet(Pet(id: '1', name: 'Milo', species: 'Dog'));
      await repository.addPet(Pet(id: '2', name: 'Luna', species: 'Cat'));
      await state.load();
      state.selectPet(state.pets.last);
      var notifications = 0;
      state.addListener(() => notifications++);

      await state.deletePet('2');

      expect(state.pets.map((pet) => pet.id), ['1']);
      expect(state.selectedPet?.id, '1');
      expect(notifications, 1);
      await state.deletePet('1');
      expect(state.pets, isEmpty);
      expect(state.selectedPet, isNull);
      expect(notifications, 2);
    },
  );

  test(
    'load reports repository errors without presenting an empty success',
    () async {
      final failingState = FurloState(_FailingPetRepository());

      await failingState.load();

      expect(failingState.isLoading, isFalse);
      expect(failingState.loadError, isA<StateError>());
      expect(failingState.pets, isEmpty);
    },
  );
}

class _FailingPetRepository extends WebPetRepository {
  @override
  Future<List<Pet>> getPets() async => throw StateError('load failed');
}
