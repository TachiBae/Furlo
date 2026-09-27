import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/pet.dart';

abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
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
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE pets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          species TEXT NOT NULL,
          breed TEXT,
          birthDate TEXT,
          photoPath TEXT
        )
      '''),
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
}

class WebPetRepository implements PetRepository {
  static const _storageKey = 'furlo.pets';

  @override
  Future<List<Pet>> getPets() async {
    final values =
        (await SharedPreferences.getInstance()).getStringList(_storageKey) ??
        [];
    return values
        .map(
          (value) => _petFromMap(
            Map<String, Object?>.from(
              Uri.splitQueryString(
                value,
              ).map((key, value) => MapEntry(key, value)),
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> addPet(Pet pet) async {
    final preferences = await SharedPreferences.getInstance();
    final pets = await getPets();
    pets.add(pet);
    await preferences.setStringList(
      _storageKey,
      pets
          .map(
            (item) => Uri(
              queryParameters: _petToMap(
                item,
              ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
            ).query,
          )
          .toList(),
    );
  }
}

Map<String, Object?> _petToMap(Pet pet) => {
  'name': pet.name,
  'species': pet.species,
  'breed': pet.breed,
  'birthDate': pet.birthDate?.toIso8601String(),
  'photoPath': pet.photoPath,
};

Pet _petFromMap(Map<String, Object?> row) => Pet(
  id: row['id'] is int ? row['id'] as int : null,
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
