import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/vaccination.dart';

void main() {
  final today = DateTime(2026, 4, 10);

  test('status is due soon for a vaccine due today', () {
    expect(
      deriveVaccinationStatus(today, today: today),
      VaccinationStatuses.dueSoon,
    );
  });

  test('status is due soon for a vaccine due tomorrow', () {
    expect(
      deriveVaccinationStatus(DateTime(2026, 4, 11), today: today),
      VaccinationStatuses.dueSoon,
    );
  });

  test('status is overdue for a past due vaccine', () {
    expect(
      deriveVaccinationStatus(DateTime(2026, 4, 9), today: today),
      VaccinationStatuses.overdue,
    );
  });

  test('status is completed when there is no next due date', () {
    expect(
      deriveVaccinationStatus(null, today: today),
      VaccinationStatuses.completed,
    );
  });

  test(
    'explicitly completed status can be reversed without a due date change',
    () {
      expect(
        deriveVaccinationStatus(today, isCompleted: true, today: today),
        VaccinationStatuses.completed,
      );
      expect(
        deriveVaccinationStatus(today, isCompleted: false, today: today),
        VaccinationStatuses.dueSoon,
      );
    },
  );

  test('status is due soon no matter how far in the future the date is', () {
    expect(
      deriveVaccinationStatus(DateTime(2036, 4, 10), today: today),
      VaccinationStatuses.dueSoon,
    );
  });

  test('toMap and fromMap preserve vaccination fields', () {
    final vaccination = Vaccination(
      id: '12',
      petId: '5',
      vaccineName: 'Rabies',
      dateGiven: DateTime(2026, 2, 3),
      nextDueDate: DateTime(2027, 2, 3),
      isCompleted: true,
    );
    final map = vaccination.toMap(today: today);
    final decoded = Vaccination.fromMap(map);

    expect(map['status'], VaccinationStatuses.completed);
    expect(decoded.id, vaccination.id);
    expect(decoded.petId, vaccination.petId);
    expect(decoded.vaccineName, vaccination.vaccineName);
    expect(decoded.dateGiven, vaccination.dateGiven);
    expect(decoded.nextDueDate, vaccination.nextDueDate);
    expect(decoded.isCompleted, isTrue);
    expect(decoded.status, VaccinationStatuses.completed);
  });

  test('fromMap recomputes stale stored status from next due date', () {
    final decoded = Vaccination.fromMap({
      'id': 1,
      'pet_id': 8,
      'vaccine_name': 'Core vaccine',
      'date_given': '2026-04-01T00:00:00.000',
      'next_due_date': '2026-04-09T00:00:00.000',
      'status': VaccinationStatuses.upcoming,
    });
    expect(decoded.status, VaccinationStatuses.overdue);
  });
}
