import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../repositories/pet_repository.dart';
import '../utils/app_diagnostics.dart';

/// Records whether the one-time local-to-cloud copy already happened.
abstract interface class MigrationMarker {
  Future<bool> isComplete();
  Future<void> markComplete();
}

/// Marker stored in the account's own `users/{uid}/settings/meta` document.
class FirestoreMigrationMarker implements MigrationMarker {
  FirestoreMigrationMarker({
    required String userUid,
    FirebaseFirestore? database,
  }) : _uid = userUid,
       _db = database ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _document =>
      _db.collection('users').doc(_uid).collection('settings').doc('meta');

  @override
  Future<bool> isComplete() async {
    final snapshot = await _document.get();
    return snapshot.data()?['localMigratedAt'] != null;
  }

  @override
  Future<void> markComplete() => _document.set({
    'localMigratedAt': DateTime.now().toIso8601String(),
    'schemaVersion': 1,
  }, SetOptions(merge: true));
}

/// One-time copy of device-local pet data into the signed-in account's cloud data.
///
/// The local stores are read but never cleared or rewritten, so nothing already
/// on the device is destroyed. It runs at most once per account, guarded by a
/// [MigrationMarker] and by an empty-cloud check, so it cannot duplicate records.
class LegacyLocalMigration {
  LegacyLocalMigration({
    required this.uid,
    required this.target,
    MigrationMarker? marker,
    FirebaseFirestore? database,
    List<PetRepository>? legacySources,
  }) : _markerOverride = marker,
       _firestoreOverride = database,
       _legacySourcesOverride = legacySources;

  final String uid;

  /// Cloud repository that becomes the system of record.
  final PetRepository target;

  final MigrationMarker? _markerOverride;
  final FirebaseFirestore? _firestoreOverride;
  final List<PetRepository>? _legacySourcesOverride;

  MigrationMarker get _marker =>
      _markerOverride ??
      FirestoreMigrationMarker(userUid: uid, database: _firestoreOverride);

  /// Copies local rows into the account. Returns true when rows were copied.
  Future<bool> run() async {
    try {
      if (await _marker.isComplete()) return false;
      if ((await target.getPets()).isNotEmpty) {
        await _marker.markComplete();
        return false;
      }
      var migrated = false;
      for (final source in _legacySources()) {
        migrated = await _copyFrom(source) || migrated;
      }
      await _marker.markComplete();
      return migrated;
    } catch (_) {
      // Migration is best-effort: it must never block or lose a session.
      logAppDiagnostic('Local data migration could not be completed.');
      return false;
    }
  }

  /// The pre-account store and the earlier per-account store, both read-only.
  List<PetRepository> _legacySources() =>
      _legacySourcesOverride ??
      [
        if (kIsWeb) ...[
          WebPetRepository(storageScope: null),
          WebPetRepository(storageScope: uid),
        ] else ...[
          SqlitePetRepository(storageScope: null),
          SqlitePetRepository(storageScope: uid),
        ],
      ];

  Future<bool> _copyFrom(PetRepository source) async {
    final copiedIds = <String>{};
    var copied = false;

    for (final pet in await source.getPets()) {
      final id = pet.id;
      if (id == null || copiedIds.contains(id)) continue;
      copiedIds.add(id);
      await target.addPet(pet);
      copied = true;

      for (final entry in await source.getFeedingSchedules(id)) {
        await target.addFeedingSchedule(entry);
      }
      for (final record in await source.getHealthRecordsForPet(id)) {
        await target.addHealthRecord(record);
      }
      for (final vaccination in await source.getVaccinationsForPet(id)) {
        await target.addVaccination(vaccination);
      }
      for (final log in await source.getWeightLogsForPet(id)) {
        await target.addWeightLog(log);
      }
    }

    for (final vet in await source.getAllVets()) {
      final links = await source.getVetPetAssociations(vet.id!);
      final petIds = links
          .map((link) => link.petId)
          .where(copiedIds.contains)
          .toList();
      if (petIds.isEmpty) continue;
      final saved = await target.addVet(vet, petIds);
      for (final link in links) {
        if (!copiedIds.contains(link.petId)) continue;
        await target.setNextAppointment(
          saved.id!,
          link.petId,
          link.nextAppointmentDate,
        );
      }
    }
    return copied;
  }
}
