import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'web health record CRUD is pet-scoped and pet deletion cascades',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(name: 'Miso', species: 'Cat'));
      final pets = await repository.getPets();
      final mochiId = pets.firstWhere((pet) => pet.name == 'Mochi').id!;
      final misoId = pets.firstWhere((pet) => pet.name == 'Miso').id!;

      final newest = await repository.addHealthRecord(
        HealthRecord(
          petId: mochiId,
          title: 'Recent checkup',
          date: DateTime(2026, 5, 3),
          type: 'Checkup',
        ),
      );
      final older = await repository.addHealthRecord(
        HealthRecord(
          petId: mochiId,
          title: 'Older checkup',
          date: DateTime(2025, 5, 3),
          type: 'Checkup',
        ),
      );
      expect(
        (await repository.getHealthRecordsForPet(mochiId)).map((r) => r.id),
        [newest.id, older.id],
      );
      expect(await repository.getHealthRecordsForPet(misoId), isEmpty);

      final updated = HealthRecord(
        id: newest.id,
        petId: mochiId,
        title: 'Medication reminder',
        date: newest.date,
        type: 'Medication',
        reminderFrequency: 'weekly',
        reminderActive: true,
      );
      await repository.updateHealthRecord(updated);
      expect(
        (await repository.getHealthRecordsForPet(mochiId)).first.title,
        'Medication reminder',
      );

      await repository.deleteHealthRecord(newest.id!, mochiId);
      expect(
        (await repository.getHealthRecordsForPet(mochiId)).single.id,
        older.id,
      );
      await repository.deletePet(mochiId);
      expect(await repository.getHealthRecordsForPet(mochiId), isEmpty);
    },
  );
}
