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
  test(
    'deleting a pet removes all related records and vet links on web',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(id: 1, name: 'Milo', species: 'Dog'));
      await repository.addPet(Pet(id: 2, name: 'Luna', species: 'Cat'));
      await repository.addFeedingSchedule(
        FeedingEntry(petId: 1, name: 'Dinner', time: '18:00'),
      );
      await repository.addVaccination(
        Vaccination(petId: 1, vaccineName: 'Rabies'),
      );
      await repository.addHealthRecord(
        HealthRecord(petId: 1, title: 'Checkup', type: 'Vet Visit'),
      );
      await repository.addWeightLog(
        WeightLog(petId: 1, date: DateTime(2026, 10, 1), weight: 8.2),
      );
      final vet = await repository.addVet(
        Vet(name: 'Dr. Lee', phone: '5551234567'),
        [1, 2],
      );

      await repository.deletePet(1);

      expect(await repository.getPets(), hasLength(1));
      expect(await repository.getFeedingSchedules(1), isEmpty);
      expect(await repository.getVaccinationsForPet(1), isEmpty);
      expect(await repository.getHealthRecordsForPet(1), isEmpty);
      expect(await repository.getWeightLogsForPet(1), isEmpty);
      expect(await repository.getVetsForPet(1), isEmpty);
      expect((await repository.getVetsForPet(2)).single.id, vet.id);
    },
  );
}
