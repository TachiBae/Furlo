class FeedingEntry {
  final int? id;
  final int petId;
  final String name;

  /// Local time of day in `HH:mm` format.
  final String time;
  final String frequency;
  final List<int> daysOfWeek;
  final String? portionSize;
  final bool remindMe;
  final DateTime? lastFedAt;

  FeedingEntry({
    this.id,
    required this.petId,
    required this.name,
    required this.time,
    this.frequency = 'Daily',
    this.daysOfWeek = const [],
    this.portionSize,
    this.remindMe = false,
    this.lastFedAt,
  });

  bool get doneToday {
    return isDoneOn(DateTime.now());
  }

  bool isDoneOn(DateTime date) =>
      lastFedAt != null &&
      lastFedAt!.year == date.year &&
      lastFedAt!.month == date.month &&
      lastFedAt!.day == date.day;

  FeedingEntry copyWith({
    int? id,
    int? petId,
    String? name,
    String? time,
    String? frequency,
    List<int>? daysOfWeek,
    String? portionSize,
    bool? remindMe,
    DateTime? lastFedAt,
    bool clearLastFedAt = false,
    bool clearPortionSize = false,
  }) => FeedingEntry(
    id: id ?? this.id,
    petId: petId ?? this.petId,
    name: name ?? this.name,
    time: time ?? this.time,
    frequency: frequency ?? this.frequency,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    portionSize: clearPortionSize ? null : portionSize ?? this.portionSize,
    remindMe: remindMe ?? this.remindMe,
    lastFedAt: clearLastFedAt ? null : lastFedAt ?? this.lastFedAt,
  );
}
