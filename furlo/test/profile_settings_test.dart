import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppSettingsRepository implements AppSettingsRepository {
  String value = '';

  @override
  Future<void> clearDisplayName() async => value = '';

  @override
  Future<String> getDisplayName() async => value;

  @override
  Future<void> setDisplayName(String value) async => this.value = value.trim();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  double contrast(Color foreground, Color background) {
    final light = foreground.computeLuminance();
    final dark = background.computeLuminance();
    final high = light > dark ? light : dark;
    final low = light > dark ? dark : light;
    return (high + 0.05) / (low + 0.05);
  }

  test('both palettes meet body-text contrast and remain grayscale', () {
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final color in [
        palette.bg,
        palette.surface,
        palette.surfaceAlt,
        palette.primary,
        palette.primaryMuted,
        palette.accent,
        palette.textPrimary,
        palette.textSecondary,
        palette.textDisabled,
      ]) {
        final argb = color.toARGB32();
        final red = (argb >> 16) & 0xFF;
        final green = (argb >> 8) & 0xFF;
        final blue = argb & 0xFF;
        expect(red, green);
        expect(green, blue);
      }
      expect(
        contrast(palette.textPrimary, palette.bg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(palette.textPrimary, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(palette.textSecondary, palette.bg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(palette.textSecondary, palette.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('overdue status text and danger button labels meet AA contrast', () {
    for (final palette in [
      AppPalette.defaultTheme,
      AppPalette.light,
      AppPalette.dark,
    ]) {
      // Overdue status captions render in `danger` on cards.
      expect(
        contrast(palette.danger, palette.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'danger on surface',
      );
      expect(
        contrast(palette.danger, palette.bg),
        greaterThanOrEqualTo(4.5),
        reason: 'danger on bg',
      );
      // "Delete pet" style labels: textOnDanger on danger fill.
      expect(
        contrast(palette.textOnDanger, palette.danger),
        greaterThanOrEqualTo(4.5),
        reason: 'textOnDanger on danger',
      );
    }
  });

  test('Light keeps a colored danger token for urgency semantics', () {
    // Neutrals must stay grayscale (see the palette test above), but the
    // danger token carries overdue/missed meaning and must stay a hue so
    // urgency is distinguishable even in the Light theme.
    final argb = AppPalette.light.danger.toARGB32();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    expect(red, isNot(green));
    expect(green, isNot(blue));
  });

  test('theme choice defaults to Default and restores saved choices', () async {
    final settings = ThemeSettings();
    expect(settings.choice, AppThemeChoice.defaultTheme);

    await settings.setThemeMode(AppThemeChoice.dark);
    final restored = ThemeSettings();
    await restored.load();
    expect(restored.choice, AppThemeChoice.dark);

    await restored.setThemeMode(AppThemeChoice.defaultTheme);
    final reset = ThemeSettings();
    await reset.load();
    expect(reset.choice, AppThemeChoice.defaultTheme);
  });

  test('legacy system and unknown theme values migrate to Default', () async {
    for (final saved in ['system', 'unrecognized']) {
      SharedPreferences.setMockInitialValues({
        ThemeSettings.preferenceKey: saved,
      });
      final settings = ThemeSettings();
      await settings.load();
      expect(settings.choice, AppThemeChoice.defaultTheme);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(ThemeSettings.preferenceKey), 'default');
    }
  });

  test('display name validation requires trimmed text up to 40 characters', () {
    expect(validateDisplayName(null), 'Enter a display name');
    expect(validateDisplayName('   '), 'Enter a display name');
    expect(validateDisplayName('  Ada  '), isNull);
    expect(validateDisplayName('a' * 41), 'Use 40 characters or fewer');
  });

  testWidgets('edited display name persists through the settings fake', (
    tester,
  ) async {
    final settings = _FakeAppSettingsRepository();
    final repository = WebPetRepository();
    final notifications = SharedPreferencesNotificationSettingsRepository();
    final themeSettings = ThemeSettings();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeSettings,
        child: MaterialApp(
          home: ProfileScreen(
            repository: repository,
            appSettings: settings,
            notificationSettings: notifications,
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Display name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Ada Lovelace  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.value, 'Ada Lovelace');
    expect(find.text('Ada Lovelace'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeSettings,
        child: MaterialApp(
          home: ProfileScreen(
            repository: repository,
            appSettings: settings,
            notificationSettings: notifications,
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('theme row offers and saves Default, Light, and Dark', (
    tester,
  ) async {
    final themeSettings = ThemeSettings();
    await themeSettings.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeSettings,
        child: MaterialApp(
          home: ProfileScreen(
            repository: WebPetRepository(),
            appSettings: _FakeAppSettingsRepository(),
            notificationSettings:
                SharedPreferencesNotificationSettingsRepository(),
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Default'), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButton<AppThemeChoice>));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(themeSettings.choice, AppThemeChoice.dark);
    expect(
      SharedPreferences.getInstance().then(
        (preferences) => preferences.getString(ThemeSettings.preferenceKey),
      ),
      completion('dark'),
    );
  });
}
