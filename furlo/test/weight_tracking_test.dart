import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/utils/weight_tracking.dart';

void main() {
  test('weight log toMap and fromMap preserve values', () {
    final log = WeightLog(
      id: 3,
      petId: 8,
      date: DateTime(2026, 10, 2),
      weight: 8.25,
      notes: 'checkup',
    );
    final restored = WeightLog.fromMap(log.toMap());
    expect(restored.id, 3);
    expect(restored.petId, 8);
    expect(restored.date, DateTime(2026, 10, 2));
    expect(restored.weight, 8.25);
    expect(restored.notes, 'checkup');
  });

  test(
    'weight validation rejects zero, negative, non-numeric and excess decimals',
    () {
      expect(validateWeight('0'), isNotNull);
      expect(validateWeight('-1.2'), isNotNull);
      expect(validateWeight('heavy'), isNotNull);
      expect(validateWeight('3.456'), isNotNull);
      expect(validateWeight('2.35'), isNull);
      expect(validateWeight('.5'), isNull);
    },
  );

  test(
    'change since previous uses latest date and returns null for one entry',
    () {
      final older = WeightLog(
        id: 1,
        petId: 1,
        date: DateTime(2026, 9, 1),
        weight: 9.6,
      );
      final latest = WeightLog(
        id: 2,
        petId: 1,
        date: DateTime(2026, 10, 1),
        weight: 10,
      );
      expect(weightChangeSincePrevious([older]), isNull);
      expect(weightChangeSincePrevious([older, latest]), closeTo(.4, .00001));
      expect(weightChangeSincePrevious([latest, older]), closeTo(.4, .00001));
    },
  );

  test('change can be a neutral negative value', () {
    final older = WeightLog(petId: 1, date: DateTime(2026, 9, 1), weight: 10.2);
    final latest = WeightLog(petId: 1, date: DateTime(2026, 10, 1), weight: 10);
    expect(weightChangeSincePrevious([latest, older]), closeTo(-.2, .00001));
  });
}
