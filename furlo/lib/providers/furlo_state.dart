import 'package:flutter/foundation.dart';
import '../models/pet.dart';

class FurloState with ChangeNotifier {
  List<Pet> _pets = const [];
  int? _selectedPetId;

  List<Pet> get pets => List.unmodifiable(_pets);
  Pet? get selectedPet =>
      _pets.where((pet) => pet.id == _selectedPetId).firstOrNull ??
      _pets.firstOrNull;

  void setPets(List<Pet> pets) {
    _pets = List.of(pets);
    if (!_pets.any((pet) => pet.id == _selectedPetId)) {
      _selectedPetId = _pets.firstOrNull?.id;
    }
    notifyListeners();
  }

  void selectPet(Pet pet) {
    if (!_pets.any((item) => item.id == pet.id)) return;
    _selectedPetId = pet.id;
    notifyListeners();
  }
}
