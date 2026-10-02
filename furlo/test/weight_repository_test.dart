import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';

void main() {
  late WebPetRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = WebPetRepository();
    await repository.addPet(Pet(id: 4, name: 'Mochi', species: 'Dog'));
  });

  test('web weight CRUD is scoped and sorted newest first', () async {
    final earlier = await repository.addWeightLog(
      WeightLog(petId: 4, date: DateTime(2026, 9, 1), weight: 9.1),
    );
    final later = await repository.addWeightLog(
      WeightLog(petId: 4, date: DateTime(2026, 10, 1), weight: 9.4),
    );
    expect((await repository.getWeightLogsForPet(4)).map((log) => log.id), [
      later.id,
      earlier.id,
    ]);
    await repository.updateWeightLog(
      WeightLog(id: earlier.id, petId: 4, date: earlier.date, weight: 9.2),
    );
    expect((await repository.getWeightLogsForPet(4)).last.weight, 9.2);
    await repository.deleteWeightLog(later.id!, 4);
    expect((await repository.getWeightLogsForPet(4)).single.id, earlier.id);
  });

  test('deleting a pet cascades to its in-memory weight logs', () async {
    await repository.addWeightLog(
      WeightLog(petId: 4, date: DateTime(2026, 10, 1), weight: 9.4),
    );
    await repository.deletePet(4);
    expect(await repository.getWeightLogsForPet(4), isEmpty);
  });
}
