import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'web repository keeps vaccination CRUD in memory per pet and cascades deletes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(name: 'Miso', species: 'Cat'));
      final pets = await repository.getPets();
      final mochiId = pets.firstWhere((pet) => pet.name == 'Mochi').id!;
      final misoId = pets.firstWhere((pet) => pet.name == 'Miso').id!;

      final record = await repository.addVaccination(
        Vaccination(
          petId: mochiId,
          vaccineName: 'Rabies',
          dateGiven: DateTime(2026, 2, 1),
          nextDueDate: DateTime(2027, 2, 1),
        ),
      );
      expect(
        (await repository.getVaccinationsForPet(mochiId)).single.id,
        record.id,
      );
      expect(await WebPetRepository().getVaccinationsForPet(mochiId), isEmpty);
      expect(await repository.getVaccinationsForPet(misoId), isEmpty);

      await repository.updateVaccination(
        record.copyWith(vaccineName: 'Updated vaccine', isCompleted: true),
      );
      final completed = (await repository.getVaccinationsForPet(
        mochiId,
      )).single;
      expect(completed.vaccineName, 'Updated vaccine');
      expect(completed.status, VaccinationStatuses.completed);
      expect(completed.nextDueDate, record.nextDueDate);

      await repository.updateVaccination(
        completed.copyWith(isCompleted: false),
      );
      final reopened = (await repository.getVaccinationsForPet(mochiId)).single;
      expect(reopened.isCompleted, isFalse);
      expect(reopened.nextDueDate, record.nextDueDate);

      await repository.deleteVaccination(record.id!, mochiId);
      expect(await repository.getVaccinationsForPet(mochiId), isEmpty);

      await repository.addVaccination(record.copyWith(id: null));
      await repository.deletePet(mochiId);
      expect(await repository.getVaccinationsForPet(mochiId), isEmpty);
      expect(
        (await repository.getPets()).map((pet) => pet.id),
        contains(misoId),
      );
    },
  );
}
