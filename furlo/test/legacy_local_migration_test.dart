import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/legacy_local_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryMarker implements MigrationMarker {
  bool complete = false;
  int markCompleteCalls = 0;

  @override
  Future<bool> isComplete() async => complete;

  @override
  Future<void> markComplete() async {
    complete = true;
    markCompleteCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LegacyLocalMigration', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'copies local pets and records into the account, preserving ids',
      () async {
        // Device data written before any account existed (unscoped keys).
        final legacy = WebPetRepository();
        await legacy.addPet(Pet(id: '1', name: 'Mochi', species: 'Cat'));
        await legacy.addFeedingSchedule(
          FeedingEntry(petId: '1', name: 'Breakfast', time: '08:00'),
        );
        await legacy.addWeightLog(
          WeightLog(petId: '1', date: DateTime(2026, 10, 1), weight: 4.2),
        );
        await legacy.addVet(Vet(id: '9', name: 'Dr Kim', phone: '5559'), ['1']);

        final target = WebPetRepository(storageScope: 'alice-uid');
        final marker = _MemoryMarker();
        final migration = LegacyLocalMigration(
          uid: 'alice-uid',
          target: target,
          marker: marker,
          legacySources: [legacy],
        );

        expect(await migration.run(), isTrue);

        final pets = await target.getPets();
        expect(pets.single.id, '1');
        expect(pets.single.name, 'Mochi');
        expect(await target.getFeedingSchedules('1'), hasLength(1));
        expect(await target.getWeightLogsForPet('1'), hasLength(1));
        expect((await target.getVetsForPet('1')).single.name, 'Dr Kim');
        expect(marker.complete, isTrue);
      },
    );

    test('leaves the device data untouched', () async {
      final legacy = WebPetRepository();
      await legacy.addPet(Pet(id: '1', name: 'Mochi', species: 'Cat'));

      final migration = LegacyLocalMigration(
        uid: 'alice-uid',
        target: WebPetRepository(storageScope: 'alice-uid'),
        marker: _MemoryMarker(),
        legacySources: [legacy],
      );
      await migration.run();

      // Same instance, same keys: nothing was cleared or rewritten.
      expect((await legacy.getPets()).single.name, 'Mochi');
    });

    test('runs once and skips on a second attempt', () async {
      final legacy = WebPetRepository();
      await legacy.addPet(Pet(id: '1', name: 'Mochi', species: 'Cat'));

      final target = WebPetRepository(storageScope: 'alice-uid');
      final marker = _MemoryMarker();
      final migration = LegacyLocalMigration(
        uid: 'alice-uid',
        target: target,
        marker: marker,
        legacySources: [legacy],
      );

      expect(await migration.run(), isTrue);
      expect(await migration.run(), isFalse);
      expect(await target.getPets(), hasLength(1));
      expect(marker.markCompleteCalls, 1);
    });

    test('skips when the account already has pets in the cloud', () async {
      final legacy = WebPetRepository();
      await legacy.addPet(Pet(id: '1', name: 'Mochi', species: 'Cat'));

      final target = WebPetRepository(storageScope: 'alice-uid');
      await target.addPet(Pet(id: '7', name: 'Cloud pet', species: 'Dog'));

      final marker = _MemoryMarker();
      final migration = LegacyLocalMigration(
        uid: 'alice-uid',
        target: target,
        marker: marker,
        legacySources: [legacy],
      );

      expect(await migration.run(), isFalse);
      expect(await target.getPets(), hasLength(1));
      expect(marker.complete, isTrue);
    });

    test('a failing marker does not throw', () async {
      final migration = LegacyLocalMigration(
        uid: 'alice-uid',
        target: WebPetRepository(storageScope: 'alice-uid'),
        marker: _ThrowingMarker(),
      );
      expect(await migration.run(), isFalse);
    });
  });
}

class _ThrowingMarker implements MigrationMarker {
  @override
  Future<bool> isComplete() => throw StateError('unavailable');

  @override
  Future<void> markComplete() async {}
}
