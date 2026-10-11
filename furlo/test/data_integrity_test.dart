import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/health_record_types.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data integrity for the local-first storage path.
///
/// The web repository encodes each record as a `key=value&key=value` query
/// string, so anything that mangles `&`, `=`, `+`, `%` or non-ASCII text
/// silently corrupts a record. These tests round-trip the awkward cases and
/// check what happens when the stored bytes are already damaged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Deliberately nasty: a non-ASCII letter, an emoji, an apostrophe, a
  /// percent sign, an ampersand, an equals sign, a plus, and repeated spaces.
  const awkward = "Zoë 🐕 O'Brien 100% & more=less +2  spaces";

  test('awkward text survives a web storage round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();

    await repository.addPet(Pet(name: awkward, species: 'Dog', breed: 'Mixed'));

    final pets = await repository.getPets();
    expect(pets.single.name, awkward, reason: 'the pet name must survive');
  });

  test('awkward text survives every record type', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));

    await repository.addHealthRecord(
      HealthRecord(
        petId: '1',
        title: awkward,
        date: DateTime(2026, 1, 1),
        type: HealthRecordTypes.checkup,
        notes: awkward,
      ),
    );
    await repository.addVaccination(
      Vaccination(
        petId: '1',
        vaccineName: awkward,
        dateGiven: DateTime(2026, 1, 1),
      ),
    );
    await repository.addVet(Vet(name: awkward, phone: '555-0100'), ['1']);
    await repository.addWeightLog(
      WeightLog(petId: '1', date: DateTime(2026, 1, 1), weight: 8.2),
    );
    await repository.addFeedingSchedule(
      FeedingEntry(petId: '1', name: awkward, time: '08:00'),
    );

    expect(
      (await repository.getHealthRecordsForPet('1')).single.title,
      awkward,
    );
    expect(
      (await repository.getHealthRecordsForPet('1')).single.notes,
      awkward,
    );
    expect(
      (await repository.getVaccinationsForPet('1')).single.vaccineName,
      awkward,
    );
    expect((await repository.getAllVets()).single.name, awkward);
    expect((await repository.getFeedingSchedules('1')).single.name, awkward);
  });

  test('an empty-string field round trips as empty, not null', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: '', species: 'Dog'));
    expect((await repository.getPets()).single.name, '');
  });

  test('a damaged stored record does not break the whole list', () async {
    // '%zz' is not valid percent-encoding, so this decodes only if the loader
    // is resilient.
    SharedPreferences.setMockInitialValues({
      'furlo.pets': ['name=Good&species=Dog', 'broken%zz'],
    });

    final repository = WebPetRepository();
    final pets = await repository.getPets();

    expect(
      pets.map((pet) => pet.name),
      contains('Good'),
      reason: 'one corrupt row must not take the healthy rows down with it',
    );
  });

  test('a stored value that is not a key/value pair is tolerated', () async {
    SharedPreferences.setMockInitialValues({
      'furlo.pets': ['name=Good&species=Dog', 'nonsense'],
    });

    final repository = WebPetRepository();
    final pets = await repository.getPets();
    expect(pets.map((pet) => pet.name), contains('Good'));
  });

  test('deleting a pet removes every kind of child record', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));

    await repository.addWeightLog(
      WeightLog(petId: '1', date: DateTime(2026, 1, 1), weight: 8.2),
    );
    await repository.addFeedingSchedule(
      FeedingEntry(petId: '1', name: 'Breakfast', time: '08:00'),
    );
    await repository.addVaccination(
      Vaccination(
        petId: '1',
        vaccineName: 'Rabies',
        dateGiven: DateTime(2026, 1, 1),
      ),
    );
    await repository.addHealthRecord(
      HealthRecord(
        petId: '1',
        title: 'Checkup',
        date: DateTime(2026, 1, 1),
        type: HealthRecordTypes.checkup,
      ),
    );
    await repository.addVet(Vet(name: 'Dr. Lee', phone: '555-0100'), ['1']);

    await repository.deletePet('1');

    expect(await repository.getPets(), isEmpty);
    expect(await repository.getWeightLogsForPet('1'), isEmpty);
    expect(await repository.getFeedingSchedules('1'), isEmpty);
    expect(await repository.getVaccinationsForPet('1'), isEmpty);
    expect(await repository.getHealthRecordsForPet('1'), isEmpty);

    // A vet is a contact in its own right, so it outlives the pet - that is
    // deliberate (the existing cascade test links one vet to two pets). What
    // must not survive is a link pointing at a pet that no longer exists.
    final vets = await repository.getAllVets();
    expect(vets, hasLength(1));
    expect(
      await repository.getPetsForVet(vets.single.id!),
      isEmpty,
      reason: 'the vet must not still resolve to the deleted pet',
    );
  });

  test('a weekly feeding is scheduled by weekday, not by time of day', () {
    final monday = FeedingEntry(
      petId: '1',
      name: 'Breakfast',
      time: '08:00',
      frequency: 'Weekly',
      daysOfWeek: const [1],
    );

    // 2026-03-09 is a Monday; 2026-03-10 is a Tuesday.
    expect(monday.isScheduledOn(DateTime(2026, 3, 9, 0, 0)), isTrue);
    expect(monday.isScheduledOn(DateTime(2026, 3, 9, 23, 59)), isTrue);
    expect(monday.isScheduledOn(DateTime(2026, 3, 10, 0, 0)), isFalse);
    expect(monday.isScheduledOn(DateTime(2026, 3, 8, 23, 59)), isFalse);
  });

  test('completion is judged by calendar day across a DST change', () {
    // US DST begins 2026-03-08, so this day is 23 hours long locally. A record
    // fed late that evening must still read as done on that calendar day.
    final lateEvening = DateTime(2026, 3, 8, 23, 30);
    final entry = FeedingEntry(
      petId: '1',
      name: 'Dinner',
      time: '18:00',
      lastFedAt: lateEvening,
    );

    expect(entry.isDoneOn(DateTime(2026, 3, 8, 12, 0)), isTrue);
    expect(entry.isDoneOn(DateTime(2026, 3, 9, 0, 0)), isFalse);
  });

  test('a one-off feeding is only scheduled on its own date', () {
    final oneOff = FeedingEntry(
      petId: '1',
      name: 'Vet visit treat',
      time: '09:00',
      frequency: FeedingEntry.doesNotRepeat,
      scheduledDate: DateTime(2026, 5, 4),
    );

    expect(oneOff.isScheduledOn(DateTime(2026, 5, 4, 23, 0)), isTrue);
    expect(oneOff.isScheduledOn(DateTime(2026, 5, 5, 0, 0)), isFalse);
  });
}
