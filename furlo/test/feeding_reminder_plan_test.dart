import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/providers/home_reminders_provider.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wednesday, 7 Oct 2026, 10:00.
final _now = DateTime(2026, 10, 7, 10);

List<PlannedReminder> _plan(
  FeedingEntry entry, {
  bool feeding = true,
  bool missed = true,
  DateTime? now,
}) => planFeedingReminders(
  petName: 'Mochi',
  entry: entry,
  now: now ?? _now,
  feedingEnabled: feeding,
  missedEnabled: missed,
);

FeedingEntry _entry({
  String frequency = FeedingFrequency.daily,
  List<int> days = const [],
  String time = '18:00',
  String? secondTime,
  DateTime? lastFedAt,
  DateTime? lastSecondFedAt,
  bool remindMe = true,
}) => FeedingEntry(
  id: '5',
  petId: '1',
  name: 'Dinner',
  time: time,
  frequency: frequency,
  daysOfWeek: days,
  secondTime: secondTime,
  lastFedAt: lastFedAt,
  lastSecondFedAt: lastSecondFedAt,
  remindMe: remindMe,
);

List<PlannedReminder> _ofType(List<PlannedReminder> plan, String type) =>
    plan.where((r) => r.type == type).toList();

void main() {
  group('planFeedingReminders', () {
    test('weekly schedules fire only on the chosen days, weekly', () {
      final plan = _plan(
        _entry(frequency: FeedingFrequency.weekly, days: [1, 5]),
      );
      final feeding = _ofType(plan, NotificationTypes.dailyFeeding);

      expect(feeding.map((r) => r.recordKey), ['5:w1', '5:w5']);
      expect(feeding.map((r) => r.fireAt.weekday), [1, 5]);
      expect(
        feeding.every((r) => r.repeat == NotificationRepeat.weekly),
        isTrue,
      );
      expect(feeding.first.fireAt, DateTime(2026, 10, 12, 18));
      expect(feeding.last.fireAt, DateTime(2026, 10, 9, 18));
    });

    test('custom schedules follow the same per-day rule', () {
      final plan = _plan(_entry(frequency: FeedingFrequency.custom, days: [3]));
      final feeding = _ofType(plan, NotificationTypes.dailyFeeding).single;

      // Today is Wednesday and 18:00 has not passed: today counts.
      expect(feeding.fireAt, DateTime(2026, 10, 7, 18));
      expect(feeding.repeat, NotificationRepeat.weekly);
    });

    test('a chosen day whose time already passed rolls a full week', () {
      final plan = _plan(
        _entry(frequency: FeedingFrequency.weekly, days: [3], time: '08:00'),
      );
      expect(
        _ofType(plan, NotificationTypes.dailyFeeding).single.fireAt,
        DateTime(2026, 10, 14, 8),
      );
    });

    test('weekly missed-meal nudge follows the next chosen day', () {
      final plan = _plan(
        _entry(frequency: FeedingFrequency.weekly, days: [1, 5]),
      );
      expect(
        _ofType(plan, NotificationTypes.missedMeal).single.fireAt,
        DateTime(2026, 10, 9, 19),
      );
    });

    test('weekly with no chosen days schedules nothing', () {
      expect(_plan(_entry(frequency: FeedingFrequency.weekly)), isEmpty);
    });

    test('daily repeats every day', () {
      final feeding = _ofType(
        _plan(_entry()),
        NotificationTypes.dailyFeeding,
      ).single;
      expect(feeding.repeat, NotificationRepeat.daily);
      expect(feeding.fireAt, DateTime(2026, 10, 7, 18));
    });

    test('twice daily gets a reminder for each meal time', () {
      final plan = _plan(
        _entry(
          frequency: FeedingFrequency.twiceDaily,
          time: '08:00',
          secondTime: '19:30',
        ),
      );
      final feeding = _ofType(plan, NotificationTypes.dailyFeeding);

      expect(feeding.map((r) => r.recordKey), ['5', '5:2']);
      expect(feeding.map((r) => r.fireAt), [
        DateTime(2026, 10, 8, 8),
        DateTime(2026, 10, 7, 19, 30),
      ]);
      expect(_ofType(plan, NotificationTypes.missedMeal), hasLength(2));
    });

    test('an older twice-daily schedule uses a second meal 12h later', () {
      final plan = _plan(
        _entry(frequency: FeedingFrequency.twiceDaily, time: '07:15'),
      );
      expect(
        _ofType(plan, NotificationTypes.dailyFeeding).last.fireAt,
        DateTime(2026, 10, 7, 19, 15),
      );
    });

    test('a meal fed today pushes its missed-meal nudge to tomorrow', () {
      final plan = _plan(
        _entry(
          frequency: FeedingFrequency.twiceDaily,
          time: '08:00',
          secondTime: '19:00',
          lastSecondFedAt: _now,
        ),
      );
      final secondMissed = _ofType(
        plan,
        NotificationTypes.missedMeal,
      ).firstWhere((r) => r.recordKey == '5:2');
      expect(secondMissed.fireAt, DateTime(2026, 10, 8, 20));
    });

    test('reminders off, or no id, schedules nothing', () {
      expect(_plan(_entry(remindMe: false)), isEmpty);
      expect(
        planFeedingReminders(
          petName: 'Mochi',
          entry: FeedingEntry(
            petId: '1',
            name: 'x',
            time: '08:00',
            remindMe: true,
          ),
          now: _now,
          feedingEnabled: true,
          missedEnabled: true,
        ),
        isEmpty,
      );
    });

    test('a disabled feeding toggle keeps only the missed-meal nudge', () {
      final plan = _plan(_entry(), feeding: false);
      expect(plan.single.type, NotificationTypes.missedMeal);
    });
  });

  group('twice-daily completion', () {
    test('needs both meals fed', () {
      final today = DateTime.now();
      final entry = _entry(frequency: FeedingFrequency.twiceDaily);
      expect(entry.copyWith(lastFedAt: today).isComplete, isFalse);
      expect(
        entry.copyWith(lastFedAt: today, lastSecondFedAt: today).isComplete,
        isTrue,
      );
    });

    test('the default second time wraps past midnight', () {
      expect(FeedingEntry.defaultSecondTime('14:05'), '02:05');
      expect(FeedingEntry.defaultSecondTime('08:00'), '20:00');
    });

    test("today's reminders list each unfed meal on its own", () {
      final pet = Pet(id: '1', name: 'Mochi', species: 'Cat');
      TodayReminderResult build(FeedingEntry entry) => buildTodayReminders(
        pets: [pet],
        feedings: [entry],
        vaccinations: const [],
        healthRecords: const [],
        appointments: const [],
        today: _now,
      );
      final entry = _entry(
        frequency: FeedingFrequency.twiceDaily,
        time: '08:00',
        secondTime: '19:00',
      );

      expect(build(entry).allItems.map((r) => r.title), [
        'Dinner',
        'Dinner (second meal)',
      ]);
      expect(
        build(entry.copyWith(lastFedAt: _now)).allItems.single.time,
        '19:00',
      );
    });
  });

  group('second meal persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('second time and second fed time round-trip', () async {
      final repository = WebPetRepository();
      final saved = await repository.addFeedingSchedule(
        _entry(
          frequency: FeedingFrequency.twiceDaily,
          secondTime: '20:15',
          lastSecondFedAt: DateTime(2026, 10, 7, 20, 16),
        ),
      );
      final loaded = (await repository.getFeedingSchedules('1')).single;
      expect(loaded.id, saved.id);
      expect(loaded.secondTime, '20:15');
      expect(loaded.lastSecondFedAt, DateTime(2026, 10, 7, 20, 16));
    });
  });

  testWidgets('the form asks for a second meal time for twice daily', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pet = (await repository.getPets()).single;
    final state = FurloState(repository);
    await state.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: FeedingScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add feeding schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Kibble');
    expect(find.text('Second meal time'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twice daily').last);
    await tester.pumpAndSettle();
    expect(find.text('Second meal time'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repository.getFeedingSchedules(pet.id!)).single;
    expect(saved.frequency, FeedingFrequency.twiceDaily);
    expect(saved.secondTime, '20:00');

    await tester.tap(find.text('Mark fed'));
    await tester.pumpAndSettle();
    expect(find.text('Mark second meal fed'), findsOneWidget);
    await tester.tap(find.text('Mark second meal fed'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });
}
