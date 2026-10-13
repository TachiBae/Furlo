part of 'pet_repository.dart';

// The production store: Cloud Firestore under users/{uid}.

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

  /// Maps documents to records, skipping any one that cannot be read.
  ///
  /// Mirrors the web store's `_decodeRecords`: one malformed document (an
  /// older shape, a hand-edited field) must not take the healthy ones down.
  List<T> _readDocs<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(Map<String, Object?> map) fromMap,
  ) {
    final records = <T>[];
    for (final doc in docs) {
      try {
        records.add(fromMap({...doc.data(), 'id': doc.id}));
      } on Object {
        _logSkipped();
      }
    }
    return records;
  }

  void _logSkipped() =>
      logAppDiagnostic('Skipped a cloud record that could not be read.');

  @override
  Future<List<Pet>> getPets() async {
    final snapshot = await _col(_pets).get();
    final pets = await Future.wait(
      snapshot.docs.map((doc) async {
        try {
          final photo = await resolvePetPhoto(doc.data(), doc.id, _photos);
          return _petFromMap({...doc.data(), 'id': doc.id, 'photoPath': photo});
        } on Object {
          _logSkipped();
          return null;
        }
      }),
    );
    // Firestore lists documents by their random ids, so without a sort the
    // pets reshuffle whenever one is added. Name order is stable and
    // predictable (case-insensitive, id as the tie-breaker).
    return pets.nonNulls.toList()..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : (a.id ?? '').compareTo(b.id ?? '');
    });
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
    final petIds = <String>[];
    for (final name in _all) {
      final snapshot = await _col(name).get();
      refs.addAll(snapshot.docs.map((doc) => doc.reference));
      if (name == _pets) petIds.addAll(snapshot.docs.map((doc) => doc.id));
    }
    await _deleteBatch(refs);
    // The photos cached on this device go too: deleted means deleted.
    for (final id in petIds) {
      await _photos.write(id, null);
    }
  }

  @override
  Future<List<FeedingEntry>> getFeedingSchedules(String petId) async {
    final snapshot = await _col(
      _feedings,
    ).where('pet_id', isEqualTo: petId).get();
    final entries = _readDocs(snapshot.docs, _feedingEntryFromMap);
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
    final records = _readDocs(snapshot.docs, Vaccination.fromMap);
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
    final records = _readDocs(snapshot.docs, HealthRecord.fromMap);
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
    final vets = _readDocs(snapshot.docs, Vet.fromMap);
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
    try {
      return Vet.fromMap({...doc.data()!, 'id': doc.id});
    } on Object {
      _logSkipped();
      return null;
    }
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
    return _readDocs(snapshot.docs, VetPetAssociation.fromMap);
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
    final previous = await _col(_vetLinks).where('vet_id', isEqualTo: id).get();
    final keep = petIds.toSet();
    final linked = <String>{};
    final batch = _firestore.batch();
    batch.set(_col(_vets).doc(id), vet.toMap()..remove('id'));
    // Kept links are left untouched so their next appointment survives an
    // edit of the vet; only unlinked pets lose their link.
    for (final doc in previous.docs) {
      final petId = doc.data()['pet_id']?.toString();
      if (petId != null && keep.contains(petId)) {
        linked.add(petId);
      } else {
        batch.delete(doc.reference);
      }
    }
    for (final petId in keep.difference(linked)) {
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
    final logs = _readDocs(snapshot.docs, WeightLog.fromMap);
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

  @override
  Future<List<FeedingEntry>> getAllFeedingSchedules() async {
    final entries = _readDocs(
      (await _col(_feedings).get()).docs,
      _feedingEntryFromMap,
    );
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  @override
  Future<List<Vaccination>> getAllVaccinations() async =>
      _readDocs((await _col(_vaccinations).get()).docs, Vaccination.fromMap);

  @override
  Future<List<HealthRecord>> getAllHealthRecords() async =>
      _readDocs((await _col(_healthRecords).get()).docs, HealthRecord.fromMap);

  @override
  Future<List<VetPetAssociation>> getAllVetLinks() async =>
      _readDocs((await _col(_vetLinks).get()).docs, VetPetAssociation.fromMap);

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
