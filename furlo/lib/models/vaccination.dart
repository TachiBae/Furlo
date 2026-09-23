class Vaccination {
  final int? id;
  final int petId;
  final String vaccineName;
  final DateTime? dateGiven;
  final DateTime? nextDueDate;
  final String status;

  Vaccination({
    this.id,
    required this.petId,
    required this.vaccineName,
    this.dateGiven,
    this.nextDueDate,
    this.status = 'upcoming',
  });
}
