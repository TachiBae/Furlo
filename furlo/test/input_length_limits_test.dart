import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pet name field is capped at 40 characters', (tester) async {
    final repository = WebPetRepository();
    await tester.pumpWidget(
      MaterialApp(home: AddPetScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    expect(nameField.maxLength, 40);
  });

  testWidgets('meal name field is capped at 40 characters', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: FeedingScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add feeding schedule'));
    await tester.pumpAndSettle();

    final mealNameField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    expect(mealNameField.maxLength, 40);
  });

  testWidgets('vet name field is capped at 40 characters', (tester) async {
    final repository = WebPetRepository();
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: VetFormScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    expect(nameField.maxLength, 40);
  });
}
