/// Shared date and text formatting helpers.
///
/// These replace the five near-identical `_formatDate` / `_month` /
/// `_titleCase` copies that lived inside individual screens and services.
const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String monthAbbr(int month) => _shortMonths[month - 1];

/// `Jan 5, 2026`, or `Not set` when null.
String formatShortDate(DateTime? value) =>
    value == null ? 'Not set' : shortDateWithYear(value);

/// Same as [formatShortDate] for callers that always hold a date.
String shortDateWithYear(DateTime value) =>
    '${monthAbbr(value.month)} ${value.day}, ${value.year}';

/// `Jan 5`, or an empty string when null.
String formatMonthDay(DateTime? value) =>
    value == null ? '' : '${monthAbbr(value.month)} ${value.day}';

/// Capitalizes the first letter of every word: `due soon` -> `Due Soon`.
String capitalizeWords(String value) => value
    .split(' ')
    .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
