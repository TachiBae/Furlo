part of '../pet_repository.dart';

// Legacy on-device store (mobile). Read-only in practice: the one-time
// import reads it; new writes go to Firestore. Never add destructive steps.

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

  @override
  Future<List<FeedingEntry>> getAllFeedingSchedules() async =>
      (await (await database).query(
        'feeding_schedules',
        orderBy: 'scheduled_time',
      )).map(_feedingEntryFromMap).toList();

  @override
  Future<List<Vaccination>> getAllVaccinations() async =>
      (await (await database).query(
        'vaccinations',
        orderBy: 'date_given DESC, id DESC',
      )).map(Vaccination.fromMap).toList();

  @override
  Future<List<HealthRecord>> getAllHealthRecords() async =>
      (await (await database).query(
        'health_records',
        orderBy: 'date DESC, id DESC',
      )).map(HealthRecord.fromMap).toList();

  @override
  Future<List<VetPetAssociation>> getAllVetLinks() async =>
      (await (await database).query(
        'vet_pets',
      )).map(VetPetAssociation.fromMap).toList();
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
    second_time TEXT,
    last_second_fed_at TEXT,
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
    'second_time': 'TEXT',
    'last_second_fed_at': 'TEXT',
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
