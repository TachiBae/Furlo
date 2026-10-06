import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/health_record_types.dart';
import '../models/feeding_entry.dart';
import '../models/pet.dart';
import '../repositories/notification_settings_repository.dart';
import '../repositories/pet_repository.dart';
import '../utils/user_storage_scope.dart';

enum NotificationRepeat { none, daily, weekly }

abstract interface class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<void> openAppSettings();
  Future<void> schedule(
    String type,
    String id,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  });
  Future<void> cancel(String type, String id);
  Future<void> cancelAllOfType(String type);
  Future<void> rescheduleAll();
  Future<void> clearScheduled();
}

NotificationService createNotificationService({
  required PetRepository repository,
  required NotificationSettingsRepository settings,
  String? storageScope,
}) => kIsWeb
    ? const NoOpNotificationService()
    : LocalNotificationService(
        repository: repository,
        settings: settings,
        storageScope: storageScope,
      );

/// Uses a deterministic FNV-1a hash instead of String.hashCode, which is not
/// guaranteed to be stable across runtime instances.
int stableNotificationId(String type, Object recordId, {String? scope}) {
  final source = scope == null ? '$type:$recordId' : '$scope:$type:$recordId';
  var hash = 0x811c9dc5;
  for (final unit in source.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id == 0 ? 1 : id;
}

/// Returns whether a pending reminder payload belongs to [storageScope].
/// Legacy payloads have `type|recordId`; scoped payloads prefix a namespace.
bool notificationPayloadIsOwnedByScope(String payload, {String? storageScope}) {
  final fields = payload.split('|');
  if (storageScope == null) return fields.length == 2;
  return fields.length >= 3 &&
      fields.first == userStorageScopeToken(storageScope);
}

DateTime? calculateOneTimeFeedingFireTime({
  required DateTime now,
  required bool enabled,
  required DateTime date,
  required String time,
}) {
  if (!enabled) return null;
  final parts = time.split(':');
  final scheduled = DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts.first) ?? 8,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
  return scheduled.isAfter(now) ? scheduled : null;
}

DateTime? calculateNotificationFireTime({
  required String type,
  required DateTime now,
  required bool enabled,
  DateTime? date,
  String? time,
  String? frequency,
  bool isDone = false,
}) {
  if (!enabled ||
      date == null &&
          type != NotificationTypes.dailyFeeding &&
          type != NotificationTypes.missedMeal) {
    return null;
  }
  DateTime? fireTime;
  switch (type) {
    case NotificationTypes.dailyFeeding:
      fireTime = _nextTime(now, time ?? '08:00');
    case NotificationTypes.missedMeal:
      var nextMeal = _nextTime(now, time ?? '08:00');
      if (isDone && _sameDate(nextMeal, now)) {
        nextMeal = nextMeal.add(const Duration(days: 1));
      }
      fireTime = nextMeal.add(const Duration(minutes: 60));
    case NotificationTypes.upcomingVaccine:
      fireTime = _atNine(date!.subtract(const Duration(days: 3)));
    case NotificationTypes.overdueVaccine:
      if (isDone) return null;
      fireTime = _atNine(date!.add(const Duration(days: 1)));
    case NotificationTypes.vetAppointment:
      fireTime = _atNine(date!.subtract(const Duration(days: 1)));
    case NotificationTypes.medication:
      fireTime = _nextMedicationTime(now, date!, frequency ?? 'daily');
    default:
      return null;
  }
  return fireTime.isBefore(now) ? null : fireTime;
}

DateTime _atNine(DateTime date) => DateTime(date.year, date.month, date.day, 9);

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

DateTime _nextTime(DateTime now, String time) {
  final parts = time.split(':');
  final hour = int.tryParse(parts.first) ?? 8;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  var result = DateTime(now.year, now.month, now.day, hour, minute);
  if (!result.isAfter(now)) result = result.add(const Duration(days: 1));
  return result;
}

