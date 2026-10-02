class WeightLog {
  final int? id;
  final int petId;
  final DateTime? date;
  final double weight;
  final String? notes;

  WeightLog({
    this.id,
    required this.petId,
    this.date,
    required this.weight,
    this.notes,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'pet_id': petId,
    'date': date?.toIso8601String(),
    'weight': weight,
    'notes': notes,
  };

  factory WeightLog.fromMap(Map<String, Object?> map) => WeightLog(
    id: int.tryParse(map['id']?.toString() ?? ''),
    petId: int.parse(map['pet_id']?.toString() ?? '0'),
    date: DateTime.tryParse(map['date']?.toString() ?? ''),
    weight: double.parse(map['weight']?.toString() ?? '0'),
    notes: map['notes']?.toString(),
  );
}

/// Stored weight unit across the app. Convert any future display units here.
const String weightUnit = 'kg';
