import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class AccountOnboardingRepository {
  Future<bool> requiresFirstPet(String uid);
  Future<void> markFirstPetRequired(String uid);
  Future<void> markFirstPetComplete(String uid);

  /// Removes the account's onboarding record (account deletion).
  Future<void> deleteAccountRecord(String uid);
}

class FirestoreAccountOnboardingRepository
    implements AccountOnboardingRepository {
  FirestoreAccountOnboardingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _collection = 'accountMetadata';
  static const _field = 'requiresFirstPet';

  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      _firestore.collection(_collection).doc(uid);

  @override
  Future<bool> requiresFirstPet(String uid) async {
    final snapshot = await _document(uid).get();
    return snapshot.data()?[_field] == true;
  }

  @override
  Future<void> markFirstPetRequired(String uid) async {
    await _document(uid).set({_field: true}, SetOptions(merge: true));
  }

  @override
  Future<void> markFirstPetComplete(String uid) async {
    await _document(uid).set({_field: false}, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAccountRecord(String uid) async {
    try {
      await _document(uid).delete();
    } on FirebaseException catch (error) {
      // Rules deployed before account deletion forbid this delete. The
      // record holds only a boolean flag, nothing personal, so it can stay.
      if (error.code != 'permission-denied') rethrow;
    }
  }
}

/// Profile details a brand-new Google account must complete before the app
/// lets it in.
///
/// The marker lives on the account's own `users/{uid}/settings/profile`
/// document, which the published rules already allow to be written, unlike
/// `accountMetadata/{uid}` whose keys are restricted to `requiresFirstPet`.
abstract interface class AccountProfileRepository {
  /// True only when the marker explicitly says the profile is unfinished.
  ///
  /// Accounts with no marker at all predate this step and are treated as
  /// complete, so existing accounts are never pushed through it.
  Future<bool> requiresProfileCompletion(String uid);

  /// Flags a brand-new Google account as needing the completion step.
  Future<void> markProfileRequired(String uid);

  /// Writes the profile and records completion.
  Future<void> completeProfile(
    String uid, {
    required String fullName,
    required String displayName,
  });

  /// True once the account has saved its first pet.
  ///
  /// An account with no marker and no pets never finished setup, so the gate
  /// sends it to onboarding; an established account that later deletes every
  /// pet keeps the marker and stays on the dashboard.
  Future<bool> isSetupComplete(String uid);

  /// Records that the account's first pet was saved.
  Future<void> markSetupComplete(String uid);

  /// The display name saved on the account, or null when none was saved.
  Future<String?> getDisplayName(String uid);

  /// Saves the display name on the account, so every device shows it.
  Future<void> setDisplayName(String uid, String displayName);

  /// Removes the account's profile and settings documents (account
  /// deletion).
  Future<void> deleteProfile(String uid);
}

/// [AccountProfileRepository] backed by `users/{uid}/settings/profile`.
class FirestoreAccountProfileRepository implements AccountProfileRepository {
  FirestoreAccountProfileRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  /// Resolved on first use so constructing this never needs a live Firebase
  /// app; the gate only touches it in a real session.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const _settings = 'settings';
  static const _profile = 'profile';
  static const _field = 'profileCompleted';
  static const _setupField = 'setupCompleted';

  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection(_settings)
      .doc(_profile);

  @override
  Future<bool> requiresProfileCompletion(String uid) async {
    final snapshot = await _document(uid).get();
    return snapshot.data()?[_field] == false;
  }

  @override
  Future<void> markProfileRequired(String uid) =>
      _document(uid).set({_field: false}, SetOptions(merge: true));

  @override
  Future<void> completeProfile(
    String uid, {
    required String fullName,
    required String displayName,
  }) => _document(uid).set({
    'fullName': fullName,
    'displayName': displayName,
    _field: true,
    'updatedAt': DateTime.now().toIso8601String(),
  });

  @override
  Future<bool> isSetupComplete(String uid) async {
    final snapshot = await _document(uid).get();
    return snapshot.data()?[_setupField] == true;
  }

  @override
  Future<void> markSetupComplete(String uid) => _document(uid).set({
    _setupField: true,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));

  @override
  Future<String?> getDisplayName(String uid) async {
    final value = (await _document(uid).get()).data()?['displayName'];
    return value is String ? value : null;
  }

  @override
  Future<void> setDisplayName(String uid, String displayName) =>
      _document(uid).set({
        'displayName': displayName,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

  @override
  Future<void> deleteProfile(String uid) async {
    try {
      await _document(uid).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // Rules deployed before account deletion allow updates only: blank
      // the personal fields so no name outlives the account.
      await _document(uid).set({
        'fullName': '',
        'displayName': '',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }
    try {
      // The migration marker holds only timestamps.
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_settings)
          .doc('meta')
          .delete();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }
  }
}

/// [AccountProfileRepository] that never asks for setup work.
///
/// Used when the app runs with an injected repository, i.e. in tests, where no
/// Firebase project sits behind the gate: it reports no pending completion
/// step and treats setup as already done, so harnesses keep the routing they
/// had before the marker existed.
class NoOpAccountProfileRepository implements AccountProfileRepository {
  const NoOpAccountProfileRepository();

  @override
  Future<bool> requiresProfileCompletion(String uid) async => false;

  @override
  Future<void> markProfileRequired(String uid) async {}

  @override
  Future<void> completeProfile(
    String uid, {
    required String fullName,
    required String displayName,
  }) async {}

  @override
  Future<bool> isSetupComplete(String uid) async => true;

  @override
  Future<void> markSetupComplete(String uid) async {}

  @override
  Future<String?> getDisplayName(String uid) async => null;

  @override
  Future<void> setDisplayName(String uid, String displayName) async {}

  @override
  Future<void> deleteProfile(String uid) async {}
}
