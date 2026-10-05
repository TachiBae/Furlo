import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/screens/settings/notifications_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'notifications empty state avoids short-viewport overflows in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final textScale in [1.0, 1.5]) {
          SharedPreferences.setMockInitialValues({});
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: NotificationsScreen(
                settings: SharedPreferencesNotificationSettingsRepository(),
                service: const NoOpNotificationService(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'theme=${theme.brightness}, text scale=$textScale',
          );
          expect(find.text('No notifications yet'), findsOneWidget);
        }
      }
    },
  );
}
