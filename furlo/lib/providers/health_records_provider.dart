import '../models/health_record.dart';
import 'pet_records_provider.dart';

class HealthRecordsProvider extends PetRecordsProvider<HealthRecord> {
  HealthRecordsProvider({
    required super.repository,
    super.notificationService,
    required super.pets,
    super.selectedPet,
  });

  List<HealthRecord> get records => items;

  @override
  String get loadErrorMessage => 'Health records could not be loaded.';

  @override
  Future<List<HealthRecord>> loadFor(String petId) =>
      repository.getHealthRecordsForPet(petId);

  @override
  Future<void> persist(HealthRecord record) => record.id == null
      ? repository.addHealthRecord(record)
      : repository.updateHealthRecord(record);

  @override
  Future<void> remove(HealthRecord record) =>
      repository.deleteHealthRecord(record.id!, record.petId);

  @override
  String? idOf(HealthRecord record) => record.id;
}
