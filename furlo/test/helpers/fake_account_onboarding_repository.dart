import 'package:furlo/services/account_onboarding_repository.dart';

class FakeAccountOnboardingRepository implements AccountOnboardingRepository {
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
