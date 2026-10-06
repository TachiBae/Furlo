import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_account_onboarding_repository.dart';
import 'helpers/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'saving a pet from the dashboard adds it and returns to the dashboard',
    (tester) async {
      final repository = WebPetRepository();
      final auth = FakeAuthService(
        initialUser: const AuthUser(
          uid: 'returning',
          email: 'r@e.test',
          displayName: null,
        ),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        FurloApp(
          authService: auth,
          accountOnboardingRepository: FakeAccountOnboardingRepository(),
          repository: repository,
          notificationService: const NoOpNotificationService(),
        ),
      );
      await tester.pumpAndSettle();

      // Returning account with no pets shows the dashboard add-pet state.
      expect(
        find.text('Add a pet to start keeping their care in one place.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.add_circle).first);
      await tester.pumpAndSettle();
      expect(find.text('Add New Pet'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Pip');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dog').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6 && find.text('Save Pet').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save Pet'));
      await tester.pumpAndSettle();

      // The save must succeed and land back on the dashboard.
      expect(
        find.text('Could not save your pet. Please try again.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      expect((await repository.getPets()).length, 1);
      expect((await repository.getPets()).single.name, 'Pip');
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add New Pet'), findsNothing);
    },
  );
}
