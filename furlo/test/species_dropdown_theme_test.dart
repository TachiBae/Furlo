import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_form_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/providers/theme_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'species dropdown menu and closed-field text follow each theme palette',
    (tester) async {
      for (final choice in AppThemeChoice.values) {
        SharedPreferences.setMockInitialValues({
          ThemeSettings.preferenceKey: choice.name,
        });
        final palette = switch (choice) {
          AppThemeChoice.defaultTheme => AppPalette.defaultTheme,
          AppThemeChoice.light => AppPalette.light,
          AppThemeChoice.dark => AppPalette.dark,
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.forChoice(choice),
            home: AddPetScreen(repository: WebPetRepository()),
          ),
        );
        await tester.pumpAndSettle();

        // Open the species dropdown menu.
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Menu items show the unselected label in the theme's text color.
        final menuDog = find.text('Dog').last;
        expect(
          tester.widget<Text>(menuDog).style?.color,
          palette.textPrimary,
          reason: 'menu item color in $choice',
        );

        // Choose Dog; the menu closes and the field shows the selection.
        await tester.tap(menuDog);
        await tester.pumpAndSettle();

        final closedDog = find.text('Dog');
        expect(closedDog, findsOneWidget);
        expect(
          tester.widget<Text>(closedDog).style?.color,
          palette.textPrimary,
          reason: 'closed-field color in $choice',
        );
        expect(
          tester.widget<Text>(closedDog).style?.color,
          isNot(Colors.black),
          reason: 'closed-field text must not fall back to black in $choice',
        );

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
