import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/health_record_types.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/export_service.dart';

class _ExportTestRepository implements PetRepository {
  _ExportTestRepository({
    required this.pets,
    this.vaccinations = const [],
    this.healthRecords = const [],
    this.weights = const [],
    this.vets = const [],
    this.associationsByVetId = const {},
  });

  final List<Pet> pets;
  final List<Vaccination> vaccinations;
  final List<HealthRecord> healthRecords;
  final List<WeightLog> weights;
  final List<Vet> vets;
  final Map<int, List<VetPetAssociation>> associationsByVetId;

  @override
  Future<List<Pet>> getPets() async => pets;

  @override
  Future<List<Vaccination>> getVaccinationsForPet(int petId) async =>
      vaccinations.where((item) => item.petId == petId).toList();

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(int petId) async =>
      healthRecords.where((item) => item.petId == petId).toList();

  @override
  Future<List<WeightLog>> getWeightLogsForPet(int petId) async =>
      weights.where((item) => item.petId == petId).toList();

  @override
  Future<List<Vet>> getVetsForPet(int petId) async => vets;

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(int vetId) async =>
      associationsByVetId[vetId] ?? [];

  @override
  Future<void> addPet(Pet pet) async => throw UnimplementedError();

  @override
  Future<void> updatePet(Pet pet) async => throw UnimplementedError();

  @override
  Future<void> deletePet(int id) async => throw UnimplementedError();

  @override
  Future<void> clearAllData() async => throw UnimplementedError();

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(int petId) async => [];

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async =>
      throw UnimplementedError();

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteFeedingSchedule(int id, int petId) async =>
      throw UnimplementedError();

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async =>
      throw UnimplementedError();

  @override
  Future<void> updateHealthRecord(HealthRecord record) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteHealthRecord(int id, int petId) async =>
      throw UnimplementedError();

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async =>
      throw UnimplementedError();

  @override
  Future<void> updateVaccination(Vaccination vaccination) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteVaccination(int id, int petId) async =>
      throw UnimplementedError();

  @override
  Future<List<Vet>> getAllVets() async => vets;

  @override
  Future<Vet?> getVetById(int id) async => throw UnimplementedError();

  @override
  Future<List<Pet>> getPetsForVet(int vetId) async =>
      throw UnimplementedError();

  @override
  Future<Vet> addVet(Vet vet, List<int> petIds) async =>
      throw UnimplementedError();

  @override
  Future<void> updateVet(Vet vet, List<int> petIds) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteVet(int id) async => throw UnimplementedError();

  @override
  Future<void> setNextAppointment(int vetId, int petId, DateTime? date) async =>
      throw UnimplementedError();

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async =>
      throw UnimplementedError();

  @override
  Future<void> updateWeightLog(WeightLog log) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteWeightLog(int id, int petId) async =>
      throw UnimplementedError();
}

