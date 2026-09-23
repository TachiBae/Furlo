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
}
