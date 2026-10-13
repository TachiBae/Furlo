import '../models/vaccination.dart';
import 'pet_records_provider.dart';

class VaccinationsProvider extends PetRecordsProvider<Vaccination> {
  VaccinationsProvider({
    required super.repository,
    super.notificationService,
    required super.pets,
    super.selectedPet,
  });

  List<Vaccination> get vaccinations => items;

  @override
  String get loadErrorMessage => 'Vaccinations could not be loaded.';

  @override
  Future<List<Vaccination>> loadFor(String petId) =>
      repository.getVaccinationsForPet(petId);

  @override
  Future<void> persist(Vaccination vaccination) => vaccination.id == null
      ? repository.addVaccination(vaccination)
      : repository.updateVaccination(vaccination);

  @override
  Future<void> remove(Vaccination vaccination) =>
      repository.deleteVaccination(vaccination.id!, vaccination.petId);

  @override
  String? idOf(Vaccination vaccination) => vaccination.id;

  Future<void> toggleCompletion(Vaccination vaccination) async {
    if (vaccination.id == null) return;
    await mutate(
      () => repository.updateVaccination(
        vaccination.copyWith(isCompleted: !vaccination.isCompleted),
      ),
    );
  }
}
