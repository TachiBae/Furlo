import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/vaccine_catalog.dart';

void main() {
  test(
    'dog species returns only dog vaccines after trimming and lowercasing',
    () {
      final vaccines = vaccinesFor('  DOG  ');
      expect(vaccines, contains('DHPP'));
      expect(vaccines, contains('Canine Influenza'));
      expect(vaccines, isNot(contains('FVRCP')));
    },
  );

  test('cat species returns only cat vaccines', () {
    final vaccines = vaccinesFor('Cat');
    expect(vaccines, contains('FVRCP'));
    expect(vaccines, contains('FeLV (Feline Leukemia)'));
    expect(vaccines, isNot(contains('DHPP')));
  });

  test('unknown species returns no catalog vaccines', () {
    expect(vaccinesFor('rabbit'), isEmpty);
    expect(vaccinesFor(''), isEmpty);
  });
}
