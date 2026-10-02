import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/feeding_entry.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../models/weight_log.dart';

abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
  Future<void> updatePet(Pet pet);
  Future<void> deletePet(int id);
  Future<void> clearAllData();
  Future<List<FeedingEntry>> getFeedingSchedules(int petId);
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry);
  Future<void> updateFeedingSchedule(FeedingEntry entry);
  Future<void> deleteFeedingSchedule(int id, int petId);
  Future<List<HealthRecord>> getHealthRecordsForPet(int petId);
  Future<HealthRecord> addHealthRecord(HealthRecord record);
  Future<void> updateHealthRecord(HealthRecord record);
  Future<void> deleteHealthRecord(int id, int petId);
  Future<List<Vaccination>> getVaccinationsForPet(int petId);
  Future<Vaccination> addVaccination(Vaccination vaccination);
  Future<void> updateVaccination(Vaccination vaccination);
  Future<void> deleteVaccination(int id, int petId);
  Future<List<Vet>> getAllVets();
  Future<List<Vet>> getVetsForPet(int petId);
  Future<Vet?> getVetById(int id);
  Future<List<Pet>> getPetsForVet(int vetId);
  Future<List<VetPetAssociation>> getVetPetAssociations(int vetId);
  Future<Vet> addVet(Vet vet, List<int> petIds);
  Future<void> updateVet(Vet vet, List<int> petIds);
  Future<void> deleteVet(int id);
  Future<void> setNextAppointment(int vetId, int petId, DateTime? date);
  Future<List<WeightLog>> getWeightLogsForPet(int petId);
  Future<WeightLog> addWeightLog(WeightLog log);
  Future<void> updateWeightLog(WeightLog log);
  Future<void> deleteWeightLog(int id, int petId);
}

/// Uses browser storage on web and SQLite on native platforms.
PetRepository createPetRepository() =>
    kIsWeb ? WebPetRepository() : SqlitePetRepository();

class SqlitePetRepository implements PetRepository {
  Future<Database>? _database;

  Future<Database> get database => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databasePath = path.join(await getDatabasesPath(), 'furlo.db');
    return openDatabase(
      databasePath,
      version: 9,
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
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePet(int id) async {
    await (await database).delete('pets', where: 'id = ?', whereArgs: [id]);
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
  Future<List<FeedingEntry>> getFeedingSchedules(int petId) async {
    final db = await database;
    final rows = await db.query(
      'feeding_schedules',
      where: 'pet_id = ?',
      whereArgs: [petId],
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
          whereArgs: [entries[index].id, petId],
        );
      }
    }
    return entries;
  }

