import '../data/health_record_types.dart';

class HealthRecord {
  final String? id;
  final String petId;
  final String title;
  final DateTime? date;
  final String type;
  final String? notes;
  final String? reminderFrequency;
  final bool? reminderActive;

  HealthRecord({
    this.id,
    required this.petId,
    required this.title,
    this.date,
    required this.type,
    this.notes,
    this.reminderFrequency,
    this.reminderActive,
  });

  factory HealthRecord.fromMap(Map<String, Object?> map) => HealthRecord(
    id: map['id']?.toString(),
    petId: map['pet_id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    date: DateTime.tryParse(map['date']?.toString() ?? ''),
    type: map['type']?.toString() ?? HealthRecordTypes.other,
    notes: map['notes']?.toString().isEmpty == true
        ? null
        : map['notes']?.toString(),
    reminderFrequency: map['reminder_frequency']?.toString().isEmpty == true
        ? null
        : map['reminder_frequency']?.toString(),
    reminderActive: _nullableBool(map['reminder_active']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'pet_id': petId,
    'title': title,
    'date': date?.toIso8601String(),
    'type': type,
    'notes': notes,
    'reminder_frequency': reminderFrequency,
    'reminder_active': reminderActive == null
        ? null
        : reminderActive!
        ? 1
        : 0,
  };

  HealthRecord copyWith({String? id}) => HealthRecord(
    id: id ?? this.id,
    petId: petId,
    title: title,
    date: date,
    type: type,
    notes: notes,
    reminderFrequency: reminderFrequency,
    reminderActive: reminderActive,
  );
}

bool? _nullableBool(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().toLowerCase();
  if (normalized == '1' || normalized == 'true') return true;
  if (normalized == '0' || normalized == 'false') return false;
  return null;
}
