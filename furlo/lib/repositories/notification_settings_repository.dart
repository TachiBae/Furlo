import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class NotificationTypes {
  static const dailyFeeding = 'daily_feeding';
  static const missedMeal = 'missed_meal';
  static const upcomingVaccine = 'upcoming_vaccine';
  static const overdueVaccine = 'overdue_vaccine';
  static const vetAppointment = 'vet_appointment';
  static const medication = 'medication';

  static const all = [
    dailyFeeding,
    missedMeal,
    upcomingVaccine,
    overdueVaccine,
    vetAppointment,
    medication,
  ];
}

abstract interface class NotificationSettingsRepository {
  Future<bool> isEnabled(String type);
  Future<Map<String, bool>> getAll();
  Future<void> setEnabled(String type, bool enabled);
  Future<bool> permissionWasRequested();
  Future<void> markPermissionRequested();
  Future<void> clearAll();
}

class SharedPreferencesNotificationSettingsRepository
    implements NotificationSettingsRepository {
  static const _keyPrefix = 'notification.enabled.';
  static const _permissionRequestedKey = 'notification.permission_requested';
  static final Map<String, bool> _webMemory = {};
  static bool? _permissionMemory;

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      // SharedPreferences supports web. This fallback also avoids plugin errors
      // when running tests or a partially configured platform target.
      return null;
    }
  }

  @override
  Future<bool> isEnabled(String type) async {
    if (!NotificationTypes.all.contains(type)) return false;
    final preferences = await _preferences();
    if (preferences == null) return kIsWeb ? (_webMemory[type] ?? true) : true;
    return preferences.getBool('$_keyPrefix$type') ??
        (kIsWeb ? (_webMemory[type] ?? true) : true);
  }

  @override
  Future<Map<String, bool>> getAll() async => {
    for (final type in NotificationTypes.all) type: await isEnabled(type),
  };

  @override
  Future<void> setEnabled(String type, bool enabled) async {
    if (!NotificationTypes.all.contains(type)) return;
    final preferences = await _preferences();
    if (preferences == null) {
      if (kIsWeb) _webMemory[type] = enabled;
      return;
    }
    final stored = await preferences.setBool('$_keyPrefix$type', enabled);
    if (kIsWeb && !stored) _webMemory[type] = enabled;
  }

  @override
  Future<bool> permissionWasRequested() async {
    final preferences = await _preferences();
    if (preferences == null) {
      return kIsWeb ? (_permissionMemory ?? false) : false;
    }
    return preferences.getBool(_permissionRequestedKey) ?? false;
  }

  @override
  Future<void> markPermissionRequested() async {
    final preferences = await _preferences();
    if (preferences == null) {
      if (kIsWeb) _permissionMemory = true;
      return;
    }
    await preferences.setBool(_permissionRequestedKey, true);
  }

  @override
  Future<void> clearAll() async {
    _webMemory.clear();
    _permissionMemory = false;
    final preferences = await _preferences();
    await preferences?.clear();
  }
}
