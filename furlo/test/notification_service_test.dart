import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/services/notifications_service.dart';

void main() {
  test('notification IDs are stable and unique by reminder type', () {
    expect(
      stableNotificationId(NotificationTypes.dailyFeeding, 42),
      stableNotificationId(NotificationTypes.dailyFeeding, 42),
    );
    expect(
      stableNotificationId(NotificationTypes.dailyFeeding, 42),
      isNot(stableNotificationId(NotificationTypes.missedMeal, 42)),
    );
    expect(
      stableNotificationId(NotificationTypes.dailyFeeding, 42),
      greaterThan(0),
    );
  });

  test('calculates feeding and missed meal fire times', () {
    final now = DateTime(2026, 10, 2, 7);
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.dailyFeeding,
        now: now,
        enabled: true,
        time: '08:30',
      ),
      DateTime(2026, 10, 2, 8, 30),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.missedMeal,
        now: now,
        enabled: true,
        time: '08:30',
      ),
      DateTime(2026, 10, 2, 9, 30),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.missedMeal,
        now: now,
        enabled: true,
        time: '08:30',
        isDone: true,
      ),
      DateTime(2026, 10, 3, 9, 30),
    );
  });

  test('calculates a one-time feeding reminder only at its selected date', () {
    const enabled = true;
    final now = DateTime(2026, 10, 2, 7);
    expect(
      calculateOneTimeFeedingFireTime(
        now: now,
        enabled: enabled,
        date: DateTime(2026, 10, 2),
        time: '08:30',
      ),
      DateTime(2026, 10, 2, 8, 30),
    );
    expect(
      calculateOneTimeFeedingFireTime(
        now: now,
        enabled: enabled,
        date: DateTime(2026, 10, 3),
        time: '08:30',
      ),
      DateTime(2026, 10, 3, 8, 30),
    );
    expect(
      calculateOneTimeFeedingFireTime(
        now: DateTime(2026, 10, 2, 9),
        enabled: enabled,
        date: DateTime(2026, 10, 2),
        time: '08:30',
      ),
      isNull,
    );
    expect(
      calculateOneTimeFeedingFireTime(
        now: now,
        enabled: false,
        date: DateTime(2026, 10, 3),
        time: '08:30',
      ),
      isNull,
    );
  });

  test('calculates vaccine and appointment reminder dates', () {
    final now = DateTime(2026, 10, 1, 8);
    final due = DateTime(2026, 10, 10);
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.upcomingVaccine,
        now: now,
        enabled: true,
        date: due,
      ),
      DateTime(2026, 10, 7, 9),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.overdueVaccine,
        now: now,
        enabled: true,
        date: due,
      ),
      DateTime(2026, 10, 11, 9),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.overdueVaccine,
        now: now,
        enabled: true,
        date: due,
        isDone: true,
      ),
      isNull,
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.vetAppointment,
        now: now,
        enabled: true,
        date: due,
      ),
      DateTime(2026, 10, 9, 9),
    );
  });

  test('calculates daily, weekly, and monthly medication reminders', () {
    final now = DateTime(2026, 10, 2, 10);
    final start = DateTime(2026, 10, 1);
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.medication,
        now: now,
        enabled: true,
        date: start,
        frequency: 'daily',
      ),
      DateTime(2026, 10, 3, 9),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.medication,
        now: now,
        enabled: true,
        date: DateTime(2026, 9, 1),
        frequency: 'weekly',
      ),
      DateTime(2026, 10, 6, 9),
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.medication,
        now: now,
        enabled: true,
        date: DateTime(2026, 9, 15),
        frequency: 'monthly',
      ),
      DateTime(2026, 11, 15, 9),
    );
  });

  test('past dates and disabled types are not scheduled', () {
    final now = DateTime(2026, 10, 2, 10);
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.upcomingVaccine,
        now: now,
        enabled: true,
        date: DateTime(2026, 10, 3),
      ),
      isNull,
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.vetAppointment,
        now: now,
        enabled: false,
        date: DateTime(2026, 12, 1),
      ),
      isNull,
    );
    expect(
      calculateNotificationFireTime(
        type: NotificationTypes.medication,
        now: now,
        enabled: false,
        date: DateTime(2026, 10, 1),
        frequency: 'daily',
      ),
      isNull,
    );
  });
}
