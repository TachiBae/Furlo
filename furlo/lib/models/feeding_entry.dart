class FeedingEntry {
  static const doesNotRepeat = 'Does not repeat';

  final String? id;
  final String petId;
  final String name;

  /// Local time of day in `HH:mm` format.
  final String time;
  final String frequency;
  final DateTime? scheduledDate;
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
    this.scheduledDate,
    this.daysOfWeek = const [],
    this.portionSize,
    this.remindMe = false,
    this.lastFedAt,
  });

  bool get doneToday {
    return isDoneOn(DateTime.now());
  }

  bool get isComplete =>
      frequency == doesNotRepeat ? lastFedAt != null : doneToday;

  bool isCompleteOn(DateTime date) {
    if (frequency != doesNotRepeat) return isDoneOn(date);
    final scheduled = scheduledDate;
    return scheduled != null &&
        scheduled.year == date.year &&
        scheduled.month == date.month &&
        scheduled.day == date.day &&
        isDoneOn(scheduled);
  }

  bool isScheduledOn(DateTime date) {
    if (frequency == doesNotRepeat) {
      final scheduled = scheduledDate;
      return scheduled != null &&
          scheduled.year == date.year &&
          scheduled.month == date.month &&
          scheduled.day == date.day;
    }
    final normalizedFrequency = frequency.toLowerCase();
    if (normalizedFrequency == 'daily' ||
        normalizedFrequency == 'twice daily') {
      return true;
    }
    if (normalizedFrequency == 'weekly' || normalizedFrequency == 'custom') {
      return daysOfWeek.contains(date.weekday);
    }
    return daysOfWeek.contains(date.weekday);
  }

  bool isDoneOn(DateTime date) =>
      lastFedAt != null &&
      lastFedAt!.year == date.year &&
      lastFedAt!.month == date.month &&
      lastFedAt!.day == date.day;

  FeedingEntry copyWith({
    String? id,
    String? petId,
    String? name,
    String? time,
    String? frequency,
    DateTime? scheduledDate,
    List<int>? daysOfWeek,
    String? portionSize,
    bool? remindMe,
    DateTime? lastFedAt,
    bool clearLastFedAt = false,
    bool clearPortionSize = false,
    bool clearScheduledDate = false,
  }) => FeedingEntry(
    id: id ?? this.id,
    petId: petId ?? this.petId,
    name: name ?? this.name,
    time: time ?? this.time,
    frequency: frequency ?? this.frequency,
    scheduledDate: clearScheduledDate
        ? null
        : scheduledDate ?? this.scheduledDate,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    portionSize: clearPortionSize ? null : portionSize ?? this.portionSize,
    remindMe: remindMe ?? this.remindMe,
    lastFedAt: clearLastFedAt ? null : lastFedAt ?? this.lastFedAt,
  );
}
