import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/data/health_record_types.dart';
import 'package:furlo/models/health_record.dart';
import 'package:furlo/utils/health_record_validation.dart';

void main() {
  test('health record toMap and fromMap preserve nullable reminder values', () {
    final record = HealthRecord(
      id: '4',
      petId: '2',
      title: 'Medication check',
      date: DateTime(2026, 8, 13),
      type: HealthRecordTypes.medication,
      notes: 'One tablet',
      reminderFrequency: HealthReminderFrequencies.weekly,
      reminderActive: true,
    );
    final decoded = HealthRecord.fromMap(record.toMap());

    expect(decoded.id, record.id);
    expect(decoded.petId, record.petId);
    expect(decoded.title, record.title);
    expect(decoded.date, record.date);
    expect(decoded.type, record.type);
    expect(decoded.notes, record.notes);
    expect(decoded.reminderFrequency, record.reminderFrequency);
    expect(decoded.reminderActive, isTrue);
  });

  test('non-medication records preserve null reminder fields', () {
    final decoded = HealthRecord.fromMap(
      HealthRecord(
        petId: '3',
        title: 'Annual exam',
        date: DateTime(2026, 1, 2),
        type: HealthRecordTypes.checkup,
      ).toMap(),
    );
    expect(decoded.reminderFrequency, isNull);
    expect(decoded.reminderActive, isNull);
  });

  test(
    'reminder frequency is required only for active medication reminders',
    () {
      expect(
        validateHealthReminderFrequency(
          type: HealthRecordTypes.medication,
          reminderActive: true,
          frequency: null,
        ),
        isNotNull,
      );
      expect(
        validateHealthReminderFrequency(
          type: HealthRecordTypes.medication,
          reminderActive: true,
          frequency: 'sometimes',
        ),
        isNotNull,
      );
      expect(
        validateHealthReminderFrequency(
          type: HealthRecordTypes.medication,
          reminderActive: false,
          frequency: null,
        ),
        isNull,
      );
      expect(
        validateHealthReminderFrequency(
          type: HealthRecordTypes.checkup,
          reminderActive: true,
          frequency: null,
        ),
        isNull,
      );
      expect(
        validateHealthReminderFrequency(
          type: HealthRecordTypes.medication,
          reminderActive: true,
          frequency: HealthReminderFrequencies.monthly,
        ),
        isNull,
      );
    },
  );
}
