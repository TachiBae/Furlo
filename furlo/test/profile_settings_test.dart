import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/services/notifications_service.dart';

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

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          appSettings: settings,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
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
      MaterialApp(
        home: ProfileScreen(
          repository: repository,
          appSettings: settings,
          notificationSettings: notifications,
          notificationService: const NoOpNotificationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}
