import '../data/health_record_types.dart';

/// Returns an error when an active medication reminder has no valid frequency.
String? validateHealthReminderFrequency({
  required String type,
  required bool reminderActive,
  required String? frequency,
}) {
  if (type != HealthRecordTypes.medication || !reminderActive) return null;
  if (frequency == null ||
      !HealthReminderFrequencies.values.contains(frequency)) {
    return 'Choose a reminder frequency';
  }
  return null;
}
