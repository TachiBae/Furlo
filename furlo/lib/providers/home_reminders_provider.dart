import 'package:flutter/foundation.dart';

import '../models/feeding_entry.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../repositories/pet_repository.dart';
import '../services/notifications_service.dart';

enum ReminderType { feeding, vaccination, vetAppointment, medication }

enum ReminderUrgency { overdue, today, upcoming }

class VetAppointmentReminder {
  const VetAppointmentReminder({
    required this.petId,
    required this.vetName,
    required this.date,
  });

  final String petId;
  final String vetName;
  final DateTime date;
}

class HomeReminder {
  const HomeReminder({
    required this.petId,
    required this.petName,
    required this.title,
    required this.type,
    required this.urgency,
    this.time,
    this.date,
    this.recordId,
    this.secondMeal = false,
  });

  final String petId;
  final String petName;
  final String title;
  final ReminderType type;
  final ReminderUrgency urgency;
  final String? time;
  final DateTime? date;

  /// The feeding schedule behind a feeding reminder, so it can be marked fed
  /// from the dashboard.
  final String? recordId;

  /// Whether this is the second meal of a twice-daily schedule.
  final bool secondMeal;

  DateTime get sortDate => date ?? DateTime(0);
}

class TodayReminderResult {
  const TodayReminderResult({required this.allItems});

  static const visibleLimit = 5;
  final List<HomeReminder> allItems;
  List<HomeReminder> get visibleItems => allItems.take(visibleLimit).toList();
  int get remainingCount =>
      allItems.length > visibleLimit ? allItems.length - visibleLimit : 0;
}

