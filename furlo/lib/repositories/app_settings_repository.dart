import 'package:shared_preferences/shared_preferences.dart';

import '../utils/user_storage_scope.dart';

abstract interface class AppSettingsRepository {
  Future<String> getDisplayName();
  Future<void> setDisplayName(String value);
  Future<void> clearDisplayName();
}

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  SharedPreferencesAppSettingsRepository({this.storageScope});

  final String? storageScope;
  static const _legacyDisplayNameKey = 'profile.display_name';
  static final Map<String, String> _memoryDisplayNames = {};

  String get _displayNameKey => storageScope == null
      ? _legacyDisplayNameKey
      : 'profile.user.${userStorageScopeToken(storageScope!)}.display_name';

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> getDisplayName() async {
    final preferences = await _preferences();
    return preferences?.getString(_displayNameKey) ??
        _memoryDisplayNames[_displayNameKey] ??
        '';
  }

  @override
  Future<void> setDisplayName(String value) async {
    final trimmed = value.trim();
    _memoryDisplayNames[_displayNameKey] = trimmed;
    final preferences = await _preferences();
    if (preferences != null) {
      await preferences.setString(_displayNameKey, trimmed);
    }
  }

  @override
  Future<void> clearDisplayName() async {
    _memoryDisplayNames.remove(_displayNameKey);
    final preferences = await _preferences();
    await preferences?.remove(_displayNameKey);
  }
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter a display name';
  if (name.length > 40) return 'Use 40 characters or fewer';
  return null;
}
