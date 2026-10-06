import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('petAgeLabel', () {
    final today = DateTime(2026, 10, 2);

    test('formats years and remaining months', () {
      expect(petAgeLabel(DateTime(2024, 7, 2), today: today), '2 yrs 3 mos');
      expect(petAgeLabel(DateTime(2025, 10, 2), today: today), '1 yr');
      expect(petAgeLabel(DateTime(2026, 9, 2), today: today), '1 mo');
    });

    test('handles missing, future, and not-yet-reached birth day', () {
      expect(petAgeLabel(null, today: today), 'Not provided');
      expect(petAgeLabel(DateTime(2026, 11, 1), today: today), 'Not provided');
      expect(petAgeLabel(DateTime(2026, 9, 30), today: today), '0 mos');
    });
  });

  testWidgets('export button remains idle while the PDF choice sheet is open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: PetProfileScreen(petId: '1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export care summary'));
    await tester.pumpAndSettle();

    expect(find.text('Save PDF'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Export care summary'), findsOneWidget);
    expect(find.text('Generating PDF…'), findsNothing);

    Navigator.of(tester.element(find.text('Save PDF'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Export care summary'), findsOneWidget);
    expect(find.text('Generating PDF…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
