import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/utils/formatting.dart';

void main() {
  test('formatShortDate renders month-day-year and handles null', () {
    expect(formatShortDate(DateTime(2026, 1, 5)), 'Jan 5, 2026');
    expect(formatShortDate(DateTime(2026, 12, 31)), 'Dec 31, 2026');
    expect(formatShortDate(null), 'Not set');
  });

  test('formatMonthDay renders month-day and handles null', () {
    expect(formatMonthDay(DateTime(2026, 1, 5)), 'Jan 5');
    expect(formatMonthDay(null), '');
  });

  test('capitalizeWords capitalizes each word', () {
    expect(capitalizeWords('due soon'), 'Due Soon');
    expect(capitalizeWords('daily'), 'Daily');
    expect(capitalizeWords(''), '');
    expect(capitalizeWords('a b'), 'A B');
  });

  test('monthAbbr maps month numbers to abbreviations', () {
    expect(monthAbbr(1), 'Jan');
    expect(monthAbbr(9), 'Sep');
    expect(monthAbbr(12), 'Dec');
  });
}
