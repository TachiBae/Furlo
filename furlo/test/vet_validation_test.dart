import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/utils/vet_validation.dart';

void main() {
  test('vet model maps nullable fields and identifiers', () {
    final vet = Vet(
      id: '9',
      name: 'Dr. Lee',
      phone: '+1 (555) 123-4567',
      clinic: 'Paws',
    );
    final restored = Vet.fromMap(vet.toMap());
    expect(restored.id, '9');
    expect(restored.name, 'Dr. Lee');
    expect(restored.phone, '+1 (555) 123-4567');
    expect(restored.clinic, 'Paws');
    expect(restored.email, isNull);
  });

  test('phone and email validators', () {
    expect(validateVetPhone(''), isNotNull);
    expect(validateVetPhone('555-123-4567'), isNull);
    expect(validateVetPhone('123'), isNotNull);
    expect(validateVetEmail(''), isNull);
    expect(validateVetEmail('lee@example.com'), isNull);
    expect(validateVetEmail('bad-email'), isNotNull);
  });
}
