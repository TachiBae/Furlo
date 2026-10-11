import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/pet_repository.dart';
import '../utils/app_diagnostics.dart';
import '../utils/user_storage_scope.dart';

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

/// Account-scoped local marker for the injected-repository harness, where no
/// Firebase project exists. Keyed per account so "at most once" keeps the
/// same meaning as the Firestore marker.
class SharedPreferencesMigrationMarker implements MigrationMarker {
  SharedPreferencesMigrationMarker({required String uid})
    : _key = 'legacy.user.${userStorageScopeToken(uid)}.migrated';

  final String _key;

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isComplete() async =>
      (await _preferences())?.getBool(_key) ?? false;

  @override
  Future<void> markComplete() async {
    final preferences = await _preferences();
    await preferences?.setBool(_key, true);
  }
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
  ///
  /// [resumePartial] re-runs an import that failed partway: records already
  /// present in the target are skipped instead of tripping the non-empty
  /// guard, so the retry completes without duplicating anything.
  Future<bool> run({bool resumePartial = false}) async {
    try {
      return await _run(resumePartial: resumePartial);
    } catch (_) {
      // Migration is best-effort: it must never block or lose a session.
      logAppDiagnostic('Local data migration could not be completed.');
      return false;
    }
  }

  /// The consent flow's entry point: the same copy as [run], but failures are
  /// logged with the real error and rethrown so the caller knows whether the
  /// import finished — the account's answer is recorded only on success.
  Future<void> importNow({bool resumePartial = false}) async {
    try {
      await _run(resumePartial: resumePartial);
    } catch (error, stackTrace) {
      debugPrint('Legacy import failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<bool> _run({required bool resumePartial}) async {
    if (await _marker.isComplete()) return false;
    final existing = await target.getPets();
    if (existing.isNotEmpty && !resumePartial) {
      await _marker.markComplete();
      return false;
    }
    // In a resumed run these ids belong to records the failed attempt already
    // wrote: skip them so the retry neither duplicates nor rewrites them.
    final existingPetIds = resumePartial
        ? {
            for (final pet in existing)
              if (pet.id != null) pet.id!,
          }
        : <String>{};
    var migrated = false;
    // One id set for the whole run: a source that happens to be (or mirror)
    // the target must never copy the same pet into the account twice.
    final copiedIds = <String>{};
    for (final source in _legacySources()) {
      migrated =
          await _copyFrom(source, copiedIds, existingPetIds, resumePartial) ||
          migrated;
    }
    await _marker.markComplete();
    return migrated;
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

  /// Whether the device-wide, pre-account store holds pets — the condition
  /// for asking the signed-in account to consent before anything is copied.
  ///
  /// Sources that do not expose a scope count as device data (asking when
  /// unsure is the safe direction). Read failures mean "cannot confirm it is
  /// empty", so they are reported as data present.
  Future<bool> hasPreAccountData() async {
    final sources = _legacySources();
    final deviceWide = <PetRepository>[
      for (final source in sources)
        if (_isDeviceWide(source)) source,
    ];
    for (final source in deviceWide.isEmpty ? sources : deviceWide) {
      try {
        if ((await source.getPets()).isNotEmpty) return true;
      } catch (error, stackTrace) {
        debugPrint('Legacy data check failed: $error\n$stackTrace');
        return true;
      }
    }
    return false;
  }

  bool _isDeviceWide(PetRepository source) => source is WebPetRepository
      ? source.storageScope == null
      : source is SqlitePetRepository
      ? source.storageScope == null
      : false;

  Future<bool> _copyFrom(
    PetRepository source,
    Set<String> copiedIds,
    Set<String> existingPetIds,
    bool resume,
  ) async {
    var copied = false;

    /// Copies one record type for [petId], skipping rows the failed attempt
    /// already wrote when resuming. Non-resume runs target an empty account,
    /// so they keep the original write-everything path.
    Future<bool> copyAll<T>(
      Future<List<T>> Function(PetRepository repo, String petId) read,
      Future<void> Function(T record) add,
      String? Function(T record) idOf,
      String petId,
    ) async {
      final alreadySaved = resume
          ? (await read(target, petId)).map(idOf).toSet()
          : <String?>{};
      var wrote = false;
      for (final record in await read(source, petId)) {
        if (alreadySaved.contains(idOf(record))) continue;
        await add(record);
        wrote = true;
      }
      return wrote;
    }

    for (final pet in await source.getPets()) {
      final id = pet.id;
      if (id == null || copiedIds.contains(id)) continue;
      copiedIds.add(id);
      if (!existingPetIds.contains(id)) {
        await target.addPet(pet);
        copied = true;
      }
      copied =
          await copyAll(
            (repo, petId) => repo.getFeedingSchedules(petId),
            target.addFeedingSchedule,
            (entry) => entry.id,
            id,
          ) ||
          copied;
      copied =
          await copyAll(
            (repo, petId) => repo.getHealthRecordsForPet(petId),
            target.addHealthRecord,
            (record) => record.id,
            id,
          ) ||
          copied;
      copied =
          await copyAll(
            (repo, petId) => repo.getVaccinationsForPet(petId),
            target.addVaccination,
            (vaccination) => vaccination.id,
            id,
          ) ||
          copied;
      copied =
          await copyAll(
            (repo, petId) => repo.getWeightLogsForPet(petId),
            target.addWeightLog,
            (log) => log.id,
            id,
          ) ||
          copied;
    }

    final existingVetIds = resume
        ? (await target.getAllVets()).map((vet) => vet.id).toSet()
        : <String?>{};
    for (final vet in await source.getAllVets()) {
      final vetId = vet.id!;
      final links = await source.getVetPetAssociations(vetId);
      final petIds = links
          .map((link) => link.petId)
          .where(copiedIds.contains)
          .toList();
      if (petIds.isEmpty) continue;
      var savedId = vetId;
      if (!existingVetIds.contains(vetId)) {
        final saved = await target.addVet(vet, petIds);
        savedId = saved.id!;
      }
      for (final link in links) {
        if (!copiedIds.contains(link.petId)) continue;
        // Upsert by (vet, pet) key in every target, so a resume may repeat it.
        await target.setNextAppointment(
          savedId,
          link.petId,
          link.nextAppointmentDate,
        );
      }
    }
    return copied;
  }
}
