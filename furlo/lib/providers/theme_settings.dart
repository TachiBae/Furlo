import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_diagnostics.dart';
import '../utils/app_theme.dart';

/// The person's theme choice (Default, Light or Dark), restored at startup
/// and saved when changed. App state, so it lives with the providers; the
/// palettes and tokens it selects between stay in utils/app_theme.dart.
class ThemeSettings extends ChangeNotifier {
  static const preferenceKey = 'app.theme_mode';

  AppThemeChoice _choice = AppThemeChoice.defaultTheme;
  bool _persistenceFailed = false;

  AppThemeChoice get choice => _choice;
  ThemeData get themeData => AppTheme.forChoice(_choice);
  bool get persistenceFailed => _persistenceFailed;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(preferenceKey);
      _choice = switch (value) {
        'light' => AppThemeChoice.light,
        'dark' => AppThemeChoice.dark,
        _ => AppThemeChoice.defaultTheme,
      };
      if (value == 'system' ||
          (value != null &&
              !const ['default', 'light', 'dark'].contains(value))) {
        final migrated = await preferences.setString(preferenceKey, 'default');
        if (!migrated) {
          throw StateError('The Default theme preference was not saved.');
        }
      }
      _persistenceFailed = false;
    } catch (_) {
      _choice = AppThemeChoice.defaultTheme;
      _persistenceFailed = true;
      logAppDiagnostic('Theme preference restore failed.');
    }
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeChoice choice) async {
    if (choice == _choice) return;
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(preferenceKey, switch (choice) {
      AppThemeChoice.defaultTheme => 'default',
      AppThemeChoice.light => 'light',
      AppThemeChoice.dark => 'dark',
    });
    if (!stored) throw StateError('The theme preference was not saved.');
    _choice = choice;
    _persistenceFailed = false;
    notifyListeners();
  }
}
