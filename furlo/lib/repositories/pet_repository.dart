import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/feeding_entry.dart';
import '../models/pet.dart';

abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
  Future<List<FeedingEntry>> getFeedingSchedules(int petId);
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry);
  Future<void> updateFeedingSchedule(FeedingEntry entry);
  Future<void> deleteFeedingSchedule(int id, int petId);
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
      version: 4,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createFeedingSchedulesTable(db);
        }
        if (oldVersion < 4) await _ensureFeedingScheduleColumns(db);
      },
      onOpen: (db) async {
        await _createFeedingSchedulesTable(db);
        await _ensureFeedingScheduleColumns(db);
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
}

class WebPetRepository implements PetRepository {
  static const _storageKey = 'furlo.pets';
  static const _feedingStorageKey = 'furlo.feeding_schedules';

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