void main() {
  final generatedAt = DateTime(2026, 10, 2, 15, 30);

  group('saveSummary', () {
    test(
      'passes PDF bytes and the expected filename to the save function',
      () async {
        final service = ExportService(
          repository: _ExportTestRepository(
            pets: [Pet(id: 1, name: 'Milo / Pup', species: 'Dog')],
          ),
          saveFile: ({required fileName, required bytes}) async {
            expect(fileName, 'furlo-milo-pup-summary-2026-10-02.pdf');
            expect(bytes, isNotEmpty);
            expect(String.fromCharCodes(bytes.take(4)), '%PDF');
            return '/Downloads/$fileName';
          },
        );
        expect(await service.saveSummary(1, generatedAt: generatedAt), isTrue);
      },
    );

    test('returns false when the native save function is canceled', () async {
      final service = ExportService(
        repository: _ExportTestRepository(
          pets: [Pet(id: 1, name: 'Milo', species: 'Dog')],
        ),
        saveFile: ({required fileName, required bytes}) async => null,
      );
      expect(await service.saveSummary(1, generatedAt: generatedAt), isFalse);
    });

    test('propagates save errors for the UI to handle', () async {
      final service = ExportService(
        repository: _ExportTestRepository(
          pets: [Pet(id: 1, name: 'Milo', species: 'Dog')],
        ),
        saveFile: ({required fileName, required bytes}) async {
          throw StateError('Save failed');
        },
      );
      await expectLater(
        service.saveSummary(1, generatedAt: generatedAt),
        throwsStateError,
      );
    });
  });

  test(
    'web save downloads PDF bytes without sharing or calling saveFile',
    () async {
      var downloaded = false;
      final service = ExportService(
        repository: _ExportTestRepository(
          pets: [Pet(id: 1, name: 'Milo / Pup', species: 'Dog')],
        ),
        isWeb: true,
        saveFile: ({required fileName, required bytes}) async {
          fail('Web must not call the file picker save function');
        },
        shareFile: (_) async => fail('Web download must not invoke sharing'),
        downloadFile: ({required fileName, required bytes}) async {
          downloaded = true;
          expect(fileName, 'furlo-milo-pup-summary-2026-10-02.pdf');
          expect(bytes, isNotEmpty);
          expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        },
      );
      expect(await service.saveSummary(1, generatedAt: generatedAt), isTrue);
      expect(downloaded, isTrue);
    },
  );

  test(
    'native cancel completes without throwing or invoking sharing',
    () async {
      final service = ExportService(
        repository: _ExportTestRepository(
          pets: [Pet(id: 1, name: 'Milo', species: 'Dog')],
        ),
        isWeb: false,
        saveFile: ({required fileName, required bytes}) async => null,
        shareFile: (_) async => fail('Native save must not invoke sharing'),
      );
      expect(await service.saveSummary(1, generatedAt: generatedAt), isFalse);
    },
  );

  group('summaryFileName', () {
    test('sanitizes illegal characters and whitespace', () {
      expect(
        summaryFileName('Milo / Pup', generatedAt),
        'furlo-milo-pup-summary-2026-10-02.pdf',
      );
      expect(
        summaryFileName('  Luna:Star?  ', generatedAt),
        'furlo-luna-star-summary-2026-10-02.pdf',
      );
      expect(
        summaryFileName('***', generatedAt),
        'furlo-pet-summary-2026-10-02.pdf',
      );
    });
  });

  group('formatSummaryDate', () {
    test('formats like Oct 2, 2026', () {
      expect(formatSummaryDate(DateTime(2026, 10, 2)), 'Oct 2, 2026');
      expect(formatSummaryDate(null), '—');
    });
  });

  group('assemblePetSummary', () {
    test('loads pet with empty related records', () async {
      const petId = 7;
      final repository = _ExportTestRepository(
        pets: [
          Pet(
            id: petId,
            name: 'Milo',
            species: 'Dog',
            breed: 'Beagle',
            birthDate: DateTime(2024, 7, 2),
          ),
        ],
      );
      final service = ExportService(repository: repository);

      final summary = await service.assemblePetSummary(
        petId,
        generatedAt: generatedAt,
      );

      expect(summary.pet.name, 'Milo');
      expect(summary.age, '2 yrs 3 mos');
      expect(summary.vaccinations, isEmpty);
      expect(summary.healthRecords, isEmpty);
      expect(summary.weights, isEmpty);
      expect(summary.vets, isEmpty);
      expect(summary.generatedAt, generatedAt);
    });

    test('loads full related data and vet appointments', () async {
      const petId = 3;
      final repository = _ExportTestRepository(
        pets: [
          Pet(
            id: petId,
            name: 'Luna',
            species: 'Cat',
            breed: 'Siamese',
            birthDate: DateTime(2020, 1, 15),
          ),
        ],
        vaccinations: [
          Vaccination(
            id: 1,
            petId: petId,
            vaccineName: 'Rabies',
            dateGiven: DateTime(2026, 1, 10),
            nextDueDate: DateTime(2027, 1, 10),
          ),
        ],
        healthRecords: [
          HealthRecord(
            id: 1,
            petId: petId,
            title: 'Annual checkup',
            date: DateTime(2026, 9, 1),
            type: HealthRecordTypes.checkup,
            notes: 'Healthy',
          ),
        ],
        weights: [
          WeightLog(
            id: 1,
            petId: petId,
            date: DateTime(2026, 9, 15),
            weight: 4.2,
          ),
        ],
        vets: [
          Vet(id: 9, name: 'Dr. Smith', clinic: 'City Vet', phone: '555-0100'),
        ],
        associationsByVetId: {
          9: [
            VetPetAssociation(
              vetId: 9,
              petId: petId,
              nextAppointmentDate: DateTime(2026, 11, 5),
            ),
          ],
        },
      );
      final service = ExportService(repository: repository);

      final summary = await service.assemblePetSummary(
        petId,
        generatedAt: generatedAt,
      );

      expect(summary.vaccinations, hasLength(1));
      expect(summary.healthRecords, hasLength(1));
      expect(summary.weights, hasLength(1));
      expect(summary.vets, hasLength(1));
      expect(summary.vets.first.vet.name, 'Dr. Smith');
      expect(summary.vets.first.nextAppointment, DateTime(2026, 11, 5));
    });

    test('throws when pet is missing', () async {
      final service = ExportService(
        repository: _ExportTestRepository(pets: []),
      );
      expect(
        () => service.assemblePetSummary(99, generatedAt: generatedAt),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('renderSummary', () {
    test('returns non-empty PDF bytes', () async {
      const petId = 1;
      final summary = PetCareSummary(
        pet: Pet(
          id: petId,
          name: 'Zöe 🐾',
          species: 'Dog',
          breed: 'Mix',
          birthDate: DateTime(2022, 5, 1),
        ),
        generatedAt: generatedAt,
        age: '4 yrs 5 mos',
        vaccinations: [
          Vaccination(
            petId: petId,
            vaccineName: 'DHPP',
            dateGiven: DateTime(2026, 3, 1),
            nextDueDate: DateTime(2027, 3, 1),
          ),
        ],
        healthRecords: [
          HealthRecord(
            petId: petId,
            title: 'Skin irritation',
            date: DateTime(2026, 8, 20),
            type: HealthRecordTypes.other,
            notes: 'Long note '.padRight(240, 'x'),
          ),
        ],
        weights: [
          WeightLog(petId: petId, date: DateTime(2026, 8, 1), weight: 12.5),
        ],
        vets: [
          PetCareVetSummary(
            vet: Vet(
              name: 'Dr. Lee',
              clinic: 'North Clinic',
              phone: '555-0199',
            ),
            nextAppointment: DateTime(2026, 12, 1),
          ),
        ],
      );

      final service = ExportService(
        repository: _ExportTestRepository(pets: [summary.pet]),
      );
      final Uint8List bytes = await service.renderSummary(summary);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
