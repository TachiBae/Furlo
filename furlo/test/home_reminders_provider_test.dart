import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/providers/home_reminders_provider.dart';

void main() {
  final today = DateTime(2026, 10, 2, 13);
  final pets = [Pet(id: 1, name: 'Milo', species: 'Dog')];

  TodayReminderResult build({
    List<FeedingEntry> feedings = const [],
    List<Vaccination> vaccinations = const [],
    List<HealthRecord> healthRecords = const [],
    List<VetAppointmentReminder> appointments = const [],
    List<Pet> availablePets = const [],
  }) => buildTodayReminders(
    pets: availablePets.isEmpty ? pets : availablePets,
    feedings: feedings,
    vaccinations: vaccinations,
    healthRecords: healthRecords,
    appointments: appointments,
    today: today,
  );

  test(
    'includes overdue, today, and seven-day vaccinations but excludes eight days',
    () {
      final result = build(
        vaccinations: [
          Vaccination(
            petId: 1,
            vaccineName: 'Overdue',
            nextDueDate: DateTime(2026, 10, 1),
          ),
          Vaccination(
            petId: 1,
            vaccineName: 'Due today',
            nextDueDate: DateTime(2026, 10, 2),
          ),
          Vaccination(
            petId: 1,
            vaccineName: 'Seven days',
            nextDueDate: DateTime(2026, 10, 9),
          ),
          Vaccination(
            petId: 1,
            vaccineName: 'Eight days',
            nextDueDate: DateTime(2026, 10, 10),
          ),
        ],
      );

      expect(result.allItems.map((item) => item.title), [
        'Overdue',
        'Due today',
        'Seven days',
      ]);
      expect(result.allItems.first.urgency, ReminderUrgency.overdue);
    },
  );

  test(
    'includes unfinished meals scheduled today and excludes completed meals',
    () {
      final result = build(
        feedings: [
          FeedingEntry(
            petId: 1,
            name: 'Breakfast',
            time: '08:00',
            lastFedAt: DateTime(2026, 10, 2, 8),
          ),
          FeedingEntry(petId: 1, name: 'Dinner', time: '18:00'),
          FeedingEntry(
            petId: 1,
            name: 'Monday only',
            time: '10:00',
            frequency: 'Custom',
            daysOfWeek: const [1],
          ),
        ],
      );

      expect(result.allItems.map((item) => item.title), ['Dinner']);
      expect(result.allItems.single.time, '18:00');
    },
  );

  test('one-time feedings appear only on their scheduled date', () {
    final scheduledDate = DateTime(today.year, today.month, today.day);
    final oneTimeMeal = FeedingEntry(
      petId: 1,
      name: 'One-time meal',
      time: '15:00',
      frequency: FeedingEntry.doesNotRepeat,
      scheduledDate: scheduledDate,
    );

    final onScheduledDate = build(feedings: [oneTimeMeal]);
    expect(onScheduledDate.allItems.map((item) => item.title), [
      'One-time meal',
    ]);
    expect(
      onScheduledDate.allItems.single.date,
      DateTime(today.year, today.month, today.day, 15),
    );
    expect(
      buildTodayReminders(
        pets: pets,
        feedings: [oneTimeMeal],
        vaccinations: const [],
        healthRecords: const [],
        appointments: const [],
        today: scheduledDate.add(const Duration(days: 1)),
      ).allItems,
      isEmpty,
    );
    expect(
      buildTodayReminders(
        pets: pets,
        feedings: [oneTimeMeal],
        vaccinations: const [],
        healthRecords: const [],
        appointments: const [],
        today: scheduledDate.subtract(const Duration(days: 1)),
      ).allItems,
      isEmpty,
    );
  });

  test('one-time feeding completion is evaluated on its scheduled date', () {
    final scheduledDate = DateTime(today.year, today.month, today.day);
    final meal = FeedingEntry(
      petId: 1,
      name: 'One-time meal',
      time: '15:00',
      frequency: FeedingEntry.doesNotRepeat,
      scheduledDate: scheduledDate,
      lastFedAt: scheduledDate.add(const Duration(hours: 9)),
    );

    expect(build(feedings: [meal]).allItems, isEmpty);
  });

  test('orders overdue reminders before today and upcoming reminders', () {
    final result = build(
      feedings: [FeedingEntry(petId: 1, name: 'Meal', time: '08:00')],
      vaccinations: [
        Vaccination(
          petId: 1,
          vaccineName: 'Later',
          nextDueDate: DateTime(2026, 10, 3),
        ),
        Vaccination(
          petId: 1,
          vaccineName: 'Past',
          nextDueDate: DateTime(2026, 9, 30),
        ),
      ],
      healthRecords: [
        HealthRecord(
          petId: 1,
          title: 'Medicine',
          type: 'Medication',
          date: DateTime(2026, 10, 1),
          reminderFrequency: 'daily',
          reminderActive: true,
        ),
      ],
    );

    expect(result.allItems.map((item) => item.urgency), [
      ReminderUrgency.overdue,
      ReminderUrgency.today,
      ReminderUrgency.today,
      ReminderUrgency.upcoming,
    ]);
  });

  test(
    'includes vet appointments through three days and medications due today',
    () {
      final result = build(
        appointments: [
          VetAppointmentReminder(
            petId: 1,
            vetName: 'Dr Lee',
            date: DateTime(2026, 10, 5),
          ),
          VetAppointmentReminder(
            petId: 1,
            vetName: 'Dr Kim',
            date: DateTime(2026, 10, 6),
          ),
        ],
        healthRecords: [
          HealthRecord(
            petId: 1,
            title: 'Weekly dose',
            type: 'Medication',
            date: DateTime(2026, 9, 25),
            reminderFrequency: 'weekly',
            reminderActive: true,
          ),
          HealthRecord(
            petId: 1,
            title: 'Disabled dose',
            type: 'Medication',
            date: DateTime(2026, 9, 25),
            reminderFrequency: 'daily',
            reminderActive: false,
          ),
        ],
      );

      expect(result.allItems.map((item) => item.title), [
        'Weekly dose',
        'Vet appointment · Dr Lee',
      ]);
    },
  );

  test('returns no reminders when there is no matching data', () {
    expect(
      build(
        availablePets: [Pet(id: 2, name: 'Luna', species: 'Cat')],
      ).allItems,
      isEmpty,
    );
  });

  test('caps visible results at five and reports the remainder', () {
    final result = build(
      vaccinations: List.generate(
        7,
        (index) => Vaccination(
          petId: 1,
          vaccineName: 'Vaccine $index',
          nextDueDate: DateTime(2026, 10, 3),
        ),
      ),
    );

    expect(result.allItems, hasLength(7));
    expect(result.visibleItems, hasLength(5));
    expect(result.remainingCount, 2);
  });
}
