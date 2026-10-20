/// Stored frequency labels for feeding schedules. Persisted as-is, so never
/// rename a value; add a new one instead.
abstract final class FeedingFrequency {
  static const doesNotRepeat = 'Does not repeat';
  static const daily = 'Daily';
  static const twiceDaily = 'Twice daily';
  static const weekly = 'Weekly';
  static const custom = 'Custom';

  static const all = [doesNotRepeat, daily, twiceDaily, weekly, custom];

  /// Frequencies that repeat on chosen days of the week only.
  static bool usesDays(String frequency) =>
      frequency == weekly || frequency == custom;
}

class FeedingEntry {
  static const doesNotRepeat = FeedingFrequency.doesNotRepeat;

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

  /// Second meal of a [FeedingFrequency.twiceDaily] schedule, `HH:mm`.
  ///
  /// Schedules saved before this field existed have none; they fall back to
  /// [defaultSecondTime] through [effectiveSecondTime].
  final String? secondTime;

  /// When the second meal of a twice-daily schedule was last marked fed.
  final DateTime? lastSecondFedAt;

  FeedingEntry({
    this.id,
    required this.petId,
    required this.name,
    required this.time,
    this.frequency = FeedingFrequency.daily,
    this.scheduledDate,
    this.daysOfWeek = const [],
    this.portionSize,
    this.remindMe = false,
    this.lastFedAt,
    this.secondTime,
    this.lastSecondFedAt,
  });

  bool get isTwiceDaily => frequency == FeedingFrequency.twiceDaily;

  /// Twelve hours after [first], wrapping past midnight.
  static String defaultSecondTime(String first) {
    final parts = first.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return '${((hour + 12) % 24).toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String get effectiveSecondTime => secondTime ?? defaultSecondTime(time);

  bool get doneToday {
    return isDoneOn(DateTime.now());
  }

  bool get isComplete {
    if (frequency == doesNotRepeat) return lastFedAt != null;
    if (isTwiceDaily) return isCompleteOn(DateTime.now());
    return doneToday;
  }

  bool isCompleteOn(DateTime date) {
    // A one-time meal is done once fed, even if fed early, matching isComplete
    // (changing its date clears lastFedAt).
    if (frequency == doesNotRepeat) return lastFedAt != null;
    if (isTwiceDaily) return isDoneOn(date) && isSecondDoneOn(date);
    return isDoneOn(date);
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
    return daysOfWeek.contains(date.weekday);
  }

  bool isDoneOn(DateTime date) => _sameDay(lastFedAt, date);

  bool isSecondDoneOn(DateTime date) => _sameDay(lastSecondFedAt, date);

  static bool _sameDay(DateTime? value, DateTime date) =>
      value != null &&
      value.year == date.year &&
      value.month == date.month &&
      value.day == date.day;

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
    String? secondTime,
    DateTime? lastSecondFedAt,
    bool clearLastFedAt = false,
    bool clearPortionSize = false,
    bool clearScheduledDate = false,
    bool clearSecondTime = false,
    bool clearLastSecondFedAt = false,
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
    secondTime: clearSecondTime ? null : secondTime ?? this.secondTime,
    lastSecondFedAt: clearLastSecondFedAt
        ? null
        : lastSecondFedAt ?? this.lastSecondFedAt,
  );
}
