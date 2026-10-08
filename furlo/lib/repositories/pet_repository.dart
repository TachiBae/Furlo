import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/feeding_entry.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../models/weight_log.dart';
import '../utils/app_diagnostics.dart';
import '../utils/user_storage_scope.dart';

abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
  Future<void> updatePet(Pet pet);
  Future<void> deletePet(String id);
  Future<void> clearAllData();
  Future<List<FeedingEntry>> getFeedingSchedules(String petId);
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry);
  Future<void> updateFeedingSchedule(FeedingEntry entry);
  Future<void> deleteFeedingSchedule(String id, String petId);
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId);
  Future<HealthRecord> addHealthRecord(HealthRecord record);
  Future<void> updateHealthRecord(HealthRecord record);
  Future<void> deleteHealthRecord(String id, String petId);
  Future<List<Vaccination>> getVaccinationsForPet(String petId);
  Future<Vaccination> addVaccination(Vaccination vaccination);
  Future<void> updateVaccination(Vaccination vaccination);
  Future<void> deleteVaccination(String id, String petId);
  Future<List<Vet>> getAllVets();
  Future<List<Vet>> getVetsForPet(String petId);
  Future<Vet?> getVetById(String id);
  Future<List<Pet>> getPetsForVet(String vetId);
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId);
  Future<Vet> addVet(Vet vet, List<String> petIds);
  Future<void> updateVet(Vet vet, List<String> petIds);
  Future<void> deleteVet(String id);
  Future<void> setNextAppointment(String vetId, String petId, DateTime? date);
  Future<List<WeightLog>> getWeightLogsForPet(String petId);
  Future<WeightLog> addWeightLog(WeightLog log);
  Future<void> updateWeightLog(WeightLog log);
  Future<void> deleteWeightLog(String id, String petId);
}

/// The cloud-backed repository is the system of record for signed-in accounts.
///
/// Requires [storageScope] to be the signed-in user's uid; pet data then lives in
/// Firestore under `users/{uid}/…` and follows the account across devices.
///
/// The local implementations remain only as read-only legacy readers used by the
/// one-time migration and by tests. New writes never go to device storage.
PetRepository createPetRepository({required String storageScope}) =>
    FirestorePetRepository(uid: storageScope);

class SqlitePetRepository implements PetRepository {
  SqlitePetRepository({this.storageScope});

  final String? storageScope;
  Future<Database>? _database;

