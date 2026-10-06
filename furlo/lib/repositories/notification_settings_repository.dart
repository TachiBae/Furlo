import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/user_storage_scope.dart';

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
  SharedPreferencesNotificationSettingsRepository({this.storageScope});

  final String? storageScope;
  static const _legacyKeyPrefix = 'notification.enabled.';
  static const _legacyPermissionRequestedKey =
      'notification.permission_requested';
  static final Map<String, bool> _webMemory = {};
  static final Map<String, bool> _permissionMemory = {};

  String _key(String type) => storageScope == null
      ? '$_legacyKeyPrefix$type'
      : 'notification.user.${userStorageScopeToken(storageScope!)}.enabled.$type';

  String get _permissionKey => storageScope == null
      ? _legacyPermissionRequestedKey
      : 'notification.user.${userStorageScopeToken(storageScope!)}.permission_requested';

  String get _memoryScope =>
      storageScope == null ? 'legacy' : userStorageScopeToken(storageScope!);

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
    final key = _key(type);
    if (preferences == null) {
      return kIsWeb ? (_webMemory[key] ?? true) : true;
    }
    return preferences.getBool(key) ??
        (kIsWeb ? (_webMemory[key] ?? true) : true);
  }

  @override
  Future<Map<String, bool>> getAll() async => {
    for (final type in NotificationTypes.all) type: await isEnabled(type),
  };

  @override
  Future<void> setEnabled(String type, bool enabled) async {
    if (!NotificationTypes.all.contains(type)) return;
    final preferences = await _preferences();
    final key = _key(type);
    if (preferences == null) {
      if (kIsWeb) _webMemory[key] = enabled;
      return;
    }
    final stored = await preferences.setBool(key, enabled);
    if (stored) {
      _webMemory.remove(key);
    } else if (kIsWeb) {
      _webMemory[key] = enabled;
    }
  }

  @override
  Future<bool> permissionWasRequested() async {
    final preferences = await _preferences();
    if (preferences == null) {
      return kIsWeb ? (_permissionMemory[_memoryScope] ?? false) : false;
    }
    return preferences.getBool(_permissionKey) ?? false;
  }

  @override
  Future<void> markPermissionRequested() async {
    final preferences = await _preferences();
    if (preferences == null) {
      if (kIsWeb) _permissionMemory[_memoryScope] = true;
      return;
    }
    final stored = await preferences.setBool(_permissionKey, true);
    if (stored) {
      _permissionMemory.remove(_memoryScope);
    } else if (kIsWeb) {
      _permissionMemory[_memoryScope] = true;
    }
  }

  @override
  Future<void> clearAll() async {
    for (final type in NotificationTypes.all) {
      _webMemory.remove(_key(type));
    }
    _permissionMemory.remove(_memoryScope);
    final preferences = await _preferences();
    if (preferences == null) return;
    for (final type in NotificationTypes.all) {
      await preferences.remove(_key(type));
    }
    await preferences.remove(_permissionKey);
  }
}
