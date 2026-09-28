import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'web storage starts empty and feeding CRUD is isolated per pet',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(name: 'Miso', species: 'Cat'));

      final pets = await repository.getPets();
      final mochiId = pets.firstWhere((pet) => pet.name == 'Mochi').id!;
      final misoId = pets.firstWhere((pet) => pet.name == 'Miso').id!;
      expect(await repository.getFeedingSchedules(mochiId), isEmpty);
      expect(await repository.getFeedingSchedules(misoId), isEmpty);

      final mochiMeal = await repository.addFeedingSchedule(
        FeedingEntry(petId: mochiId, name: 'Breakfast', time: '08:00'),
      );
      final misoMeal = await repository.addFeedingSchedule(
        FeedingEntry(petId: misoId, name: 'Dinner', time: '18:00'),
      );
      expect(
        (await repository.getFeedingSchedules(mochiId)).single.name,
        'Breakfast',
      );
      expect(
        (await repository.getFeedingSchedules(misoId)).single.name,
        'Dinner',
      );

      final fedNow = mochiMeal.copyWith(
        name: 'Morning meal',
        lastFedAt: DateTime.now(),
      );
      await repository.updateFeedingSchedule(fedNow);
      final savedMeal = (await repository.getFeedingSchedules(mochiId)).single;
      expect(savedMeal.name, 'Morning meal');
      expect(savedMeal.doneToday, isTrue);

      await repository.deleteFeedingSchedule(mochiMeal.id!, mochiId);
      expect(await repository.getFeedingSchedules(mochiId), isEmpty);
      expect(
        (await repository.getFeedingSchedules(misoId)).single.id,
        misoMeal.id,
      );
    },
  );

  test('daily completion expires on the following date', () {
    final fedAt = DateTime(2026, 2, 3, 20, 0);
    final schedule = FeedingEntry(
      petId: 1,
      name: 'Dinner',
      time: '18:00',
      lastFedAt: fedAt,
    );

    expect(schedule.isDoneOn(DateTime(2026, 2, 3)), isTrue);
    expect(schedule.isDoneOn(DateTime(2026, 2, 4)), isFalse);
  });
}
