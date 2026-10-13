import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The production store. Every other repository test runs against the web
/// legacy store, so these pin the behaviour the app actually ships.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late FirestorePetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    repository = FirestorePetRepository(uid: 'alice', firestore: firestore);
  });

  Future<Map<String, dynamic>> doc(String collection, String id) async =>
      (await firestore
              .collection('users')
              .doc('alice')
              .collection(collection)
              .doc(id)
              .get())
          .data()!;

  Future<int> count(String collection) async =>
      (await firestore
              .collection('users')
              .doc('alice')
              .collection(collection)
              .get())
          .size;

  group('pets', () {
    test('add, read, update and delete under users/{uid}/pets', () async {
      await repository.addPet(
        Pet(id: 'p1', name: 'Mochi', species: 'Cat', breed: 'Siamese'),
      );
      expect((await repository.getPets()).single.breed, 'Siamese');

      await repository.updatePet(Pet(id: 'p1', name: 'Mochi', species: 'Cat'));
      final updated = (await repository.getPets()).single;
      expect(updated.breed, isNull);
      expect((await doc('pets', 'p1')).keys, isNot(contains('id')));

      await repository.deletePet('p1');
      expect(await repository.getPets(), isEmpty);
    });

    test('a pet without an id gets a generated one', () async {
      await repository.addPet(Pet(name: 'Rex', species: 'Dog'));
      expect((await repository.getPets()).single.id, isNotEmpty);
    });

    test('only small data-URI photos are stored in the document', () async {
      const small = 'data:image/jpeg;base64,AAAA';
      await repository.addPet(
        Pet(id: 'p1', name: 'A', species: 'Cat', photoPath: small),
      );
      await repository.addPet(
        Pet(id: 'p2', name: 'B', species: 'Cat', photoPath: '/tmp/b.jpg'),
      );
      final huge = 'data:image/png;base64,${'A' * kMaxCloudPhotoBytes}';
      await repository.addPet(
        Pet(id: 'p3', name: 'C', species: 'Cat', photoPath: huge),
      );

      expect((await doc('pets', 'p1'))['photo'], small);
      expect((await doc('pets', 'p2'))['photo'], isNull);
      expect((await doc('pets', 'p3'))['photo'], isNull);
      // The device mirror still shows the local-only photos here.
      final pets = {for (final p in await repository.getPets()) p.id: p};
      expect(pets['p2']!.photoPath, '/tmp/b.jpg');
      expect(pets['p3']!.photoPath, huge);
    });

    test('accounts never see each other\'s pets', () async {
      await repository.addPet(Pet(id: 'p1', name: 'Mochi', species: 'Cat'));
      final bob = FirestorePetRepository(uid: 'bob', firestore: firestore);
      expect(await bob.getPets(), isEmpty);
    });
  });

  group('cascade delete', () {
    Future<void> seedPet(String id) async {
      await repository.addPet(Pet(id: id, name: 'Pet $id', species: 'Dog'));
      await repository.addFeedingSchedule(
        FeedingEntry(petId: id, name: 'Breakfast', time: '08:00'),
      );
      await repository.addVaccination(
        Vaccination(petId: id, vaccineName: 'Rabies'),
      );
      await repository.addHealthRecord(
        HealthRecord(petId: id, title: 'Checkup', type: 'Vet visit'),
      );
      await repository.addWeightLog(
        WeightLog(petId: id, date: DateTime(2026, 10, 1), weight: 12),
      );
    }

    test(
      'deleting a pet removes its records and links, keeps the vet',
      () async {
        await seedPet('p1');
        await seedPet('p2');
        final vet = await repository.addVet(Vet(name: 'Dr Kim', phone: '1'), [
          'p1',
          'p2',
        ]);

        await repository.deletePet('p1');

        expect(await repository.getFeedingSchedules('p1'), isEmpty);
        expect(await repository.getVaccinationsForPet('p1'), isEmpty);
        expect(await repository.getHealthRecordsForPet('p1'), isEmpty);
        expect(await repository.getWeightLogsForPet('p1'), isEmpty);
        expect(await repository.getFeedingSchedules('p2'), hasLength(1));
        expect(await repository.getVetById(vet.id!), isNotNull);
        final links = await repository.getVetPetAssociations(vet.id!);
        expect(links.map((l) => l.petId), ['p2']);
      },
    );

    test('cascades past the 400-write batch size', () async {
      await repository.addPet(Pet(id: 'p1', name: 'Big', species: 'Dog'));
      for (var i = 0; i < 450; i++) {
        await repository.addFeedingSchedule(
          FeedingEntry(petId: 'p1', name: 'Meal $i', time: '08:00'),
        );
      }
      await repository.deletePet('p1');
      expect(await count('feedings'), 0);
    });

    test('clearAllData empties every collection', () async {
      await seedPet('p1');
      await repository.addVet(Vet(name: 'Dr Kim', phone: '1'), ['p1']);
      await repository.clearAllData();
      for (final name in [
        'pets',
        'feedings',
        'vaccinations',
        'healthRecords',
        'weightLogs',
        'vets',
        'vetLinks',
      ]) {
        expect(await count(name), 0, reason: name);
      }
    });
  });

  group('records', () {
    setUp(() => repository.addPet(Pet(id: 'p1', name: 'M', species: 'Cat')));

    test('feeding CRUD stays scoped to its pet', () async {
      final saved = await repository.addFeedingSchedule(
        FeedingEntry(petId: 'p1', name: 'Dinner', time: '18:00'),
      );
      await repository.addFeedingSchedule(
        FeedingEntry(petId: 'p1', name: 'Breakfast', time: '08:00'),
      );
      expect((await repository.getFeedingSchedules('p1')).map((e) => e.name), [
        'Breakfast',
        'Dinner',
      ]);
      await repository.updateFeedingSchedule(saved.copyWith(name: 'Supper'));
      await repository.deleteFeedingSchedule(saved.id!, 'other-pet');
      expect(await repository.getFeedingSchedules('p1'), hasLength(2));
      await repository.deleteFeedingSchedule(saved.id!, 'p1');
      expect(
        (await repository.getFeedingSchedules('p1')).single.name,
        'Breakfast',
      );
    });

    test(
      'a schedule without a second meal writes no second-meal keys',
      () async {
        final saved = await repository.addFeedingSchedule(
          FeedingEntry(petId: 'p1', name: 'Dinner', time: '18:00'),
        );
        final data = await doc('feedings', saved.id!);
        expect(data.keys, isNot(contains('second_time')));
        expect(data.keys, isNot(contains('last_second_fed_at')));
        expect(data['pet_id'], 'p1');
      },
    );

    test('vaccinations sort newest first and keep completion', () async {
      await repository.addVaccination(
        Vaccination(
          petId: 'p1',
          vaccineName: 'Old',
          dateGiven: DateTime(2025, 1, 1),
        ),
      );
      final recent = await repository.addVaccination(
        Vaccination(
          petId: 'p1',
          vaccineName: 'New',
          dateGiven: DateTime(2026, 1, 1),
        ),
      );
      await repository.updateVaccination(recent.copyWith(isCompleted: true));
      final list = await repository.getVaccinationsForPet('p1');
      expect(list.map((v) => v.vaccineName), ['New', 'Old']);
      expect(list.first.isCompleted, isTrue);
    });

    test('health records and weight logs round-trip', () async {
      final record = await repository.addHealthRecord(
        HealthRecord(
          petId: 'p1',
          title: 'Meds',
          type: 'Medication',
          date: DateTime(2026, 10, 1),
          reminderFrequency: 'daily',
          reminderActive: true,
        ),
      );
      final log = await repository.addWeightLog(
        WeightLog(petId: 'p1', date: DateTime(2026, 10, 2), weight: 4.25),
      );
      final loaded = (await repository.getHealthRecordsForPet('p1')).single;
      expect(loaded.reminderActive, isTrue);
      expect((await repository.getWeightLogsForPet('p1')).single.weight, 4.25);
      await repository.deleteHealthRecord(record.id!, 'p1');
      await repository.deleteWeightLog(log.id!, 'p1');
      expect(await repository.getHealthRecordsForPet('p1'), isEmpty);
      expect(await repository.getWeightLogsForPet('p1'), isEmpty);
    });
  });

  group('vets and the vet-pet links', () {
    setUp(() async {
      await repository.addPet(Pet(id: 'p1', name: 'A', species: 'Cat'));
      await repository.addPet(Pet(id: 'p2', name: 'B', species: 'Dog'));
    });

    test('links follow add, update and delete', () async {
      final vet = await repository.addVet(Vet(name: 'Dr Kim', phone: '1'), [
        'p1',
        'p2',
      ]);
      expect((await repository.getVetsForPet('p1')).single.name, 'Dr Kim');
      expect(await repository.getPetsForVet(vet.id!), hasLength(2));

      await repository.updateVet(vet.copyWith(name: 'Dr K'), ['p2']);
      expect(await repository.getVetsForPet('p1'), isEmpty);
      expect((await repository.getVetsForPet('p2')).single.name, 'Dr K');

      await repository.deleteVet(vet.id!);
      expect(await repository.getAllVets(), isEmpty);
      expect(await count('vetLinks'), 0);
    });

    test('editing a vet keeps the appointments of pets still linked', () async {
      final vet = await repository.addVet(Vet(name: 'Dr Kim', phone: '1'), [
        'p1',
        'p2',
      ]);
      await repository.setNextAppointment(vet.id!, 'p1', DateTime(2026, 11, 3));

      await repository.updateVet(vet.copyWith(phone: '2'), ['p1']);

      final link = (await repository.getVetPetAssociations(vet.id!)).single;
      expect(link.petId, 'p1');
      expect(link.nextAppointmentDate, DateTime(2026, 11, 3));
    });

    test('next appointment is stored on the link', () async {
      final vet = await repository.addVet(Vet(name: 'Dr Kim', phone: '1'), [
        'p1',
      ]);
      await repository.setNextAppointment(vet.id!, 'p1', DateTime(2026, 11, 3));
      final link = (await repository.getVetPetAssociations(vet.id!)).single;
      expect(link.nextAppointmentDate, DateTime(2026, 11, 3));
    });

    test('vets list alphabetically, ignoring case', () async {
      await repository.addVet(Vet(name: 'zed', phone: '1'), []);
      await repository.addVet(Vet(name: 'Amy', phone: '2'), []);
      expect((await repository.getAllVets()).map((v) => v.name), [
        'Amy',
        'zed',
      ]);
    });
  });
}