  @override
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry) async {
    final db = await database;
    final id = await db.insert('feeding_schedules', _feedingEntryToMap(entry));
    return entry.copyWith(id: id);
  }

  @override
  Future<void> updateFeedingSchedule(FeedingEntry entry) async {
    final id = entry.id;
    if (id == null) throw ArgumentError('Schedule id is required to update.');
    await (await database).update(
      'feeding_schedules',
      _feedingEntryToMap(entry),
      where: 'id = ? AND pet_id = ?',
      whereArgs: [id, entry.petId],
    );
  }

  @override
  Future<void> deleteFeedingSchedule(int id, int petId) async {
    await (await database).delete(
      'feeding_schedules',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [id, petId],
    );
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(int petId) async {
    final rows = await (await database).query(
      'vaccinations',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date_given DESC, id DESC',
    );
    return rows.map(Vaccination.fromMap).toList();
  }

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async {
    final map = vaccination.toMap();
    map.remove('id');
    final id = await (await database).insert('vaccinations', map);
    return vaccination.copyWith(id: id);
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
      whereArgs: [id, vaccination.petId],
    );
  }

  @override
  Future<void> deleteVaccination(int id, int petId) async {
    await (await database).delete(
      'vaccinations',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [id, petId],
    );
  }

  @override
  Future<List<Vet>> getAllVets() async => (await (await database).query(
    'vets',
    orderBy: 'name COLLATE NOCASE',
  )).map(Vet.fromMap).toList();

  @override
  Future<List<Vet>> getVetsForPet(int petId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT vets.* FROM vets INNER JOIN vet_pets ON vets.id = vet_pets.vet_id
      WHERE vet_pets.pet_id = ? ORDER BY vets.name COLLATE NOCASE
    ''',
      [petId],
    );
    return rows.map(Vet.fromMap).toList();
  }

  @override
  Future<Vet?> getVetById(int id) async {
    final rows = await (await database).query(
      'vets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Vet.fromMap(rows.first);
  }

  @override
  Future<List<Pet>> getPetsForVet(int vetId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT pets.* FROM pets INNER JOIN vet_pets ON pets.id = vet_pets.pet_id
      WHERE vet_pets.vet_id = ? ORDER BY pets.name COLLATE NOCASE
    ''',
      [vetId],
    );
    return rows.map(_petFromMap).toList();
  }

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(int vetId) async =>
      (await (await database).query(
        'vet_pets',
        where: 'vet_id = ?',
        whereArgs: [vetId],
      )).map(VetPetAssociation.fromMap).toList();

  @override
  Future<Vet> addVet(Vet vet, List<int> petIds) async {
    final db = await database;
    late Vet saved;
    await db.transaction((txn) async {
      final values = vet.toMap()..remove('id');
      final id = await txn.insert('vets', values);
      saved = vet.copyWith(id: id);
      for (final petId in petIds.toSet()) {
        await txn.insert('vet_pets', {'vet_id': id, 'pet_id': petId});
      }
    });
    return saved;
  }

  @override
  Future<void> updateVet(Vet vet, List<int> petIds) async {
    final id = vet.id;
    if (id == null) throw ArgumentError('Vet id is required to update.');
    final db = await database;
    await db.transaction((txn) async {
      final values = vet.toMap()..remove('id');
      await txn.update('vets', values, where: 'id = ?', whereArgs: [id]);
      await txn.delete('vet_pets', where: 'vet_id = ?', whereArgs: [id]);
      for (final petId in petIds.toSet()) {
        await txn.insert('vet_pets', {'vet_id': id, 'pet_id': petId});
      }
    });
  }

  @override
  Future<void> deleteVet(int id) async =>
      (await database).delete('vets', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> setNextAppointment(int vetId, int petId, DateTime? date) async {
    await (await database).update(
      'vet_pets',
      {'next_appointment_date': date?.toIso8601String()},
      where: 'vet_id = ? AND pet_id = ?',
      whereArgs: [vetId, petId],
    );
  }

  @override
  Future<List<WeightLog>> getWeightLogsForPet(int petId) async =>
      (await (await database).query(
        'weight_logs',
        where: 'pet_id = ?',
        whereArgs: [petId],
        orderBy: 'date DESC, id DESC',
      )).map(WeightLog.fromMap).toList();

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async {
    final values = log.toMap()..remove('id');
    final id = await (await database).insert('weight_logs', values);
    return WeightLog(
      id: id,
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
      whereArgs: [id, log.petId],
    );
  }

  @override
  Future<void> deleteWeightLog(int id, int petId) async =>
      (await database).delete(
        'weight_logs',
        where: 'id = ? AND pet_id = ?',
        whereArgs: [id, petId],
      );

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(int petId) async {
    final rows = await (await database).query(
      'health_records',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async {
    final map = record.toMap()..remove('id');
    final id = await (await database).insert('health_records', map);
    return record.copyWith(id: id);
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
      whereArgs: [id, record.petId],
    );
  }

  @override
  Future<void> deleteHealthRecord(int id, int petId) async {
    await (await database).delete(
      'health_records',
      where: 'id = ? AND pet_id = ?',
      whereArgs: [id, petId],
    );
  }
}

class WebPetRepository implements PetRepository {
  static const _storageKey = 'furlo.pets';
  static const _feedingStorageKey = 'furlo.feeding_schedules';
  final List<Vaccination> _vaccinations = [];
  final List<HealthRecord> _healthRecords = [];
  final List<Vet> _vets = [];
  final List<VetPetAssociation> _vetLinks = [];
  final List<WeightLog> _weightLogs = [];

  @override
  Future<List<Pet>> getPets() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_storageKey) ?? [];
    final pets = values.map((value) => _petFromMap(_decodeMap(value))).toList();
    var nextId = pets.fold<int>(0, (maxId, pet) {
      final id = pet.id ?? 0;
      return id > maxId ? id : maxId;
    });
    var migrated = false;
    for (var index = 0; index < pets.length; index++) {
      final pet = pets[index];
      if (pet.id != null) continue;
      migrated = true;
      nextId++;
      pets[index] = Pet(
        id: nextId,
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
              final existingId = existing.id ?? 0;
              return existingId > maxId ? existingId : maxId;
            }) +
            1);
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
  Future<void> deletePet(int id) async {
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
    _healthRecords.removeWhere((record) => record.petId == id);
    _vetLinks.removeWhere((link) => link.petId == id);
    _weightLogs.removeWhere((log) => log.petId == id);
  }

  @override
  Future<void> clearAllData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
      await preferences.remove(_feedingStorageKey);
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
  Future<List<FeedingEntry>> getFeedingSchedules(int petId) async {
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
              final existingId = existing.id ?? 0;
              return existingId > maxId ? existingId : maxId;
            }) +
            1);
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
  Future<void> deleteFeedingSchedule(int id, int petId) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_feedingStorageKey) ?? [];
    final entries = values
        .map((value) => _feedingEntryFromMap(_decodeMap(value)))
        .where((entry) => !(entry.id == id && entry.petId == petId))
        .toList();
    await _saveFeedingEntries(preferences, entries);
  }

  @override
  Future<List<Vaccination>> getVaccinationsForPet(int petId) async =>
      _vaccinations
          .where((item) => item.petId == petId)
          .map((item) => Vaccination.fromMap(item.toMap()))
          .toList();

  @override
  Future<Vaccination> addVaccination(Vaccination vaccination) async {
    final nextId =
        _vaccinations.fold<int>(0, (maxId, item) {
          final id = item.id ?? 0;
          return id > maxId ? id : maxId;
        }) +
        1;
    final saved = vaccination.copyWith(id: vaccination.id ?? nextId);
    _vaccinations.add(saved);
    return saved;
  }

  @override
  Future<void> updateVaccination(Vaccination vaccination) async {
    final id = vaccination.id;
    if (id == null) {
      throw ArgumentError('Vaccination id is required to update.');
    }
    final index = _vaccinations.indexWhere(
      (item) => item.id == id && item.petId == vaccination.petId,
    );
    if (index < 0) return;
    _vaccinations[index] = vaccination;
  }

  @override
  Future<void> deleteVaccination(int id, int petId) async {
    _vaccinations.removeWhere((item) => item.id == id && item.petId == petId);
  }

  @override
  Future<List<HealthRecord>> getHealthRecordsForPet(int petId) async {
    final records = _healthRecords
        .where((record) => record.petId == petId)
        .toList();
    records.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate == null && bDate == null) {
        return (b.id ?? 0).compareTo(a.id ?? 0);
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      final dateOrder = bDate.compareTo(aDate);
      return dateOrder == 0 ? (b.id ?? 0).compareTo(a.id ?? 0) : dateOrder;
    });
    return records;
  }

  @override
  Future<HealthRecord> addHealthRecord(HealthRecord record) async {
    final nextId =
        _healthRecords.fold<int>(0, (maxId, item) {
          final id = item.id ?? 0;
          return id > maxId ? id : maxId;
        }) +
        1;
    final saved = record.copyWith(id: record.id ?? nextId);
    _healthRecords.add(saved);
    return saved;
  }

  @override
  Future<void> updateHealthRecord(HealthRecord record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError('Health record id is required to update.');
    }
    final index = _healthRecords.indexWhere(
      (item) => item.id == id && item.petId == record.petId,
    );
    if (index >= 0) _healthRecords[index] = record;
  }

  @override
  Future<void> deleteHealthRecord(int id, int petId) async {
    _healthRecords.removeWhere((item) => item.id == id && item.petId == petId);
  }

  @override
  Future<List<Vet>> getAllVets() async => List.of(_vets);

  @override
  Future<List<Vet>> getVetsForPet(int petId) async => _vets
      .where(
        (vet) => _vetLinks.any(
          (link) => link.vetId == vet.id && link.petId == petId,
        ),
      )
      .toList();

  @override
  Future<Vet?> getVetById(int id) async {
    for (final vet in _vets) {
      if (vet.id == id) return vet;
    }
    return null;
  }

  @override
  Future<List<Pet>> getPetsForVet(int vetId) async {
    final ids = _vetLinks
        .where((link) => link.vetId == vetId)
        .map((link) => link.petId)
        .toSet();
    return (await getPets()).where((pet) => ids.contains(pet.id)).toList();
  }

  @override
  Future<List<VetPetAssociation>> getVetPetAssociations(int vetId) async =>
      _vetLinks.where((link) => link.vetId == vetId).toList();

  @override
  Future<Vet> addVet(Vet vet, List<int> petIds) async {
    final id =
        vet.id ??
        (_vets.fold<int>(
              0,
              (max, item) => (item.id ?? 0) > max ? item.id! : max,
            ) +
            1);
    final saved = vet.copyWith(id: id);
    _vets.add(saved);
    for (final petId in petIds.toSet()) {
      _vetLinks.add(VetPetAssociation(vetId: id, petId: petId));
    }
    return saved;
  }

  @override
  Future<void> updateVet(Vet vet, List<int> petIds) async {
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
  }

  @override
  Future<void> deleteVet(int id) async {
    _vets.removeWhere((vet) => vet.id == id);
    _vetLinks.removeWhere((link) => link.vetId == id);
  }

  @override
  Future<void> setNextAppointment(int vetId, int petId, DateTime? date) async {
    final index = _vetLinks.indexWhere(
      (link) => link.vetId == vetId && link.petId == petId,
    );
    if (index >= 0) {
      _vetLinks[index] = VetPetAssociation(
        vetId: vetId,
        petId: petId,
        nextAppointmentDate: date,
      );
    }
  }

  @override
  Future<List<WeightLog>> getWeightLogsForPet(int petId) async {
    final logs = _weightLogs.where((log) => log.petId == petId).toList();
    logs.sort((a, b) {
      final dateOrder = (b.date ?? DateTime(0)).compareTo(
        a.date ?? DateTime(0),
      );
      return dateOrder == 0 ? (b.id ?? 0).compareTo(a.id ?? 0) : dateOrder;
    });
    return logs;
  }

  @override
  Future<WeightLog> addWeightLog(WeightLog log) async {
    final id =
        log.id ??
        (_weightLogs.fold<int>(
              0,
              (max, item) => (item.id ?? 0) > max ? item.id! : max,
            ) +
            1);
    final saved = WeightLog(
      id: id,
      petId: log.petId,
      date: log.date,
      weight: log.weight,
      notes: log.notes,
    );
    _weightLogs.add(saved);
    return saved;
  }

  @override
  Future<void> updateWeightLog(WeightLog log) async {
    final id = log.id;
    if (id == null) throw ArgumentError('Weight log id is required to update.');
    final index = _weightLogs.indexWhere(
      (item) => item.id == id && item.petId == log.petId,
    );
    if (index >= 0) _weightLogs[index] = log;
  }

  @override
  Future<void> deleteWeightLog(int id, int petId) async {
    _weightLogs.removeWhere((log) => log.id == id && log.petId == petId);
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

Map<String, Object?> _petToMap(Pet pet) => {
  'id': pet.id,
  'name': pet.name,
  'species': pet.species,
  'breed': pet.breed,
  'birthDate': pet.birthDate?.toIso8601String(),
  'photoPath': pet.photoPath,
};

Pet _petFromMap(Map<String, Object?> row) => Pet(
  id: int.tryParse(row['id']?.toString() ?? ''),
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
  'days_of_week': entry.daysOfWeek.join(','),
  'portion_size': entry.portionSize,
  'remind_me': entry.remindMe ? 1 : 0,
  'last_fed_at': entry.lastFedAt?.toIso8601String(),
  'done_today': entry.doneToday ? 1 : 0,
};

FeedingEntry _feedingEntryFromMap(Map<String, Object?> row) => FeedingEntry(
  id: int.tryParse(row['id']?.toString() ?? ''),
  petId: int.parse(row['pet_id']?.toString() ?? '0'),
  name: row['name']?.toString() ?? '',
  time: row['scheduled_time']?.toString() ?? '08:00',
  frequency: row['frequency']?.toString() ?? 'Daily',
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
