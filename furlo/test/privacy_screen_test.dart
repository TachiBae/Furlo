import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/providers/theme_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings opens the privacy note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ThemeSettings(),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ProfileScreen(
            repository: WebPetRepository(),
            appSettings: SharedPreferencesAppSettingsRepository(),
            notificationSettings:
                SharedPreferencesNotificationSettingsRepository(),
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Privacy'));
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    for (final heading in [
      'What Furlo stores',
      'Where it is kept',
      'Who can see it',
      'What Furlo does not do',
      'Deleting your data',
    ]) {
      await tester.scrollUntilVisible(find.text(heading), 100);
      expect(find.text(heading), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
