class HealthRecord {
  final int? id;
  final int petId;
  final String title;
  final DateTime? date;
  final String type;
  final String? notes;
  final String? reminderFrequency;
  final bool reminderActive;

  HealthRecord({
    this.id,
    required this.petId,
    required this.title,
    this.date,
    required this.type,
    this.notes,
    this.reminderFrequency,
    this.reminderActive = false,
  });
}
