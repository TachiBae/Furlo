import 'package:flutter/foundation.dart';

import '../models/pet.dart';
import '../repositories/pet_repository.dart';
import '../services/notifications_service.dart';

/// Shared state for a screen that lists one pet's records of type [T]
/// (health records, vaccinations, weight logs).
///
/// Loads can finish after the screen that started them is gone, or after the
/// user picked another pet. Both cases are dropped instead of notifying: a
/// disposed notifier must never be touched, and a stale load must never
/// replace the current pet's records.
abstract class PetRecordsProvider<T> extends ChangeNotifier {
  PetRecordsProvider({
    required this.repository,
    required List<Pet> pets,
    this.notificationService = const NoOpNotificationService(),
    Pet? selectedPet,
  }) : pets = List.unmodifiable(pets),
       _selectedPet = selectedPet ?? pets.firstOrNull {
    refresh();
  }

  final PetRepository repository;
  final NotificationService notificationService;
  final List<Pet> pets;
  Pet? _selectedPet;
  List<T> _items = [];
  bool _loading = true;
  bool _saving = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? _error;

  Pet? get selectedPet => _selectedPet;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  @protected
  List<T> get items => List.unmodifiable(_items);

  /// Message shown when [loadFor] fails.
  @protected
  String get loadErrorMessage;

  @protected
  Future<List<T>> loadFor(String petId);

  @protected
  Future<void> persist(T record);

  @protected
  Future<void> remove(T record);

  @protected
  String? idOf(T record);

  Future<void> selectPet(Pet pet) async {
    if (_disposed || _selectedPet?.id == pet.id) return;
    _selectedPet = pet;
    _items = [];
    _notify();
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final petId = _selectedPet?.id;
    if (petId == null) {
      _items = [];
      _loading = false;
      _notify();
      return;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      final records = await loadFor(petId);
      if (_isStale(generation)) return;
      _items = records;
    } catch (_) {
      if (_isStale(generation)) return;
      _error = loadErrorMessage;
    } finally {
      if (!_isStale(generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> save(T record) => mutate(() => persist(record));

  Future<void> delete(T record) async {
    if (idOf(record) == null) return;
    await remove(record);
    await notificationService.rescheduleAll();
    await refresh();
  }

  /// Runs [write] with [saving] set, then reschedules reminders and reloads.
  @protected
  Future<void> mutate(Future<void> Function() write) async {
    if (_disposed) return;
    _saving = true;
    _notify();
    try {
      await write();
      await notificationService.rescheduleAll();
      await refresh();
    } finally {
      _saving = false;
      _notify();
    }
  }

  bool _isStale(int generation) =>
      _disposed || generation != _loadGeneration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
