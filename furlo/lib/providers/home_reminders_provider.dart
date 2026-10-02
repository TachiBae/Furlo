import 'package:flutter/foundation.dart';

import '../models/feeding_entry.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../repositories/pet_repository.dart';

enum ReminderType { feeding, vaccination, vetAppointment, medication }

enum ReminderUrgency { overdue, today, upcoming }

class VetAppointmentReminder {
  const VetAppointmentReminder({
    required this.petId,
    required this.vetName,
    required this.date,
  });

  final int petId;
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
  });

  final int petId;
  final String petName;
  final String title;
  final ReminderType type;
  final ReminderUrgency urgency;
  final String? time;
  final DateTime? date;

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
        feeding.isDoneOn(today) ||
        !_feedingScheduledToday(feeding, today)) {
      continue;
    }
    reminders.add(
      HomeReminder(
        petId: feeding.petId,
        petName: pet.name,
        title: feeding.name,
        type: ReminderType.feeding,
        urgency: ReminderUrgency.today,
        time: feeding.time,
        date: _dateAtTime(todayOnly, feeding.time),
      ),
    );
  }

  for (final vaccination in vaccinations) {
    final pet = petById[vaccination.petId];
    final due = vaccination.nextDueDate;
    if (pet == null || due == null || vaccination.isCompleted) continue;
    final dueDay = DateTime(due.year, due.month, due.day);
    final daysUntilDue = dueDay.difference(todayOnly).inDays;
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
    final daysUntil = date.difference(todayOnly).inDays;
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

bool _feedingScheduledToday(FeedingEntry entry, DateTime today) {
  final frequency = entry.frequency.toLowerCase();
  if (frequency == 'daily' || frequency == 'twice daily') return true;
  if (frequency == 'weekly' || frequency == 'custom') {
    return entry.daysOfWeek.contains(today.weekday);
  }
  return entry.daysOfWeek.isNotEmpty &&
      entry.daysOfWeek.contains(today.weekday);
}

bool _medicationDueToday(DateTime start, String frequency, DateTime today) {
  final startDay = DateTime(start.year, start.month, start.day);
  if (startDay.isAfter(today)) return false;
  final elapsedDays = today.difference(startDay).inDays;
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
  HomeRemindersProvider(this._repository);

  final PetRepository _repository;
  TodayReminderResult _result = const TodayReminderResult(allItems: []);
  bool _loading = false;
  bool _hasError = false;

  List<HomeReminder> get reminders => _result.allItems;
  TodayReminderResult get result => _result;
  bool get loading => _loading;
  bool get hasError => _hasError;

  Future<void> refresh({List<Pet>? pets, DateTime? today}) async {
    _loading = true;
    _hasError = false;
    notifyListeners();
    try {
      final currentPets = pets ?? await _repository.getPets();
      final data = await Future.wait<_PetReminders>(
        currentPets.where((pet) => pet.id != null).map(_loadPet),
      );
      _result = buildTodayReminders(
        pets: currentPets,
        feedings: data.expand((item) => item.feedings).toList(),
        vaccinations: data.expand((item) => item.vaccinations).toList(),
        healthRecords: data.expand((item) => item.healthRecords).toList(),
        appointments: data.expand((item) => item.appointments).toList(),
        today: today ?? DateTime.now(),
      );
    } catch (_) {
      _hasError = true;
      _result = const TodayReminderResult(allItems: []);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<_PetReminders> _loadPet(Pet pet) async {
    final id = pet.id!;
    final results = await Future.wait<Object>([
      _repository.getFeedingSchedules(id),
      _repository.getVaccinationsForPet(id),
      _repository.getHealthRecordsForPet(id),
      _repository.getVetsForPet(id),
    ]);
    final vets = results[3] as List<Vet>;
    final associations = await Future.wait<List<VetPetAssociation>>(
      vets
          .where((vet) => vet.id != null)
          .map((vet) => _repository.getVetPetAssociations(vet.id!)),
    );
    final appointments = <VetAppointmentReminder>[];
    for (var index = 0; index < associations.length; index++) {
      final vet = vets.where((item) => item.id != null).elementAt(index);
      for (final association in associations[index]) {
        final date = association.nextAppointmentDate;
        if (association.petId == id && date != null) {
          appointments.add(
            VetAppointmentReminder(petId: id, vetName: vet.name, date: date),
          );
        }
      }
    }
    return _PetReminders(
      feedings: results[0] as List<FeedingEntry>,
      vaccinations: results[1] as List<Vaccination>,
      healthRecords: results[2] as List<HealthRecord>,
      appointments: appointments,
    );
  }
}

class _PetReminders {
  const _PetReminders({
    required this.feedings,
    required this.vaccinations,
    required this.healthRecords,
    required this.appointments,
  });
  final List<FeedingEntry> feedings;
  final List<Vaccination> vaccinations;
  final List<HealthRecord> healthRecords;
  final List<VetAppointmentReminder> appointments;
}
