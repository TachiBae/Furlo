import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/screens/pets/pet_profile_screen.dart';

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

  test('selected pet falls back to a remaining pet or null after delete', () {
    final state = FurloState();
    final milo = Pet(id: 1, name: 'Milo', species: 'Dog');
    final luna = Pet(id: 2, name: 'Luna', species: 'Cat');
    state.setPets([milo, luna]);
    state.selectPet(luna);

    state.setPets([milo]);
    expect(state.selectedPet?.id, milo.id);

    state.setPets([]);
    expect(state.selectedPet, isNull);
  });
}
