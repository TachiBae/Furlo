class FeedingEntry {
  final int? id;
  final int petId;
  final DateTime? time;
  final String? frequency;
  final DateTime? lastFedAt;
  final bool doneToday;

  FeedingEntry({
    this.id,
    required this.petId,
    this.time,
    this.frequency,
    this.lastFedAt,
    this.doneToday = false,
  });
}
