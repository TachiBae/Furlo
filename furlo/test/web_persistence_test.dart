import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';

void main() {
  group('WebPetRepository persistence', () {
    test('vaccinations, health records, vets, vet links, and weight logs survive a simulated restart', () async {
      SharedPreferences.setMockInitialValues({});

      // Simulate first session: add data.
      final first = WebPetRepository();
      await first.addPet(Pet(id: 1, name: 'Mochi', species: 'Cat'));
      await first.addVaccination(
        Vaccination(petId: 1, vaccineName: 'Rabies'),
      );
      await first.addHealthRecord(
        HealthRecord(petId: 1, title: 'Checkup', type: 'Checkup'),
      );
      await first.addWeightLog(
        WeightLog(petId: 1, date: DateTime(2026, 10, 1), weight: 4.2),
      );
      await first.addVet(Vet(name: 'Dr Kim', phone: '5559999'), [1]);

      // Simulate restart: create a fresh instance (same SharedPreferences backing).
      final second = WebPetRepository();

      expect(await second.getVaccinationsForPet(1), hasLength(1));
      expect(
        (await second.getVaccinationsForPet(1)).first.vaccineName,
        'Rabies',
      );

      expect(await second.getHealthRecordsForPet(1), hasLength(1));
      expect(
        (await second.getHealthRecordsForPet(1)).first.title,
        'Checkup',
      );

      expect(await second.getWeightLogsForPet(1), hasLength(1));
      expect((await second.getWeightLogsForPet(1)).first.weight, 4.2);

      final vets = await second.getAllVets();
      expect(vets, hasLength(1));
      expect(vets.first.name, 'Dr Kim');

      final petsForVet = await second.getPetsForVet(vets.first.id!);
      expect(petsForVet, hasLength(1));
      expect(petsForVet.first.id, 1);
    });

    test('clearAllData removes all persisted data so a third instance finds nothing', () async {
      SharedPreferences.setMockInitialValues({});

      final first = WebPetRepository();
      await first.addPet(Pet(id: 1, name: 'Mochi', species: 'Cat'));
      await first.addVaccination(Vaccination(petId: 1, vaccineName: 'Rabies'));
      await first.addWeightLog(
        WeightLog(petId: 1, date: DateTime(2026, 10, 1), weight: 4.2),
      );
      await first.addVet(Vet(name: 'Dr Kim', phone: '5559999'), [1]);
      await first.addHealthRecord(
        HealthRecord(petId: 1, title: 'Checkup', type: 'Checkup'),
      );

      await first.clearAllData();

      final second = WebPetRepository();
      expect(await second.getPets(), isEmpty);
      expect(await second.getVaccinationsForPet(1), isEmpty);
      expect(await second.getWeightLogsForPet(1), isEmpty);
      expect(await second.getAllVets(), isEmpty);
      expect(await second.getHealthRecordsForPet(1), isEmpty);
    });

    test('deleting a pet cascades to all persisted records', () async {
      SharedPreferences.setMockInitialValues({});

      final repo = WebPetRepository();
      await repo.addPet(Pet(id: 1, name: 'Mochi', species: 'Cat'));
      await repo.addFeedingSchedule(
        FeedingEntry(petId: 1, name: 'Breakfast', time: '08:00'),
      );
      await repo.addVaccination(Vaccination(petId: 1, vaccineName: 'Rabies'));
      await repo.addHealthRecord(
        HealthRecord(petId: 1, title: 'Checkup', type: 'Checkup'),
      );
      await repo.addWeightLog(
        WeightLog(petId: 1, date: DateTime(2026, 10, 1), weight: 4.2),
      );
      await repo.addVet(Vet(name: 'Dr Kim', phone: '5559999'), [1]);

      await repo.deletePet(1);

      // Verify via a fresh instance.
      final second = WebPetRepository();
      expect(await second.getPets(), isEmpty);
      expect(await second.getFeedingSchedules(1), isEmpty);
      expect(await second.getVaccinationsForPet(1), isEmpty);
      expect(await second.getHealthRecordsForPet(1), isEmpty);
      expect(await second.getWeightLogsForPet(1), isEmpty);
      // Vet contacts survive pet deletion (same as SQLite behaviour).
      expect(await second.getAllVets(), hasLength(1));
      // But the vet<->pet link is gone.
      expect(await second.getVetsForPet(1), isEmpty);
    });
  });
}
