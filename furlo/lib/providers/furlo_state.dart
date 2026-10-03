import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../repositories/pet_repository.dart';

class FurloState with ChangeNotifier {
  FurloState(this._repository);

  final PetRepository _repository;
  List<Pet> _pets = const [];
  int? _selectedPetId;
  bool _isLoading = true;
  Object? _loadError;

  List<Pet> get pets => List.unmodifiable(_pets);
  Pet? get selectedPet =>
      _pets.where((pet) => pet.id == _selectedPetId).firstOrNull;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _setPets(await _repository.getPets());
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPet(Pet pet) async {
    final previousPetIds = _pets.map((item) => item.id).toSet();
    await _repository.addPet(pet);
    final pets = await _repository.getPets();
    final addedPet = pets
        .where((item) => !previousPetIds.contains(item.id))
        .firstOrNull;
    _setPets(pets, preferredPetId: addedPet?.id);
    notifyListeners();
  }

  Future<void> updatePet(Pet pet) async {
    await _repository.updatePet(pet);
    _setPets(await _repository.getPets());
    notifyListeners();
  }

  Future<void> deletePet(int id) async {
    await _repository.deletePet(id);
    _setPets(await _repository.getPets());
    notifyListeners();
  }

  void selectPet(Pet pet) {
    if (!_pets.any((item) => item.id == pet.id)) return;
    _selectedPetId = pet.id;
    notifyListeners();
  }

  void _setPets(List<Pet> pets, {int? preferredPetId}) {
    _pets = List.of(pets);
    if (_pets.any((pet) => pet.id == _selectedPetId)) return;
    _selectedPetId =
        preferredPetId ?? _pets.firstOrNull?.id;
  }
}
