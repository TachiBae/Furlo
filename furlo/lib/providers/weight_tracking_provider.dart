import '../models/weight_log.dart';
import 'pet_records_provider.dart';

/// Weight logs carry no reminders, so the default no-op notification service
/// is kept and saves never reschedule.
class WeightTrackingProvider extends PetRecordsProvider<WeightLog> {
  WeightTrackingProvider({
    required super.repository,
    required super.pets,
    super.selectedPet,
  });

  List<WeightLog> get logs => items;

  @override
  String get loadErrorMessage => 'Weight entries could not be loaded.';

  @override
  Future<List<WeightLog>> loadFor(String petId) =>
      repository.getWeightLogsForPet(petId);

  @override
  Future<void> persist(WeightLog log) => log.id == null
      ? repository.addWeightLog(log)
      : repository.updateWeightLog(log);

  @override
  Future<void> remove(WeightLog log) =>
      repository.deleteWeightLog(log.id!, log.petId);

  @override
  String? idOf(WeightLog log) => log.id;
}
