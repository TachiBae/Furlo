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

  /// Recorded answers for the pre-account data import question, one per
  /// account, so the same account is never asked twice.
  static const String legacyImportApproved = 'import';
  static const String legacyImportDeclined = 'decline';

  String get _legacyImportChoiceKey => storageScope == null
      ? 'legacy.import_choice'
      : 'legacy.user.${userStorageScopeToken(storageScope!)}.import_choice';

  String get _legacyImportAttemptKey => storageScope == null
      ? 'legacy.import_in_progress'
      : 'legacy.user.${userStorageScopeToken(storageScope!)}.import_in_progress';

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

  /// The account's stored answer to "Import pets from this device?",
  /// or null while the question has not been answered yet.
  Future<String?> getLegacyImportChoice() async {
    final preferences = await _preferences();
    return preferences?.getString(_legacyImportChoiceKey);
  }

  Future<void> setLegacyImportChoice(String choice) async {
    final preferences = await _preferences();
    await preferences?.setString(_legacyImportChoiceKey, choice);
  }

  /// True between the moment an Import starts and its success: a failed
  /// attempt stays flagged so the next Import can resume the copy instead of
  /// skipping a partially filled account.
  Future<bool> isLegacyImportInProgress() async =>
      (await _preferences())?.getBool(_legacyImportAttemptKey) ?? false;

  Future<void> setLegacyImportInProgress(bool value) async {
    final preferences = await _preferences();
    if (value) {
      await preferences?.setBool(_legacyImportAttemptKey, true);
    } else {
      await preferences?.remove(_legacyImportAttemptKey);
    }
  }
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter a display name';
  if (name.length > 40) return 'Use 40 characters or fewer';
  return null;
}
