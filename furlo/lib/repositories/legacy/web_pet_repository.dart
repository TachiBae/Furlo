part of '../pet_repository.dart';

// Legacy on-device store (web, SharedPreferences). Read-only in practice:
// the one-time import reads it; new writes go to Firestore.

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
        _decodeRecords(vaccinationValues, (v) => Vaccination.fromMap(v)),
      );

    final healthValues = preferences.getStringList(_healthRecordsKey) ?? [];
    _healthRecords
      ..clear()
      ..addAll(_decodeRecords(healthValues, (v) => HealthRecord.fromMap(v)));

    final vetValues = preferences.getStringList(_vetsKey) ?? [];
    _vets
      ..clear()
      ..addAll(_decodeRecords(vetValues, (v) => Vet.fromMap(v)));

    final vetLinkValues = preferences.getStringList(_vetLinksKey) ?? [];
    _vetLinks
      ..clear()
      ..addAll(
        _decodeRecords(vetLinkValues, (v) => VetPetAssociation.fromMap(v)),
      );

    final weightValues = preferences.getStringList(_weightLogsKey) ?? [];
    _weightLogs
      ..clear()
      ..addAll(_decodeRecords(weightValues, (v) => WeightLog.fromMap(v)));
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
    final pets = _decodeRecords(values, (value) => _petFromMap(value)).toList();
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
    final saved = Pet(
      id: id,
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      birthDate: pet.birthDate,
      photoPath: pet.photoPath,
    );
    // Re-adding a known id (a retried save) replaces it, as Firestore does.
    final existing = pets.indexWhere((item) => item.id == id);
    if (existing >= 0) {
      pets[existing] = saved;
    } else {
      pets.add(saved);
    }
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
    final feedingEntries = _decodeRecords(
      feedingValues,
      (value) => _feedingEntryFromMap(value),
    ).where((entry) => entry.petId != id).toList();
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
    final maps = _decodeMaps(values).toList();
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
    final entries = _decodeRecords(
      values,
      (value) => _feedingEntryFromMap(value),
    ).toList();
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
    final entries = _decodeRecords(
      values,
      (value) => _feedingEntryFromMap(value),
    ).toList();
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
    final entries = _decodeRecords(
      values,
      (value) => _feedingEntryFromMap(value),
    ).where((entry) => !(entry.id == id && entry.petId == petId)).toList();
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

  @override
  Future<List<FeedingEntry>> getAllFeedingSchedules() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = _decodeRecords(
      preferences.getStringList(_feedingStorageKey) ?? [],
      _feedingEntryFromMap,
    ).toList();
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  @override
  Future<List<Vaccination>> getAllVaccinations() async {
    await _ensureLoaded();
    return List.of(_vaccinations);
  }

  @override
  Future<List<HealthRecord>> getAllHealthRecords() async {
    await _ensureLoaded();
    return List.of(_healthRecords);
  }

  @override
  Future<List<VetPetAssociation>> getAllVetLinks() async {
    await _ensureLoaded();
    return List.of(_vetLinks);
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
