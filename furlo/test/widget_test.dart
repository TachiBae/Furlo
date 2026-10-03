// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts with onboarding when there are no pets', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();

    await tester.pumpWidget(
      FurloApp(
        repository: repository,
        notificationService: const NoOpNotificationService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Track Your Pet's Care"), findsOneWidget);
  });

  testWidgets('starts with Home when a pet is already saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));

    await tester.pumpWidget(
      FurloApp(
        repository: repository,
        notificationService: const NoOpNotificationService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Track Your Pet\'s Care'), findsNothing);
  });
}
