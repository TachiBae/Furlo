import 'package:furlo/services/account_onboarding_repository.dart';

class FakeAccountOnboardingRepository implements AccountOnboardingRepository {
  final deletedRecords = <String>[];

  @override
  Future<void> deleteAccountRecord(String uid) async {
    deletedRecords.add(uid);
    _needsFirstPet.remove(uid);
  }

  final Set<String> _needsFirstPet = {};

  @override
  Future<bool> requiresFirstPet(String uid) async =>
      _needsFirstPet.contains(uid);

  @override
  Future<void> markFirstPetRequired(String uid) async {
    _needsFirstPet.add(uid);
  }

  @override
  Future<void> markFirstPetComplete(String uid) async {
    _needsFirstPet.remove(uid);
  }
}