TodayReminderResult buildTodayReminders({
  required List<Pet> pets,
  required List<FeedingEntry> feedings,
  required List<Vaccination> vaccinations,
  required List<HealthRecord> healthRecords,
  required List<VetAppointmentReminder> appointments,
  required DateTime today,
}) {
  final todayOnly = DateTime(today.year, today.month, today.day);
  final petById = {
    for (final pet in pets)
      if (pet.id != null) pet.id!: pet,
  };
  final reminders = <HomeReminder>[];

  for (final feeding in feedings) {
    final pet = petById[feeding.petId];
    if (pet == null ||
        feeding.isCompleteOn(today) ||
        !feeding.isScheduledOn(today)) {
      continue;
    }
    // A twice-daily schedule lists each meal that is still unfed on its own.
    final meals = <(String title, String time, bool second)>[
      if (!feeding.isTwiceDaily || !feeding.isDoneOn(today))
        (feeding.name, feeding.time, false),
      if (feeding.isTwiceDaily && !feeding.isSecondDoneOn(today))
        ('${feeding.name} (second meal)', feeding.effectiveSecondTime, true),
    ];
    for (final (title, time, second) in meals) {
      reminders.add(
        HomeReminder(
          petId: feeding.petId,
          petName: pet.name,
          title: title,
          type: ReminderType.feeding,
          urgency: ReminderUrgency.today,
          time: time,
          date: _dateAtTime(todayOnly, time),
          recordId: feeding.id,
          secondMeal: second,
        ),
      );
    }
  }

  for (final vaccination in vaccinations) {
    final pet = petById[vaccination.petId];
    final due = vaccination.nextDueDate;
    if (pet == null || due == null || vaccination.isCompleted) continue;
    final dueDay = DateTime(due.year, due.month, due.day);
    final daysUntilDue = _daysBetween(todayOnly, dueDay);
    if (daysUntilDue > 7) continue;
    reminders.add(
      HomeReminder(
        petId: vaccination.petId,
        petName: pet.name,
        title: vaccination.vaccineName,
        type: ReminderType.vaccination,
        urgency: daysUntilDue < 0
            ? ReminderUrgency.overdue
            : daysUntilDue == 0
            ? ReminderUrgency.today
            : ReminderUrgency.upcoming,
        date: dueDay,
      ),
    );
  }

  for (final appointment in appointments) {
    final pet = petById[appointment.petId];
    if (pet == null) continue;
    final date = DateTime(
      appointment.date.year,
      appointment.date.month,
      appointment.date.day,
    );
    final daysUntil = _daysBetween(todayOnly, date);
    if (daysUntil < 0 || daysUntil > 3) continue;
    reminders.add(
      HomeReminder(
        petId: appointment.petId,
        petName: pet.name,
        title: 'Vet appointment · ${appointment.vetName}',
        type: ReminderType.vetAppointment,
        urgency: daysUntil == 0
            ? ReminderUrgency.today
            : ReminderUrgency.upcoming,
        date: date,
      ),
    );
  }

  for (final record in healthRecords) {
    final pet = petById[record.petId];
    final start = record.date;
    final frequency = record.reminderFrequency;
    if (pet == null ||
        start == null ||
        record.reminderActive != true ||
        frequency == null) {
      continue;
    }
    if (!_medicationDueToday(start, frequency, todayOnly)) continue;
    reminders.add(
      HomeReminder(
        petId: record.petId,
        petName: pet.name,
        title: record.title,
        type: ReminderType.medication,
        urgency: ReminderUrgency.today,
        date: todayOnly,
      ),
    );
  }

  reminders.sort((a, b) {
    final urgency = a.urgency.index.compareTo(b.urgency.index);
    if (urgency != 0) return urgency;
    final date = a.sortDate.compareTo(b.sortDate);
    if (date != 0) return date;
    final pet = a.petName.toLowerCase().compareTo(b.petName.toLowerCase());
    if (pet != 0) return pet;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return TodayReminderResult(allItems: List.unmodifiable(reminders));
}

/// Whole calendar days from [from] to [to], counted on UTC dates so a
/// daylight-saving change between them cannot shave off a day.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

bool _medicationDueToday(DateTime start, String frequency, DateTime today) {
  final startDay = DateTime(start.year, start.month, start.day);
  if (startDay.isAfter(today)) return false;
  final elapsedDays = _daysBetween(startDay, today);
  switch (frequency.toLowerCase()) {
    case 'daily':
      return true;
    case 'weekly':
      return elapsedDays % 7 == 0;
    case 'monthly':
      final targetDay = start.day.clamp(
        1,
        DateTime(today.year, today.month + 1, 0).day,
      );
      return today.day == targetDay;
    default:
      return false;
  }
}

DateTime _dateAtTime(DateTime day, String time) {
  final pieces = time.split(':');
  final hour = int.tryParse(pieces.first) ?? 0;
  final minute = pieces.length > 1 ? int.tryParse(pieces[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

class HomeRemindersProvider extends ChangeNotifier {
  HomeRemindersProvider(
    this._repository, {
    this.notificationService = const NoOpNotificationService(),
  });

  final PetRepository _repository;
  final NotificationService notificationService;
  List<Pet>? _lastPets;
  TodayReminderResult _result = const TodayReminderResult(allItems: []);
  bool _loading = false;
  bool _hasError = false;
  bool _disposed = false;

  List<HomeReminder> get reminders => _result.allItems;
  TodayReminderResult get result => _result;
  bool get loading => _loading;
  bool get hasError => _hasError;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notifies listeners unless the provider is already disposed: a load can
  /// finish after the screen that started it is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({List<Pet>? pets, DateTime? today}) async {
    if (_disposed) return;
    _loading = true;
    _hasError = false;
    _notify();
    if (pets != null) _lastPets = pets;
    try {
      final currentPets = pets ?? _lastPets ?? await _repository.getPets();
      // The owning screen may be gone by now; futures cannot be cancelled, so
      // the work is abandoned at the next checkpoint instead.
      if (_disposed) return;
      // One read per collection, however many pets: the reminders builder
      // already ignores records whose pet is gone.
      final results = await Future.wait<Object>([
        _repository.getAllFeedingSchedules(),
        _repository.getAllVaccinations(),
        _repository.getAllHealthRecords(),
        _repository.getAllVets(),
        _repository.getAllVetLinks(),
      ]);
      if (_disposed) return;
      final vetsById = {
        for (final vet in results[3] as List<Vet>)
          if (vet.id != null) vet.id!: vet,
      };
      final appointments = <VetAppointmentReminder>[
        for (final link in results[4] as List<VetPetAssociation>)
          if (link.nextAppointmentDate != null && vetsById[link.vetId] != null)
            VetAppointmentReminder(
              petId: link.petId,
              vetName: vetsById[link.vetId]!.name,
              date: link.nextAppointmentDate!,
            ),
      ];
      _result = buildTodayReminders(
        pets: currentPets,
        feedings: results[0] as List<FeedingEntry>,
        vaccinations: results[1] as List<Vaccination>,
        healthRecords: results[2] as List<HealthRecord>,
        appointments: appointments,
        today: today ?? DateTime.now(),
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      debugPrint('Today reminders could not be loaded: $error\n$stackTrace');
      _hasError = true;
      _result = const TodayReminderResult(allItems: []);
    } finally {
      if (!_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Marks the meal behind a feeding [reminder] fed now, then rebuilds the
  /// reminders. Throws when the save fails, so the caller can say so.
  Future<void> markFed(HomeReminder reminder) async {
    final id = reminder.recordId;
    if (_disposed || reminder.type != ReminderType.feeding || id == null) {
      return;
    }
    final entry = (await _repository.getFeedingSchedules(
      reminder.petId,
    )).where((item) => item.id == id).firstOrNull;
    if (entry == null) return;
    final now = DateTime.now();
    await _repository.updateFeedingSchedule(
      reminder.secondMeal
          ? entry.copyWith(lastSecondFedAt: now)
          : entry.copyWith(lastFedAt: now),
    );
    await notificationService.rescheduleAll();
    await refresh();
  }
}
