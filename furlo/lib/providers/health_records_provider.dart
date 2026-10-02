import 'package:flutter/foundation.dart';

import '../models/health_record.dart';
import '../models/pet.dart';
import '../repositories/pet_repository.dart';
import '../services/notifications_service.dart';

class HealthRecordsProvider extends ChangeNotifier {
  HealthRecordsProvider({
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
  List<HealthRecord> _records = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Pet? get selectedPet => _selectedPet;
  List<HealthRecord> get records => List.unmodifiable(_records);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> selectPet(Pet pet) async {
    if (_selectedPet?.id == pet.id) return;
    _selectedPet = pet;
    _records = [];
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final petId = _selectedPet?.id;
    if (petId == null) {
      _records = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final records = await repository.getHealthRecordsForPet(petId);
      if (_selectedPet?.id == petId) _records = records;
    } catch (_) {
      _error = 'Health records could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(HealthRecord record) async {
    _saving = true;
    notifyListeners();
    try {
      if (record.id == null) {
        await repository.addHealthRecord(record);
      } else {
        await repository.updateHealthRecord(record);
      }
      await notificationService.rescheduleAll();
      await refresh();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(HealthRecord record) async {
    final id = record.id;
    if (id == null) return;
    await repository.deleteHealthRecord(id, record.petId);
    await notificationService.rescheduleAll();
    await refresh();
  }
}
