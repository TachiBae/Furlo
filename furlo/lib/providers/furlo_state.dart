import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../repositories/pet_repository.dart';

class FurloState with ChangeNotifier {
  FurloState(this._repository);

  final PetRepository _repository;
  int _loadGeneration = 0;
  bool _disposed = false;
  List<Pet> _pets = const [];
  String? _selectedPetId;
  bool _isLoading = true;
  Object? _loadError;

  List<Pet> get pets => List.unmodifiable(_pets);
  Pet? get selectedPet =>
      _pets.where((pet) => pet.id == _selectedPetId).firstOrNull;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _isLoading = true;
    _loadError = null;
    _notifyIfActive();
    try {
      final pets = await _repository.getPets();
      if (_disposed || generation != _loadGeneration) return;
      _setPets(pets);
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _loadError = error;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> addPet(Pet pet) async {
    final previousPetIds = _pets.map((item) => item.id).toSet();
    await _repository.addPet(pet);
    final pets = await _repository.getPets();
    if (_disposed) return;
    final addedPet = pets
        .where((item) => !previousPetIds.contains(item.id))
        .firstOrNull;
    _setPets(pets, preferredPetId: addedPet?.id);
    _notifyIfActive();
  }

  Future<void> updatePet(Pet pet) async {
    await _repository.updatePet(pet);
    final pets = await _repository.getPets();
    if (_disposed) return;
    _setPets(pets);
    _notifyIfActive();
  }

  Future<void> deletePet(String id) async {
    await _repository.deletePet(id);
    final pets = await _repository.getPets();
    if (_disposed) return;
    _setPets(pets);
    _notifyIfActive();
  }

  void resetForSession() {
    if (_disposed) return;
    _loadGeneration++;
    _pets = const [];
    _selectedPetId = null;
    _loadError = null;
    _isLoading = true;
    _notifyIfActive();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  void selectPet(Pet pet) {
    if (_disposed || !_pets.any((item) => item.id == pet.id)) return;
    _selectedPetId = pet.id;
    _notifyIfActive();
  }

  void _setPets(List<Pet> pets, {String? preferredPetId}) {
    _pets = List.of(pets);
    if (_pets.any((pet) => pet.id == _selectedPetId)) return;
    _selectedPetId = preferredPetId ?? _pets.firstOrNull?.id;
  }
}