  Future<Database> get database => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databaseName = storageScope == null
        ? 'furlo.db'
        : 'furlo_${userStorageScopeToken(storageScope!)}.db';
    final databasePath = path.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      databasePath,
      version: 10,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE pets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          species TEXT NOT NULL,
          breed TEXT,
          birthDate TEXT,
          photoPath TEXT
        )
      ''');
        await _createFeedingSchedulesTable(db);
        await _ensureFeedingScheduleColumns(db);
        await _createVaccinationsTable(db);
        await _createHealthRecordsTable(db);
        await _createVetsTables(db);
        await _createWeightLogsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createFeedingSchedulesTable(db);
        }
        if (oldVersion < 4) await _ensureFeedingScheduleColumns(db);
        if (oldVersion < 5) await _createVaccinationsTable(db);
        if (oldVersion < 6) await _ensureVaccinationColumns(db);
        if (oldVersion < 7) await _createHealthRecordsTable(db);
        if (oldVersion < 8) await _createVetsTables(db);
        if (oldVersion < 9) await _createWeightLogsTable(db);
        if (oldVersion < 10) await _ensureFeedingScheduleColumns(db);
      },
      onOpen: (db) async {
        await _createFeedingSchedulesTable(db);
        await _ensureFeedingScheduleColumns(db);
        await _createVaccinationsTable(db);
        await _ensureVaccinationColumns(db);
        await _createHealthRecordsTable(db);
        await _createVetsTables(db);
        await _createWeightLogsTable(db);
      },
    );
  }

  @override
  Future<List<Pet>> getPets() async {
    final rows = await (await database).query('pets', orderBy: 'id DESC');
    return rows.map(_petFromMap).toList();
  }

  @override
  Future<void> addPet(Pet pet) async {
    await (await database).insert('pets', _petToMap(pet));
  }

  @override
  Future<void> updatePet(Pet pet) async {
    final id = pet.id;
    if (id == null) throw ArgumentError('Pet id is required to update.');
    await (await database).update(
      'pets',
      _petToMap(pet),
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  @override
  Future<void> deletePet(String id) async {
    await (await database).delete(
      'pets',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('vet_pets');
      await txn.delete('pets');
      await txn.delete('vets');
    });
  }

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async {
    final db = await database;
    final rows = await db.query(
      'feeding_schedules',
      where: 'pet_id = ?',
      whereArgs: [int.parse(petId)],
      orderBy: 'scheduled_time',
    );
    final entries = rows.map(_feedingEntryFromMap).toList();
    for (var index = 0; index < rows.length; index++) {
      final doneToday = entries[index].doneToday ? 1 : 0;
      if (rows[index]['done_today'] != doneToday) {
        await db.update(
          'feeding_schedules',
          {'done_today': doneToday},
          where: 'id = ? AND pet_id = ?',
          whereArgs: [int.parse(entries[index].id!), int.parse(petId)],
        );
      }
    }
    return entries;
  }

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final db = await database;
    final id = await db.insert('feeding_schedules', _feedingEntryToMap(entry));
    return entry.copyWith(id: id.toString());
  }

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final id = entry.id;
    if (id == null) throw ArgumentError('Schedule id is required to update.');
    await (await database).update(
      'feeding_schedules',
      _feedingEntryToMap(entry),
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(entry.petId)],
    );
  }

  @override
  Future<void> deleteFeedingSchedule(String id, String petId) async {
    await (await database).delete(
      'feeding_schedules',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(petId)],
    );
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    final rows = await (await database).query(
      'vaccinations',
      where: 'pet_id = ?',
      whereArgs: [int.parse(petId)],
      orderBy: 'date_given DESC, id DESC',
    );
    return rows.map(Vaccination.fromMap).toList();
  }

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async {
    final map = vaccination.toMap();
    map.remove('id');
    final id = await (await database).insert('vaccinations', map);
    return vaccination.copyWith(id: id.toString());
  }

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {
    final id = vaccination.id;
    if (id == null) {
      throw ArgumentError('Vaccination id is required to update.');
    }
    final map = vaccination.toMap();
    map.remove('id');
    await (await database).update(
      'vaccinations',
      map,
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(vaccination.petId)],
    );
  }

  @override
  Future<void> deleteVaccination(String id, String petId) async {
    await (await database).delete(
      'vaccinations',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(petId)],
    );
  }

  @override
  Future<List<Vet>> getAllVets() async => (await (await database).query(
    'vets',
    orderBy: 'name COLLATE NOCASE',
  )).map(Vet.fromMap).toList();

  @override
  Future<List<Vet>> getVetsForPet(String petId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT vets.* FROM vets INNER JOIN vet_pets ON vets.id = vet_pets.vet_id
      WHERE vet_pets.pet_id = ? ORDER BY vets.name COLLATE NOCASE
    ''',
      [int.parse(petId)],
    );
    return rows.map(Vet.fromMap).toList();
  }

  @override
  Future<Vet?> getVetById(String id) async {
    final rows = await (await database).query(
      'vets',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
      limit: 1,
    );
    return rows.isEmpty ? null : Vet.fromMap(rows.first);
  }

  @override
  Future<List<Pet>> getPetsForVet(String vetId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT pets.* FROM pets INNER JOIN vet_pets ON pets.id = vet_pets.pet_id
      WHERE vet_pets.vet_id = ? ORDER BY pets.name COLLATE NOCASE
    ''',
      [int.parse(vetId)],
    );
    return rows.map(_petFromMap).toList();
  }

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId) async =>
      (await (await database).query(
        'vet_pets',
        where: 'vet_id = ?',
        whereArgs: [int.parse(vetId)],
      )).map(VetPetAssociation.fromMap).toList();

  @override
  Future<Vet> addVet(Vet vet, List<String> petIds) async {
    final db = await database;
    late Vet saved;
    await db.transaction((txn) async {
      final values = vet.toMap()..remove('id');
      final id = await txn.insert('vets', values);
      saved = vet.copyWith(id: id.toString());
      for (final petId in petIds.toSet()) {
        await txn.insert('vet_pets', {
          'vet_id': id,
          'pet_id': int.parse(petId),
        });
      }
    });
    return saved;
  }

  @override
  Future<void> updateVet(Vet vet, List<String> petIds) async {
    final id = vet.id;
    if (id == null) throw ArgumentError('Vet id is required to update.');
    final db = await database;
    final rowId = int.parse(id);
    await db.transaction((txn) async {
      final values = vet.toMap()..remove('id');
      await txn.update('vets', values, where: 'id = ?', whereArgs: [rowId]);
      await txn.delete('vet_pets', where: 'vet_id = ?', whereArgs: [rowId]);
      for (final petId in petIds.toSet()) {
        await txn.insert('vet_pets', {
          'vet_id': rowId,
          'pet_id': int.parse(petId),
        });
      }
    });
  }

  @override
  Future<void> deleteVet(String id) async => (await database).delete(
    'vets',
    where: 'id = ?',
    whereArgs: [int.parse(id)],
  );

  @override
  Future<void> setNextAppointment(
    String vetId,
    String petId,
    DateTime? date,
  ) async {
    await (await database).update(
      'vet_pets',
      {'next_appointment_date': date?.toIso8601String()},
      where: 'vet_id = ? AND pet_id = ?',
      whereArgs: [int.parse(vetId), int.parse(petId)],
    );
  }

  @override
  Future<List<WeightLog>> getWeightLogsForPet(String petId) async =>
      (await (await database).query(
        'weight_logs',
        where: 'pet_id = ?',
        whereArgs: [int.parse(petId)],
        orderBy: 'date DESC, id DESC',
      )).map(WeightLog.fromMap).toList();

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async {
    final values = log.toMap()..remove('id');
    final id = await (await database).insert('weight_logs', values);
    return WeightLog(
      id: id.toString(),
      petId: log.petId,
      date: log.date,
      weight: log.weight,
      notes: log.notes,
    );
  }

  @override
  Future<void> updateWeightLog(WeightLog log) async {
    final id = log.id;
    if (id == null) throw ArgumentError('Weight log id is required to update.');
    final values = log.toMap()..remove('id');
    await (await database).update(
      'weight_logs',
      values,
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(log.petId)],
    );
  }

  @override
  Future<void> deleteWeightLog(String id, String petId) async =>
      (await database).delete(
        'weight_logs',
        where: 'id = ? AND pet_id = ?',
        whereArgs: [int.parse(id), int.parse(petId)],
      );

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId) async {
    final rows = await (await database).query(
      'health_records',
      where: 'pet_id = ?',
      whereArgs: [int.parse(petId)],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async {
    final map = record.toMap()..remove('id');
    final id = await (await database).insert('health_records', map);
    return record.copyWith(id: id.toString());
  }

  @override
  Future<void> updateHealthRecord(HealthRecord record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError('Health record id is required to update.');
    }
    final map = record.toMap()..remove('id');
    await (await database).update(
      'health_records',
      map,
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(record.petId)],
    );
  }

  @override
  Future<void> deleteHealthRecord(String id, String petId) async {
    await (await database).delete(
      'health_records',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [int.parse(id), int.parse(petId)],
    );
  }
}

class WebPetRepository implements PetRepository {
  WebPetRepository({this.storageScope});

  final String? storageScope;

  String _scopedKey(String name, String legacyKey) => storageScope == null
      ? legacyKey
      : 'furlo.user.${userStorageScopeToken(storageScope!)}.$name';

  String get _storageKey => _scopedKey('pets', 'furlo.pets');
  String get _feedingStorageKey =>
      _scopedKey('feeding_schedules', 'furlo.feeding_schedules');
  String get _vaccinationsKey =>
      _scopedKey('vaccinations', 'furlo.vaccinations');
  String get _healthRecordsKey =>
      _scopedKey('health_records', 'furlo.health_records');
  String get _vetsKey => _scopedKey('vets', 'furlo.vets');
  String get _vetLinksKey => _scopedKey('vet_links', 'furlo.vet_links');
  String get _weightLogsKey => _scopedKey('weight_logs', 'furlo.weight_logs');

  final List<Vaccination> _vaccinations = [];
  final List<HealthRecord> _healthRecords = [];
  final List<Vet> _vets = [];
  final List<VetPetAssociation> _vetLinks = [];
  final List<WeightLog> _weightLogs = [];

  Future<void>? _initFuture;

  Future<void> _ensureLoaded() => _initFuture ??= _loadAll();

  Future<void> _loadAll() async {
    final preferences = await SharedPreferences.getInstance();

    final vaccinationValues = preferences.getStringList(_vaccinationsKey) ?? [];
    _vaccinations
      ..clear()
      ..addAll(
        vaccinationValues.map((v) => Vaccination.fromMap(_decodeMap(v))),
      );

    final healthValues = preferences.getStringList(_healthRecordsKey) ?? [];
    _healthRecords
      ..clear()
      ..addAll(healthValues.map((v) => HealthRecord.fromMap(_decodeMap(v))));

    final vetValues = preferences.getStringList(_vetsKey) ?? [];
    _vets
      ..clear()
      ..addAll(vetValues.map((v) => Vet.fromMap(_decodeMap(v))));

    final vetLinkValues = preferences.getStringList(_vetLinksKey) ?? [];
    _vetLinks
      ..clear()
      ..addAll(
        vetLinkValues.map((v) => VetPetAssociation.fromMap(_decodeMap(v))),
      );

    final weightValues = preferences.getStringList(_weightLogsKey) ?? [];
    _weightLogs
      ..clear()
      ..addAll(weightValues.map((v) => WeightLog.fromMap(_decodeMap(v))));
  }

  Future<void> _saveVaccinations(SharedPreferences preferences) =>
      preferences.setStringList(
        _vaccinationsKey,
        _vaccinations
            .map(
              (v) => Uri(
                queryParameters: v.toMap().map(
                  (k, val) => MapEntry(k, val?.toString() ?? ''),
                ),
              ).query,
            )
            .toList(),
      );

  Future<void> _saveHealthRecords(SharedPreferences preferences) =>
      preferences.setStringList(
        _healthRecordsKey,
        _healthRecords
            .map(
              (r) => Uri(
                queryParameters: r.toMap().map(
                  (k, val) => MapEntry(k, val?.toString() ?? ''),
                ),
              ).query,
            )
            .toList(),
      );

  Future<void> _saveVets(SharedPreferences preferences) =>
      preferences.setStringList(
        _vetsKey,
        _vets
            .map(
              (v) => Uri(
                queryParameters: v.toMap().map(
                  (k, val) => MapEntry(k, val?.toString() ?? ''),
                ),
              ).query,
            )
            .toList(),
      );

  Future<void> _saveVetLinks(SharedPreferences preferences) =>
      preferences.setStringList(
        _vetLinksKey,
        _vetLinks
            .map(
              (l) => Uri(
                queryParameters: l.toMap().map(
                  (k, val) => MapEntry(k, val?.toString() ?? ''),
                ),
              ).query,
            )
            .toList(),
      );

  Future<void> _saveWeightLogs(SharedPreferences preferences) =>
      preferences.setStringList(
        _weightLogsKey,
        _weightLogs
            .map(
              (l) => Uri(
                queryParameters: l.toMap().map(
                  (k, val) => MapEntry(k, val?.toString() ?? ''),
                ),
              ).query,
            )
            .toList(),
      );

  @override
  Future<List<Pet>> getPets() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_storageKey) ?? [];
    final pets = values.map((value) => _petFromMap(_decodeMap(value))).toList();
    var nextId = pets.fold<int>(0, (maxId, pet) {
      final id = _numericId(pet.id);
      return id > maxId ? id : maxId;
    });
    var migrated = false;
    for (var index = 0; index < pets.length; index++) {
      final pet = pets[index];
      if (pet.id != null) continue;
      migrated = true;
      nextId++;
      pets[index] = Pet(
        id: nextId.toString(),
        name: pet.name,
        species: pet.species,
        breed: pet.breed,
        birthDate: pet.birthDate,
        photoPath: pet.photoPath,
      );
    }
    if (migrated) await _savePets(preferences, pets);
    return pets;
  }

  @override
  Future<void> addPet(Pet pet) async {
    final preferences = await SharedPreferences.getInstance();
    final pets = await getPets();
    final id =
        pet.id ??
        (pets.fold<int>(0, (maxId, existing) {
                  final existingId = _numericId(existing.id);
                  return existingId > maxId ? existingId : maxId;
                }) +
                1)
            .toString();
    pets.add(
      Pet(
        id: id,
        name: pet.name,
        species: pet.species,
        breed: pet.breed,
        birthDate: pet.birthDate,
        photoPath: pet.photoPath,
      ),
    );
    await _savePets(preferences, pets);
  }

  @override
  Future<void> updatePet(Pet pet) async {
    final id = pet.id;
    if (id == null) throw ArgumentError('Pet id is required to update.');
    final preferences = await SharedPreferences.getInstance();
    final pets = await getPets();
    final index = pets.indexWhere((existing) => existing.id == id);
    if (index < 0) return;
    pets[index] = pet;
    await _savePets(preferences, pets);
  }

  @override
  Future<void> deletePet(String id) async {
    await _ensureLoaded();

    final preferences = await SharedPreferences.getInstance();
    final pets = await getPets();
    await _savePets(preferences, pets.where((pet) => pet.id != id).toList());
    final feedingValues = preferences.getStringList(_feedingStorageKey) ?? [];
    final feedingEntries = feedingValues
        .map((value) => _feedingEntryFromMap(_decodeMap(value)))
        .where((entry) => entry.petId != id)
        .toList();
    await _saveFeedingEntries(preferences, feedingEntries);
    _vaccinations.removeWhere((item) => item.petId == id);
    await _saveVaccinations(preferences);
    _healthRecords.removeWhere((record) => record.petId == id);
    await _saveHealthRecords(preferences);
    _vetLinks.removeWhere((link) => link.petId == id);
    await _saveVetLinks(preferences);
    _weightLogs.removeWhere((log) => log.petId == id);
    await _saveWeightLogs(preferences);
  }

  @override
  Future<void> clearAllData() async {
    _initFuture = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
      await preferences.remove(_feedingStorageKey);
      await preferences.remove(_vaccinationsKey);
      await preferences.remove(_healthRecordsKey);
      await preferences.remove(_vetsKey);
      await preferences.remove(_vetLinksKey);
      await preferences.remove(_weightLogsKey);
    } catch (_) {
      // In-memory web data is still reset if browser storage is unavailable.
    }
    _vaccinations.clear();
    _healthRecords.clear();
    _vets.clear();
    _vetLinks.clear();
    _weightLogs.clear();
  }

  Future<void> _savePets(SharedPreferences preferences, List<Pet> pets) =>
      preferences.setStringList(
        _storageKey,
        pets
            .map(
              (pet) => Uri(
                queryParameters: _petToMap(
                  pet,
                ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
              ).query,
            )
            .toList(),
      );

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_feedingStorageKey) ?? [];
    final maps = values.map(_decodeMap).toList();
    final entries = maps.map(_feedingEntryFromMap).toList();
    final needsDailyReset = List.generate(
      entries.length,
      (index) =>
          int.tryParse(maps[index]['done_today']?.toString() ?? '0') !=
          (entries[index].doneToday ? 1 : 0),
    ).contains(true);
    final updatedEntries = List<FeedingEntry>.of(entries);
    updatedEntries.sort((a, b) => a.time.compareTo(b.time));
    if (needsDailyReset) {
      await _saveFeedingEntries(preferences, updatedEntries);
    }
    return updatedEntries.where((entry) => entry.petId == petId).toList();
  }

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_feedingStorageKey) ?? [];
    final entries = values
        .map((value) => _feedingEntryFromMap(_decodeMap(value)))
        .toList();
    final id =
        entry.id ??
        (entries.fold<int>(0, (maxId, existing) {
                  final existingId = _numericId(existing.id);
                  return existingId > maxId ? existingId : maxId;
                }) +
                1)
            .toString();
    final saved = entry.copyWith(id: id);
    entries.add(saved);
    await _saveFeedingEntries(preferences, entries);
    return saved;
  }

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final id = entry.id;
    if (id == null) throw ArgumentError('Schedule id is required to update.');
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_feedingStorageKey) ?? [];
    final entries = values
        .map((value) => _feedingEntryFromMap(_decodeMap(value)))
        .toList();
    final index = entries.indexWhere(
      (existing) => existing.id == id && existing.petId == entry.petId,
    );
    if (index < 0) return;
    entries[index] = entry;
    await _saveFeedingEntries(preferences, entries);
  }

  @override
  Future<void> deleteFeedingSchedule(String id, String petId) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_feedingStorageKey) ?? [];
    final entries = values
        .map((value) => _feedingEntryFromMap(_decodeMap(value)))
        .where((entry) => !(entry.id == id && entry.petId == petId))
        .toList();
    await _saveFeedingEntries(preferences, entries);
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    await _ensureLoaded();
    return _vaccinations
        .where((item) => item.petId == petId)
        .map((item) => Vaccination.fromMap(item.toMap()))
        .toList();
  }

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async {
    await _ensureLoaded();
    final nextId =
        _vaccinations.fold<int>(0, (maxId, item) {
          final id = _numericId(item.id);
          return id > maxId ? id : maxId;
        }) +
        1;
    final saved = vaccination.copyWith(id: vaccination.id ?? nextId.toString());
    _vaccinations.add(saved);
    final preferences = await SharedPreferences.getInstance();
    await _saveVaccinations(preferences);
    return saved;
  }

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {
    await _ensureLoaded();
    final id = vaccination.id;
    if (id == null) {
      throw ArgumentError('Vaccination id is required to update.');
    }
    final index = _vaccinations.indexWhere(
      (item) => item.id == id && item.petId == vaccination.petId,
    );
    if (index < 0) return;
    _vaccinations[index] = vaccination;
    final preferences = await SharedPreferences.getInstance();
    await _saveVaccinations(preferences);
  }

  @override
  Future<void> deleteVaccination(String id, String petId) async {
    await _ensureLoaded();
    _vaccinations.removeWhere((item) => item.id == id && item.petId == petId);
    final preferences = await SharedPreferences.getInstance();
    await _saveVaccinations(preferences);
  }

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId) async {
    await _ensureLoaded();
    final records = _healthRecords
        .where((record) => record.petId == petId)
        .toList();
    records.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate == null && bDate == null) {
        return _numericId(b.id).compareTo(_numericId(a.id));
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      final dateOrder = bDate.compareTo(aDate);
      return dateOrder == 0
          ? _numericId(b.id).compareTo(_numericId(a.id))
          : dateOrder;
    });
    return records;
  }

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async {
    await _ensureLoaded();
    final nextId =
        _healthRecords.fold<int>(0, (maxId, item) {
          final id = _numericId(item.id);
          return id > maxId ? id : maxId;
        }) +
        1;
    final saved = record.copyWith(id: record.id ?? nextId.toString());
    _healthRecords.add(saved);
    final preferences = await SharedPreferences.getInstance();
    await _saveHealthRecords(preferences);
    return saved;
  }

  @override
  Future<void> updateHealthRecord(HealthRecord record) async {
    await _ensureLoaded();
    final id = record.id;
    if (id == null) {
      throw ArgumentError('Health record id is required to update.');
    }
    final index = _healthRecords.indexWhere(
      (item) => item.id == id && item.petId == record.petId,
    );
    if (index >= 0) {
      _healthRecords[index] = record;
      final preferences = await SharedPreferences.getInstance();
      await _saveHealthRecords(preferences);
    }
  }

  @override
  Future<void> deleteHealthRecord(String id, String petId) async {
    await _ensureLoaded();
    _healthRecords.removeWhere((item) => item.id == id && item.petId == petId);
    final preferences = await SharedPreferences.getInstance();
    await _saveHealthRecords(preferences);
  }

  @override
  Future<List<Vet>> getAllVets() async {
    await _ensureLoaded();
    return List.of(_vets);
  }

  @override
  Future<List<Vet>> getVetsForPet(String petId) async {
    await _ensureLoaded();
    return _vets
        .where(
          (vet) => _vetLinks.any(
            (link) => link.vetId == vet.id && link.petId == petId,
          ),
        )
        .toList();
  }

  @override
  Future<Vet?> getVetById(String id) async {
    await _ensureLoaded();
    for (final vet in _vets) {
      if (vet.id == id) return vet;
    }
    return null;
  }

  @override
  Future<List<Pet>> getPetsForVet(String vetId) async {
    await _ensureLoaded();
    final ids = _vetLinks
        .where((link) => link.vetId == vetId)
        .map((link) => link.petId)
        .toSet();
    return (await getPets()).where((pet) => ids.contains(pet.id)).toList();
  }

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId) async {
    await _ensureLoaded();
    return _vetLinks.where((link) => link.vetId == vetId).toList();
  }

  @override
  Future<Vet> addVet(Vet vet, List<String> petIds) async {
    await _ensureLoaded();
    final id =
        vet.id ??
        (_vets.fold<int>(
                  0,
                  (max, item) =>
                      _numericId(item.id) > max ? _numericId(item.id) : max,
                ) +
                1)
            .toString();
    final saved = vet.copyWith(id: id);
    _vets.add(saved);
    for (final petId in petIds.toSet()) {
      _vetLinks.add(VetPetAssociation(vetId: id, petId: petId));
    }
    final preferences = await SharedPreferences.getInstance();
    await _saveVets(preferences);
    await _saveVetLinks(preferences);
    return saved;
  }

  @override
  Future<void> updateVet(Vet vet, List<String> petIds) async {
    await _ensureLoaded();
    final id = vet.id;
    if (id == null) throw ArgumentError('Vet id is required to update.');
    final index = _vets.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _vets[index] = vet;
    final previous = {
      for (final link in _vetLinks.where((link) => link.vetId == id))
        link.petId: link,
    };
    _vetLinks.removeWhere((link) => link.vetId == id);
    for (final petId in petIds.toSet()) {
      _vetLinks.add(
        previous[petId] ?? VetPetAssociation(vetId: id, petId: petId),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await _saveVets(preferences);
    await _saveVetLinks(preferences);
  }

  @override
  Future<void> deleteVet(String id) async {
    await _ensureLoaded();
    _vets.removeWhere((vet) => vet.id == id);
    _vetLinks.removeWhere((link) => link.vetId == id);
    final preferences = await SharedPreferences.getInstance();
    await _saveVets(preferences);
    await _saveVetLinks(preferences);
  }

  @override
  Future<void> setNextAppointment(
    String vetId,
    String petId,
    DateTime? date,
  ) async {
    await _ensureLoaded();
    final index = _vetLinks.indexWhere(
      (link) => link.vetId == vetId && link.petId == petId,
    );
    if (index >= 0) {
      _vetLinks[index] = VetPetAssociation(
        vetId: vetId,
        petId: petId,
        nextAppointmentDate: date,
      );
      final preferences = await SharedPreferences.getInstance();
      await _saveVetLinks(preferences);
    }
  }

  @override
  Future<List<WeightLog>> getWeightLogsForPet(String petId) async {
    await _ensureLoaded();
    final logs = _weightLogs.where((log) => log.petId == petId).toList();
    logs.sort((a, b) {
      final dateOrder = (b.date ?? DateTime(0)).compareTo(
        a.date ?? DateTime(0),
      );
      return dateOrder == 0
          ? _numericId(b.id).compareTo(_numericId(a.id))
          : dateOrder;
    });
    return logs;
  }

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async {
    await _ensureLoaded();
    final id =
        log.id ??
        (_weightLogs.fold<int>(
                  0,
                  (max, item) =>
                      _numericId(item.id) > max ? _numericId(item.id) : max,
                ) +
                1)
            .toString();
    final saved = WeightLog(
      id: id,
      petId: log.petId,
      date: log.date,
      weight: log.weight,
      notes: log.notes,
    );
    _weightLogs.add(saved);
    final preferences = await SharedPreferences.getInstance();
    await _saveWeightLogs(preferences);
    return saved;
  }

  @override
  Future<void> updateWeightLog(WeightLog log) async {
    await _ensureLoaded();
    final id = log.id;
    if (id == null) throw ArgumentError('Weight log id is required to update.');
    final index = _weightLogs.indexWhere(
      (item) => item.id == id && item.petId == log.petId,
    );
    if (index >= 0) {
      _weightLogs[index] = log;
      final preferences = await SharedPreferences.getInstance();
      await _saveWeightLogs(preferences);
    }
  }

  @override
  Future<void> deleteWeightLog(String id, String petId) async {
    await _ensureLoaded();
    _weightLogs.removeWhere((log) => log.id == id && log.petId == petId);
    final preferences = await SharedPreferences.getInstance();
    await _saveWeightLogs(preferences);
  }

  Future<void> _saveFeedingEntries(
    SharedPreferences preferences,
    List<FeedingEntry> entries,
  ) => preferences.setStringList(
    _feedingStorageKey,
    entries
        .map(
          (entry) => Uri(
            queryParameters: _feedingEntryToMap(
              entry,
            ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
          ).query,
        )
        .toList(),
  );
}

Future<void> _createVetsTables(Database db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS vets (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, clinic TEXT,
    phone TEXT NOT NULL, email TEXT, address TEXT, notes TEXT
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS vet_pets (
    vet_id INTEGER NOT NULL, pet_id INTEGER NOT NULL, next_appointment_date TEXT,
    PRIMARY KEY (vet_id, pet_id),
    FOREIGN KEY (vet_id) REFERENCES vets(id) ON DELETE CASCADE,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
  )''');
}

