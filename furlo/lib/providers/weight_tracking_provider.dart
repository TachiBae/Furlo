import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../models/weight_log.dart';
import '../repositories/pet_repository.dart';

class WeightTrackingProvider extends ChangeNotifier {
  WeightTrackingProvider({
    required this.repository,
    required List<Pet> pets,
    Pet? selectedPet,
  }) : pets = List.unmodifiable(pets),
       _selectedPet = selectedPet ?? pets.firstOrNull {
    refresh();
  }

  final PetRepository repository;
  final List<Pet> pets;
  Pet? _selectedPet;
  List<WeightLog> _logs = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Pet? get selectedPet => _selectedPet;
  List<WeightLog> get logs => List.unmodifiable(_logs);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> selectPet(Pet pet) async {
    if (_selectedPet?.id == pet.id) return;
    _selectedPet = pet;
    _logs = [];
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final petId = _selectedPet?.id;
    if (petId == null) {
      _logs = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final logs = await repository.getWeightLogsForPet(petId);
      if (_selectedPet?.id == petId) _logs = logs;
    } catch (_) {
      _error = 'Weight entries could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(WeightLog log) async {
    _saving = true;
    notifyListeners();
    try {
      if (log.id == null) {
        await repository.addWeightLog(log);
      } else {
        await repository.updateWeightLog(log);
      }
      await refresh();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(WeightLog log) async {
    final id = log.id;
    if (id == null) return;
    await repository.deleteWeightLog(id, log.petId);
    await refresh();
  }
}
