/// Status labels used by vaccination records and their filters.
abstract final class VaccinationStatuses {
  static const completed = 'completed';
  static const upcoming = 'upcoming';
  static const dueSoon = 'due soon';
  static const overdue = 'overdue';
  static const all = 'all';
}

/// Derives the display status from completion and next due date.
String deriveVaccinationStatus(
  DateTime? nextDueDate, {
  bool isCompleted = false,
  DateTime? today,
}) {
  if (isCompleted) return VaccinationStatuses.completed;
  if (nextDueDate == null) return VaccinationStatuses.completed;
  final now = today ?? DateTime.now();
  final dueDay = DateTime.utc(
    nextDueDate.year,
    nextDueDate.month,
    nextDueDate.day,
  );
  final todayDay = DateTime.utc(now.year, now.month, now.day);
  final daysUntilDue = dueDay.difference(todayDay).inDays;
  if (daysUntilDue < 0) return VaccinationStatuses.overdue;
  return VaccinationStatuses.dueSoon;
}

class Vaccination {
  final String? id;
  final String petId;
  final String vaccineName;
  final DateTime? dateGiven;
  final DateTime? nextDueDate;
  final bool isCompleted;
  final String status;

  Vaccination({
    this.id,
    required this.petId,
    required this.vaccineName,
    this.dateGiven,
    this.nextDueDate,
    this.isCompleted = false,
  }) : status = deriveVaccinationStatus(nextDueDate, isCompleted: isCompleted);

  factory Vaccination.fromMap(Map<String, Object?> map) => Vaccination(
    id: map['id']?.toString(),
    petId: map['pet_id']?.toString() ?? '',
    vaccineName: map['vaccine_name']?.toString() ?? '',
    dateGiven: DateTime.tryParse(map['date_given']?.toString() ?? ''),
    nextDueDate: DateTime.tryParse(map['next_due_date']?.toString() ?? ''),
    isCompleted:
        map['is_completed']?.toString() == '1' ||
        map['is_completed']?.toString().toLowerCase() == 'true',
    // Stored status is intentionally ignored; date is the source of truth.
  );

  Map<String, Object?> toMap({DateTime? today}) => {
    'id': id,
    'pet_id': petId,
    'vaccine_name': vaccineName,
    'date_given': dateGiven?.toIso8601String(),
    'next_due_date': nextDueDate?.toIso8601String(),
    'is_completed': isCompleted ? 1 : 0,
    'status': deriveVaccinationStatus(
      nextDueDate,
      isCompleted: isCompleted,
      today: today,
    ),
  };

  Vaccination copyWith({
    String? id,
    String? petId,
    String? vaccineName,
    DateTime? dateGiven,
    DateTime? nextDueDate,
    bool? isCompleted,
    bool clearNextDueDate = false,
  }) => Vaccination(
    id: id ?? this.id,
    petId: petId ?? this.petId,
    vaccineName: vaccineName ?? this.vaccineName,
    dateGiven: dateGiven ?? this.dateGiven,
    nextDueDate: clearNextDueDate ? null : nextDueDate ?? this.nextDueDate,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