Future<void> _createWeightLogsTable(Database db) => db.execute('''
  CREATE TABLE IF NOT EXISTS weight_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pet_id INTEGER NOT NULL,
    date TEXT NOT NULL,
    weight REAL NOT NULL,
    notes TEXT,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
  )
''');

Future<void> _createFeedingSchedulesTable(Database db) => db.execute('''
  CREATE TABLE IF NOT EXISTS feeding_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pet_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    scheduled_time TEXT NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'Daily',
    scheduled_date TEXT,
    days_of_week TEXT NOT NULL DEFAULT '',
    portion_size TEXT,
    remind_me INTEGER NOT NULL DEFAULT 0,
    last_fed_at TEXT,
    done_today INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
  )
      ''');

Future<void> _ensureFeedingScheduleColumns(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(feeding_schedules)');
  final names = columns.map((column) => column['name']).toSet();
  final additions = <String, String>{
    'days_of_week': "TEXT NOT NULL DEFAULT ''",
    'portion_size': 'TEXT',
    'remind_me': 'INTEGER NOT NULL DEFAULT 0',
    'scheduled_date': 'TEXT',
  };
  for (final entry in additions.entries) {
    if (!names.contains(entry.key)) {
      await db.execute(
        'ALTER TABLE feeding_schedules ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }
}

Future<void> _createVaccinationsTable(Database db) => db.execute('''
  CREATE TABLE IF NOT EXISTS vaccinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pet_id INTEGER NOT NULL,
    vaccine_name TEXT NOT NULL,
    date_given TEXT,
    next_due_date TEXT,
    status TEXT NOT NULL DEFAULT 'upcoming',
    is_completed INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
  )
''');

Future<void> _createHealthRecordsTable(Database db) => db.execute('''
  CREATE TABLE IF NOT EXISTS health_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pet_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    date TEXT,
    type TEXT NOT NULL,
    notes TEXT,
    reminder_frequency TEXT,
    reminder_active INTEGER,
    FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
  )
''');

Future<void> _ensureVaccinationColumns(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(vaccinations)');
  final names = columns.map((column) => column['name']).toSet();
  if (!names.contains('is_completed')) {
    await db.execute(
      'ALTER TABLE vaccinations ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0',
    );
  }
}

/// Numeric value of a local id, for the legacy stores that keep integer rows.
int _numericId(String? id) => int.tryParse(id ?? '') ?? 0;

/// Id string, or null when the stored value is empty/absent.
String? _stringId(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

Map<String, Object?> _petToMap(Pet pet) => {
  'id': pet.id,
  'name': pet.name,
  'species': pet.species,
  'breed': pet.breed,
  'birthDate': pet.birthDate?.toIso8601String(),
  'photoPath': pet.photoPath,
};

Pet _petFromMap(Map<String, Object?> row) => Pet(
  id: _stringId(row['id']),
  name: row['name'] as String,
  species: row['species'] as String,
  breed: (row['breed'] as String?)?.isEmpty == true
      ? null
      : row['breed'] as String?,
  birthDate: DateTime.tryParse(row['birthDate'] as String? ?? ''),
  photoPath: (row['photoPath'] as String?)?.isEmpty == true
      ? null
      : row['photoPath'] as String?,
);

Map<String, Object?> _feedingEntryToMap(FeedingEntry entry) => {
  'id': entry.id,
  'pet_id': entry.petId,
  'name': entry.name,
  'scheduled_time': entry.time,
  'frequency': entry.frequency,
  'scheduled_date': entry.scheduledDate?.toIso8601String(),
  'days_of_week': entry.daysOfWeek.join(','),
  'portion_size': entry.portionSize,
  'remind_me': entry.remindMe ? 1 : 0,
  'last_fed_at': entry.lastFedAt?.toIso8601String(),
  'done_today': entry.doneToday ? 1 : 0,
};

FeedingEntry _feedingEntryFromMap(Map<String, Object?> row) => FeedingEntry(
  id: _stringId(row['id']),
  petId: row['pet_id']?.toString() ?? '',
  name: row['name']?.toString() ?? '',
  time: row['scheduled_time']?.toString() ?? '08:00',
  frequency: row['frequency']?.toString() ?? 'Daily',
  scheduledDate: DateTime.tryParse(row['scheduled_date']?.toString() ?? ''),
  daysOfWeek: (row['days_of_week']?.toString() ?? '')
      .split(',')
      .where((value) => value.isNotEmpty)
      .map(int.parse)
      .toList(),
  portionSize: (row['portion_size']?.toString().isEmpty ?? true)
      ? null
      : row['portion_size'].toString(),
  remindMe:
      row['remind_me']?.toString() == '1' ||
      row['remind_me']?.toString().toLowerCase() == 'true',
  lastFedAt: DateTime.tryParse(row['last_fed_at']?.toString() ?? ''),
);

Map<String, Object?> _decodeMap(String value) => Map<String, Object?>.from(
  Uri.splitQueryString(value).map((key, value) => MapEntry(key, value)),
);

/// Largest photo payload written to a pet document.
///
/// Firestore caps documents at 1 MB; 600 KB leaves headroom for the other
/// pet fields. Base64 data URIs are ASCII, so length approximates bytes.
const int kMaxCloudPhotoBytes = 600 * 1024;

/// Returns [photoPath] when it is a base64 data URI small enough to live in
/// the pet's Firestore document, otherwise null (device file paths, empty,
/// or oversized payloads that would risk the 1 MB document cap).
String? cloudPhotoField(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty) return null;
  if (!photoPath.startsWith('data:')) return null;
  if (photoPath.length > kMaxCloudPhotoBytes) return null;
  return photoPath;
}

/// Cloud document photo when present, otherwise the device-local mirror.
Future<String?> resolvePetPhoto(
  Map<String, Object?> data,
  String petId,
  LocalPetPhotoStore store,
) async {
  final cloud = data['photo'] as String?;
  if (cloud != null && cloud.isNotEmpty) return cloud;
  return store.read(petId);
}

/// Pet data for one signed-in account, stored in Firestore under `users/{uid}/…`.
///
/// Every collection except `pets` carries a `pet_id` field so children can be
/// queried and cascade-deleted per pet. Document ids are the model ids.
///
/// Photos ride along in the pet document when [cloudPhotoField] accepts them
/// (base64 data URI under the size cap). [LocalPetPhotoStore] remains the
/// device-side mirror and the fallback for legacy file paths and oversized
/// photos that cannot live in Firestore.
class FirestorePetRepository implements PetRepository {
  FirestorePetRepository({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _photos = LocalPetPhotoStore(storageScope: uid);

  final String uid;
  final FirebaseFirestore _firestore;
  final LocalPetPhotoStore _photos;

  static const _pets = 'pets';
  static const _feedings = 'feedings';
  static const _vaccinations = 'vaccinations';
  static const _healthRecords = 'healthRecords';
  static const _weightLogs = 'weightLogs';
  static const _vets = 'vets';
  static const _vetLinks = 'vetLinks';

  /// Children removed with their pet.
  static const _petChildren = [
    _feedings,
    _vaccinations,
    _healthRecords,
    _weightLogs,
    _vetLinks,
  ];

  static const _all = [
    _pets,
    _feedings,
    _vaccinations,
    _healthRecords,
    _weightLogs,
    _vets,
    _vetLinks,
  ];

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _firestore.collection('users').doc(uid).collection(name);

  String _newId(String collection) => _col(collection).doc().id;

  /// Reuses the model id when present so a re-run overwrites rather than duplicates.
  DocumentReference<Map<String, dynamic>> _doc(String collection, String? id) =>
      id == null ? _col(collection).doc() : _col(collection).doc(id);

  /// Firestore has no transactions spanning reads and writes here, so cascade
  /// deletes collect the child references first and commit one batch.
  Future<void> _deleteBatch(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var start = 0; start < refs.length; start += 400) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(start).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _childrenOf(
    String collection,
    String field,
    String value,
  ) async {
    final snapshot = await _col(
      collection,
    ).where(field, isEqualTo: value).get();
    return snapshot.docs.map((doc) => doc.reference).toList();
  }

  @override
  Future<List<Pet>> getPets() async {
    final snapshot = await _col(_pets).get();
    return Future.wait(
      snapshot.docs.map((doc) async {
        final photo = await resolvePetPhoto(doc.data(), doc.id, _photos);
        return _petFromMap({...doc.data(), 'id': doc.id, 'photoPath': photo});
      }),
    );
  }

  void _logLocalOnlyPhoto(Pet pet) {
    if (pet.photoPath != null && cloudPhotoField(pet.photoPath) == null) {
      logAppDiagnostic('Pet photo kept device-local: not cloud-eligible.');
    }
  }

  @override
  Future<void> addPet(Pet pet) async {
    final id = pet.id ?? _newId(_pets);
    await _col(_pets).doc(id).set(_petData(pet));
    await _photos.write(id, pet.photoPath);
    _logLocalOnlyPhoto(pet);
  }

  @override
  Future<void> updatePet(Pet pet) async {
    final id = pet.id;
    if (id == null) throw ArgumentError('Pet id is required to update.');
    await _col(_pets).doc(id).set(_petData(pet));
    await _photos.write(id, pet.photoPath);
    _logLocalOnlyPhoto(pet);
  }

  @override
  Future<void> deletePet(String id) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[_col(_pets).doc(id)];
    for (final name in _petChildren) {
      refs.addAll(await _childrenOf(name, 'pet_id', id));
    }
    await _deleteBatch(refs);
    await _photos.write(id, null);
  }

  @override
  Future<void> clearAllData() async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final name in _all) {
      final snapshot = await _col(name).get();
      refs.addAll(snapshot.docs.map((doc) => doc.reference));
    }
    await _deleteBatch(refs);
  }

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async {
    final snapshot = await _col(
      _feedings,
    ).where('pet_id', isEqualTo: petId).get();
    final entries = snapshot.docs
        .map((doc) => _feedingEntryFromMap({...doc.data(), 'id': doc.id}))
        .toList();
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final doc = _doc(_feedings, entry.id);
    final saved = entry.copyWith(id: doc.id);
    await doc.set(_feedingEntryData(saved));
    return saved;
  }

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final id = entry.id;
    if (id == null) throw ArgumentError('Schedule id is required to update.');
    await _col(_feedings).doc(id).set(_feedingEntryData(entry));
  }

  @override
  Future<void> deleteFeedingSchedule(String id, String petId) async {
    final refs = await _childrenOf(_feedings, 'pet_id', petId);
    final target = refs.where((ref) => ref.id == id).toList();
    await _deleteBatch(target);
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) async {
    final snapshot = await _col(
      _vaccinations,
    ).where('pet_id', isEqualTo: petId).get();
    final records = snapshot.docs
        .map((doc) => Vaccination.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    records.sort(
      (a, b) =>
          (b.dateGiven ?? DateTime(0)).compareTo(a.dateGiven ?? DateTime(0)),
    );
    return records;
  }

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async {
    final doc = _doc(_vaccinations, vaccination.id);
    final saved = vaccination.copyWith(id: doc.id);
    await doc.set(saved.toMap()..remove('id'));
    return saved;
  }

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {
    final id = vaccination.id;
    if (id == null) {
      throw ArgumentError('Vaccination id is required to update.');
    }
    await _col(_vaccinations).doc(id).set(vaccination.toMap()..remove('id'));
  }

  @override
  Future<void> deleteVaccination(String id, String petId) async {
    final refs = await _childrenOf(_vaccinations, 'pet_id', petId);
    await _deleteBatch(refs.where((ref) => ref.id == id).toList());
  }

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId) async {
    final snapshot = await _col(
      _healthRecords,
    ).where('pet_id', isEqualTo: petId).get();
    final records = snapshot.docs
        .map((doc) => HealthRecord.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    records.sort((a, b) {
      final dateOrder = (b.date ?? DateTime(0)).compareTo(
        a.date ?? DateTime(0),
      );
      return dateOrder;
    });
    return records;
  }

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async {
    final doc = _doc(_healthRecords, record.id);
    final saved = record.copyWith(id: doc.id);
    await doc.set(saved.toMap()..remove('id'));
    return saved;
  }

  @override
  Future<void> updateHealthRecord(HealthRecord record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError('Health record id is required to update.');
    }
    await _col(_healthRecords).doc(id).set(record.toMap()..remove('id'));
  }

  @override
  Future<void> deleteHealthRecord(String id, String petId) async {
    final refs = await _childrenOf(_healthRecords, 'pet_id', petId);
    await _deleteBatch(refs.where((ref) => ref.id == id).toList());
  }

  @override
  Future<List<Vet>> getAllVets() async {
    final snapshot = await _col(_vets).get();
    final vets = snapshot.docs
        .map((doc) => Vet.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    vets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return vets;
  }

  @override
  Future<List<Vet>> getVetsForPet(String petId) async {
    final links = await _col(_vetLinks).where('pet_id', isEqualTo: petId).get();
    final vetIds = links.docs.map((doc) => doc.data()['vet_id']).toSet();
    final vets = await getAllVets();
    return vets.where((vet) => vetIds.contains(vet.id)).toList();
  }

  @override
  Future<Vet?> getVetById(String id) async {
    final doc = await _col(_vets).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Vet.fromMap({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<List<Pet>> getPetsForVet(String vetId) async {
    final links = await _col(_vetLinks).where('vet_id', isEqualTo: vetId).get();
    final petIds = links.docs.map((doc) => doc.data()['pet_id']).toSet();
    final pets = await getPets();
    return pets.where((pet) => petIds.contains(pet.id)).toList();
  }

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId) async {
    final snapshot = await _col(
      _vetLinks,
    ).where('vet_id', isEqualTo: vetId).get();
    return snapshot.docs
        .map((doc) => VetPetAssociation.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<Vet> addVet(Vet vet, List<String> petIds) async {
    final doc = _doc(_vets, vet.id);
    final saved = vet.copyWith(id: doc.id);
    final batch = _firestore.batch();
    batch.set(doc, saved.toMap()..remove('id'));
    for (final petId in petIds.toSet()) {
      batch.set(
        _col(_vetLinks).doc('${doc.id}_$petId'),
        VetPetAssociation(vetId: doc.id, petId: petId).toMap()..remove('id'),
      );
    }
    await batch.commit();
    return saved;
  }

  @override
  Future<void> updateVet(Vet vet, List<String> petIds) async {
    final id = vet.id;
    if (id == null) throw ArgumentError('Vet id is required to update.');
    final previous = await _childrenOf(_vetLinks, 'vet_id', id);
    final batch = _firestore.batch();
    batch.set(_col(_vets).doc(id), vet.toMap()..remove('id'));
    for (final ref in previous) {
      batch.delete(ref);
    }
    for (final petId in petIds.toSet()) {
      batch.set(
        _col(_vetLinks).doc('${id}_$petId'),
        VetPetAssociation(vetId: id, petId: petId).toMap()..remove('id'),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteVet(String id) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[_col(_vets).doc(id)];
    refs.addAll(await _childrenOf(_vetLinks, 'vet_id', id));
    await _deleteBatch(refs);
  }

  @override
  Future<void> setNextAppointment(
    String vetId,
    String petId,
    DateTime? date,
  ) async {
    await _col(_vetLinks).doc('${vetId}_$petId').set({
      'vet_id': vetId,
      'pet_id': petId,
      'next_appointment_date': date?.toIso8601String(),
    });
  }

  @override
  Future<List<WeightLog>> getWeightLogsForPet(String petId) async {
    final snapshot = await _col(
      _weightLogs,
    ).where('pet_id', isEqualTo: petId).get();
    final logs = snapshot.docs
        .map((doc) => WeightLog.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    logs.sort((a, b) {
      final dateOrder = (b.date ?? DateTime(0)).compareTo(
        a.date ?? DateTime(0),
      );
      return dateOrder;
    });
    return logs;
  }

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async {
    final doc = _doc(_weightLogs, log.id);
    final saved = WeightLog(
      id: doc.id,
      petId: log.petId,
      date: log.date,
      weight: log.weight,
      notes: log.notes,
    );
    await doc.set(saved.toMap()..remove('id'));
    return saved;
  }

  @override
  Future<void> updateWeightLog(WeightLog log) async {
    final id = log.id;
    if (id == null) throw ArgumentError('Weight log id is required to update.');
    await _col(_weightLogs).doc(id).set(log.toMap()..remove('id'));
  }

  @override
  Future<void> deleteWeightLog(String id, String petId) async {
    final refs = await _childrenOf(_weightLogs, 'pet_id', petId);
    await _deleteBatch(refs.where((ref) => ref.id == id).toList());
  }

  /// Pet data without the id (held by the document).
  ///
  /// The photo is included whenever it is cloud-eligible; a null value clears
  /// a previously synced photo because `set` replaces the whole document.
  Map<String, Object?> _petData(Pet pet) => {
    'name': pet.name,
    'species': pet.species,
    'breed': pet.breed,
    'birthDate': pet.birthDate?.toIso8601String(),
    'photo': cloudPhotoField(pet.photoPath),
  };

  Map<String, Object?> _feedingEntryData(FeedingEntry entry) => {
    ..._feedingEntryToMap(entry)..remove('id'),
    'pet_id': entry.petId,
  };
}

/// Device-side mirror for pet photos, keyed by pet id within one account.
///
/// The pet document in Firestore is the source of truth when the photo is
/// cloud-eligible; this store mirrors it for instant local display and keeps
/// legacy file paths and oversized photos that cannot live in Firestore.
/// Reads fall back to the pre-account key `photo.pet.{id}` so photos taken
/// before per-account scoping still resolve, and repin hits into the scope.
class LocalPetPhotoStore {
  LocalPetPhotoStore({this.storageScope});

  final String? storageScope;

  String _key(String petId) => storageScope == null
      ? 'photo.pet.$petId'
      : 'photo.user.${userStorageScopeToken(storageScope!)}.pet.$petId';

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<String?> read(String petId) async {
    final preferences = await _preferences();
    if (preferences == null) return null;
    final scoped = preferences.getString(_key(petId));
    if (scoped != null) return scoped;
    if (storageScope == null) return null;
    // Legacy pre-account key: adopt it into the active scope. Non-destructive
    // (the legacy key stays), matching the legacy migration's first-user rule.
    final legacy = preferences.getString('photo.pet.$petId');
    if (legacy == null || legacy.isEmpty) return null;
    await preferences.setString(_key(petId), legacy);
    return legacy;
  }

  Future<void> write(String petId, String? photoPath) async {
    final preferences = await _preferences();
    if (preferences == null) return;
    if (photoPath == null || photoPath.isEmpty) {
      await preferences.remove(_key(petId));
      return;
    }
    await preferences.setString(_key(petId), photoPath);
  }
}
