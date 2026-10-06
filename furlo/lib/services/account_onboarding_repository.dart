import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class AccountOnboardingRepository {
  Future<bool> requiresFirstPet(String uid);
  Future<void> markFirstPetRequired(String uid);
  Future<void> markFirstPetComplete(String uid);
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
}
