import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';
import 'package:furlo/providers/theme_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a theme restored before runApp is used from the first frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ThemeSettings.preferenceKey: 'light',
    });
    final settings = ThemeSettings();
    await settings.load();
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      FurloApp(
        authService: auth,
        accountOnboardingRepository: FakeAccountOnboardingRepository(),
        themeSettings: settings,
      ),
    );

    // One frame, no settling: no Default-palette splash in between.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.brightness, Brightness.light);
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppPalette.defaultTheme.bg,
      ),
      findsNothing,
    );
  });
}