DateTime _nextMedicationTime(DateTime now, DateTime start, String frequency) {
  final day = DateTime(start.year, start.month, start.day, 9);
  if (day.isAfter(now)) return day;
  switch (frequency.toLowerCase()) {
    case 'weekly':
      var next = day;
      while (!next.isAfter(now)) {
        next = next.add(const Duration(days: 7));
      }
      return next;
    case 'monthly':
      var year = now.year;
      var month = now.month + 1;
      if (month > 12) {
        year++;
        month = 1;
      }
      final maxDay = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, start.day.clamp(1, maxDay), 9);
    default:
      var next = day;
      while (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }
      return next;
  }
}

class NoOpNotificationService implements NotificationService {
  const NoOpNotificationService();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> schedule(
    String type,
    String id,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {}
  @override
  Future<void> cancel(String type, String id) async {}
  @override
  Future<void> cancelAllOfType(String type) async {}
  @override
  Future<void> rescheduleAll() async {}
  @override
  Future<void> clearScheduled() async {}
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required this.repository,
    required this.settings,
    this.storageScope,
  });

  final PetRepository repository;
  final NotificationSettingsRepository settings;
  final String? storageScope;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _timezoneChannel = MethodChannel('furlo/device_timezone');
  bool _initialized = false;
  tz.Location _localLocation = tz.UTC;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final zoneName = await _timezoneChannel.invokeMethod<String>(
          'getLocalTimeZone',
        );
        if (zoneName != null) _localLocation = tz.getLocation(zoneName);
      } catch (_) {
        // UTC preserves absolute instants if the platform timezone bridge fails.
      }
      tz.setLocalLocation(_localLocation);
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _initialized = true;
    } catch (_) {
      // Notification failures never stop app startup.
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ??
            await android.areNotificationsEnabled() ??
            false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            await hasPermission();
      }
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            await hasPermission();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return (await ios.checkPermissions())?.isEnabled ?? false;
      }
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        return (await macos.checkPermissions())?.isEnabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await initialize();
      await _plugin.openAppNotificationSettings();
    } catch (_) {
      // A settings screen being unavailable must not crash the app.
    }
  }

  @override
  Future<void> schedule(
    String type,
    String id,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {
    if (!await settings.isEnabled(type) || dateTime.isBefore(DateTime.now())) {
      return;
    }
    await _scheduleWithId(
      type,
      stableNotificationId(type, id, scope: storageScope),
      storageScope == null ? id : '${userStorageScopeToken(storageScope!)}:$id',
      title,
      body,
      dateTime,
      repeat: repeat,
    );
  }

  Future<void> _scheduleWithId(
    String type,
    int notificationId,
    Object recordKey,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {
    try {
      if (!await settings.isEnabled(type) ||
          dateTime.isBefore(DateTime.now())) {
        return;
      }
      if (!await hasPermission()) return;
      await initialize();
      final components = switch (repeat) {
        NotificationRepeat.none => null,
        NotificationRepeat.daily => DateTimeComponents.time,
        NotificationRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
      };
      final scopePrefix = storageScope == null
          ? ''
          : '${userStorageScopeToken(storageScope!)}|';
      final payload = '$scopePrefix$type|$recordKey';
      final details = const NotificationDetails(
        android: AndroidNotificationDetails(
          'furlo_reminders',
          'Furlo reminders',
          channelDescription: 'Pet care reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      final scheduled = tz.TZDateTime.from(dateTime, _localLocation);
      try {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: components,
          payload: payload,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id: notificationId,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: components,
          payload: payload,
        );
      }
    } catch (_) {
      // Plugin/platform errors are isolated to the reminder operation.
    }
  }

  @override
  Future<void> cancel(String type, String id) async {
    final scopedId = stableNotificationId(type, id, scope: storageScope);
    await _cancelOwnedNotifications((payload) {
      final prefix = storageScope == null
          ? '$type|$id'
          : '${userStorageScopeToken(storageScope!)}|$type|';
      return storageScope == null
          ? payload == '$type|$id'
          : payload.startsWith(prefix) && payload.endsWith(':$id');
    }, notificationId: scopedId);
  }

  @override
  Future<void> cancelAllOfType(String type) async {
    final prefix = storageScope == null
        ? '$type|'
        : '${userStorageScopeToken(storageScope!)}|$type|';
    await _cancelOwnedNotifications(
      (payload) => payload.startsWith(prefix),
      notificationTypes: {type},
    );
  }

  @override
  Future<void> clearScheduled() async {
    await _cancelOwnedNotifications(
      (payload) => notificationPayloadIsOwnedByScope(
        payload,
        storageScope: storageScope,
      ),
    );
  }

  (String, String)? _notificationFromPayload(String payload) {
    if (!notificationPayloadIsOwnedByScope(
      payload,
      storageScope: storageScope,
    )) {
      return null;
    }
    final fields = payload.split('|');
    if (storageScope == null) return (fields.first, fields.last);
    return (fields[1], fields.sublist(2).join('|'));
  }

  Future<void> _cancelOwnedNotifications(
    bool Function(String payload) owns, {
    int? notificationId,
    Set<String>? notificationTypes,
  }) async {
    try {
      await initialize();
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        final notification = payload == null
            ? null
            : _notificationFromPayload(payload);
        if ((notificationId == null || request.id == notificationId) &&
            (notificationTypes == null ||
                notificationTypes.contains(notification?.$1)) &&
            payload != null &&
            owns(payload)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> rescheduleAll() async {
    try {
      await initialize();
      await clearScheduled();
      if (!await hasPermission()) return;
      final pets = await repository.getPets();
      for (final pet in pets) {
        final petId = pet.id;
        if (petId == null) continue;
        await _scheduleFeeding(pet, petId);
        await _scheduleVaccinations(pet, petId);
        await _scheduleMedication(pet, petId);
        await _scheduleAppointments(pet, petId);
      }
    } catch (_) {
      // Rebuild is best-effort; a repository/plugin failure cannot block launch.
    }
  }

  Future<void> _scheduleFeeding(Pet pet, String petId) async {
    final schedules = await repository.getFeedingSchedules(petId);
    for (final entry in schedules) {
      final id = entry.id;
      if (id == null || !entry.remindMe) continue;
      final now = DateTime.now();
      final isOneTime = entry.frequency == FeedingEntry.doesNotRepeat;
      final scheduledDate = entry.scheduledDate;
      if (isOneTime &&
          (scheduledDate == null ||
              scheduledDate.isBefore(DateTime(now.year, now.month, now.day)) ||
              entry.isComplete)) {
        continue;
      }
      final feedDate = isOneTime
          ? calculateOneTimeFeedingFireTime(
              now: now,
              enabled: await settings.isEnabled(NotificationTypes.dailyFeeding),
              date: scheduledDate!,
              time: entry.time,
            )
          : calculateNotificationFireTime(
              type: NotificationTypes.dailyFeeding,
              now: now,
              enabled: await settings.isEnabled(NotificationTypes.dailyFeeding),
              time: entry.time,
            );
      if (feedDate == null) continue;
      final title = 'Feeding reminder';
      final body = '${pet.name} is due for ${entry.name}.';
      await schedule(
        NotificationTypes.dailyFeeding,
        id,
        title,
        body,
        feedDate,
        repeat: isOneTime ? NotificationRepeat.none : NotificationRepeat.daily,
      );
      final missed = isOneTime
          ? null
          : calculateNotificationFireTime(
              type: NotificationTypes.missedMeal,
              now: now,
              enabled: await settings.isEnabled(NotificationTypes.missedMeal),
              time: entry.time,
              isDone: entry.doneToday,
            );
      if (missed != null) {
        await schedule(
          NotificationTypes.missedMeal,
          id,
          'Missed meal reminder',
          '${pet.name} may have missed ${entry.name}.',
          missed,
        );
      }
    }
  }

  Future<void> _scheduleVaccinations(Pet pet, String petId) async {
    final records = await repository.getVaccinationsForPet(petId);
    for (final vaccination in records) {
      final id = vaccination.id;
      final due = vaccination.nextDueDate;
      if (id == null || due == null || vaccination.isCompleted) continue;
      final upcoming = calculateNotificationFireTime(
        type: NotificationTypes.upcomingVaccine,
        now: DateTime.now(),
        enabled: await settings.isEnabled(NotificationTypes.upcomingVaccine),
        date: due,
      );
      if (upcoming != null) {
        await schedule(
          NotificationTypes.upcomingVaccine,
          id,
          'Vaccine due soon',
          '${pet.name} is due for ${vaccination.vaccineName} on ${_date(due)}.',
          upcoming,
        );
      }
      final overdue = calculateNotificationFireTime(
        type: NotificationTypes.overdueVaccine,
        now: DateTime.now(),
        enabled: await settings.isEnabled(NotificationTypes.overdueVaccine),
        date: due,
      );
      if (overdue != null) {
        await schedule(
          NotificationTypes.overdueVaccine,
          id,
          'Vaccine overdue',
          '${pet.name} is overdue for ${vaccination.vaccineName}.',
          overdue,
        );
      }
    }
  }

  Future<void> _scheduleAppointments(Pet pet, String petId) async {
    final vets = await repository.getVetsForPet(petId);
    for (final vet in vets) {
      final vetId = vet.id;
      if (vetId == null) continue;
      final link = (await repository.getVetPetAssociations(
        vetId,
      )).where((item) => item.petId == petId).firstOrNull;
      final date = link?.nextAppointmentDate;
      if (date == null) continue;
      final fire = calculateNotificationFireTime(
        type: NotificationTypes.vetAppointment,
        now: DateTime.now(),
        enabled: await settings.isEnabled(NotificationTypes.vetAppointment),
        date: date,
      );
      if (fire != null) {
        await schedule(
          NotificationTypes.vetAppointment,
          _appointmentId(vetId, petId),
          'Vet appointment tomorrow',
          '${pet.name} has an appointment with ${vet.name} on ${_date(date)}.',
          fire,
        );
      }
    }
  }

  Future<void> _scheduleMedication(Pet pet, String petId) async {
    final records = await repository.getHealthRecordsForPet(petId);
    for (final record in records) {
      if (record.type != HealthRecordTypes.medication ||
          record.reminderActive != true ||
          record.date == null ||
          record.id == null) {
        continue;
      }
      final frequency = record.reminderFrequency?.toLowerCase() ?? 'daily';
      if (frequency == 'monthly') {
        // The plugin has no monthly calendar-repeat component; keep a rolling
        // 12 month schedule, rebuilt on each app start or record/settings change.
        for (var monthOffset = 0; monthOffset < 12; monthOffset++) {
          final occurrence = _monthlyOccurrence(
            DateTime.now(),
            monthOffset,
            record.date!,
          );
          if (occurrence == null) continue;
          final id = stableNotificationId(
            NotificationTypes.medication,
            '${record.id}:$monthOffset',
            scope: storageScope,
          );
          await _scheduleWithId(
            NotificationTypes.medication,
            id,
            storageScope == null
                ? record.id!
                : '${userStorageScopeToken(storageScope!)}:${record.id!}',
            'Medication reminder',
            '${pet.name} is due for ${record.title}.',
            occurrence,
          );
        }
        continue;
      }
      final fire = calculateNotificationFireTime(
        type: NotificationTypes.medication,
        now: DateTime.now(),
        enabled: await settings.isEnabled(NotificationTypes.medication),
        date: record.date,
        frequency: frequency,
      );
      if (fire == null) continue;
      await schedule(
        NotificationTypes.medication,
        record.id!,
        'Medication reminder',
        '${pet.name} is due for ${record.title}.',
        fire,
        repeat: frequency == 'weekly'
            ? NotificationRepeat.weekly
            : NotificationRepeat.daily,
      );
    }
  }

  DateTime? _monthlyOccurrence(DateTime now, int offset, DateTime start) {
    var base = _monthlyDate(now.year, now.month, start.day);
    if (!base.isAfter(now)) {
      base = _monthlyDate(now.year, now.month + 1, start.day);
    }
    final startsAt = DateTime(start.year, start.month, start.day, 9);
    while (base.isBefore(startsAt)) {
      base = _monthlyDate(base.year, base.month + 1, start.day);
    }
    return _monthlyDate(base.year, base.month + offset, start.day);
  }

  DateTime _monthlyDate(int year, int month, int day) {
    final first = DateTime(year, month, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day.clamp(1, lastDay), 9);
  }

  String _appointmentId(String vetId, String petId) => '$vetId:$petId';

  String _date(DateTime date) => '${_month(date.month)} ${date.day}';
  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
