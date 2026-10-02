import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../models/vaccination.dart';
import '../repositories/pet_repository.dart';
import '../services/notifications_service.dart';

class VaccinationsProvider extends ChangeNotifier {
  VaccinationsProvider({
    required this.repository,
    this.notificationService = const NoOpNotificationService(),
    required this.pets,
    Pet? selectedPet,
  }) : _selectedPet = selectedPet ?? pets.firstOrNull {
    refresh();
  }

  final PetRepository repository;
  final NotificationService notificationService;
  final List<Pet> pets;
  Pet? _selectedPet;
  List<Vaccination> _vaccinations = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Pet? get selectedPet => _selectedPet;
  List<Vaccination> get vaccinations => List.unmodifiable(_vaccinations);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> selectPet(Pet pet) async {
    if (_selectedPet?.id == pet.id) return;
    _selectedPet = pet;
    _vaccinations = [];
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final petId = _selectedPet?.id;
    if (petId == null) {
      _vaccinations = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final records = await repository.getVaccinationsForPet(petId);
      if (_selectedPet?.id == petId) _vaccinations = records;
    } catch (_) {
      _error = 'Vaccinations could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(Vaccination vaccination) async {
    _saving = true;
    notifyListeners();
    try {
      if (vaccination.id == null) {
        await repository.addVaccination(vaccination);
      } else {
        await repository.updateVaccination(vaccination);
      }
      await notificationService.rescheduleAll();
      await refresh();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(Vaccination vaccination) async {
    final id = vaccination.id;
    if (id == null) return;
    await repository.deleteVaccination(id, vaccination.petId);
    await notificationService.rescheduleAll();
    await refresh();
  }

  Future<void> toggleCompletion(Vaccination vaccination) async {
    final id = vaccination.id;
    if (id == null) return;
    _saving = true;
    notifyListeners();
    try {
      await repository.updateVaccination(
        vaccination.copyWith(isCompleted: !vaccination.isCompleted),
      );
      await notificationService.rescheduleAll();
      await refresh();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
