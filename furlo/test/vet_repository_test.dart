import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/repositories/pet_repository.dart';

void main() {
  late WebPetRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = WebPetRepository();
    await repository.addPet(Pet(id: 1, name: 'Mochi', species: 'Dog'));
    await repository.addPet(Pet(id: 2, name: 'Miso', species: 'Cat'));
  });

  test('joined vet and pet queries include each linked record', () async {
    final vet = await repository.addVet(
      Vet(name: 'Dr. Lee', phone: '5551234567'),
      [1, 2],
    );
    expect((await repository.getVetsForPet(1)).single.id, vet.id);
    expect((await repository.getVetsForPet(2)).single.id, vet.id);
    expect((await repository.getPetsForVet(vet.id!)).map((pet) => pet.id), [
      1,
      2,
    ]);
    expect((await repository.getVetById(vet.id!))?.name, 'Dr. Lee');
  });

  test(
    'replacing pet associations removes old links and keeps matching appointment',
    () async {
      final vet = await repository.addVet(
        Vet(name: 'Dr. Lee', phone: '5551234567'),
        [1, 2],
      );
      final date = DateTime(2027, 4, 5);
      await repository.setNextAppointment(vet.id!, 2, date);
      await repository.updateVet(vet.copyWith(name: 'Dr. Kim'), [2]);
      expect((await repository.getVetsForPet(1)), isEmpty);
      expect((await repository.getVetsForPet(2)).single.name, 'Dr. Kim');
      expect(
        (await repository.getVetPetAssociations(
          vet.id!,
        )).single.nextAppointmentDate,
        date,
      );
    },
  );

  test('deleting vet removes links', () async {
    final vet = await repository.addVet(
      Vet(name: 'Dr. Lee', phone: '5551234567'),
      [1, 2],
    );
    await repository.deleteVet(vet.id!);
    expect(await repository.getAllVets(), isEmpty);
    expect(await repository.getPetsForVet(vet.id!), isEmpty);
    expect(await repository.getVetsForPet(1), isEmpty);
  });

  test('deleting pet removes links and keeps vet', () async {
    final vet = await repository.addVet(
      Vet(name: 'Dr. Lee', phone: '5551234567'),
      [1, 2],
    );
    await repository.deletePet(1);
    expect((await repository.getVetsForPet(1)), isEmpty);
    expect((await repository.getVetsForPet(2)).single.id, vet.id);
    expect((await repository.getAllVets()).single.id, vet.id);
  });
}
