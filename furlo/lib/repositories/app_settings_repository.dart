import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppSettingsRepository {
  Future<String> getDisplayName();
  Future<void> setDisplayName(String value);
  Future<void> clearDisplayName();
}

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  static const _displayNameKey = 'profile.display_name';
  static String? _memoryDisplayName;

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
    return preferences?.getString(_displayNameKey) ?? _memoryDisplayName ?? '';
  }

  @override
  Future<void> setDisplayName(String value) async {
    final trimmed = value.trim();
    _memoryDisplayName = trimmed;
    final preferences = await _preferences();
    if (preferences != null) {
      await preferences.setString(_displayNameKey, trimmed);
    }
  }

  @override
  Future<void> clearDisplayName() async {
    _memoryDisplayName = null;
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
