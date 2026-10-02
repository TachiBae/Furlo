abstract final class HealthRecordTypes {
  static const checkup = 'Checkup';
  static const medication = 'Medication';
  static const illnessInjury = 'Illness/Injury';
  static const surgery = 'Surgery';
  static const labTest = 'Lab Test';
  static const other = 'Other';

  static const values = <String>[
    checkup,
    medication,
    illnessInjury,
    surgery,
    labTest,
    other,
  ];
}

abstract final class HealthReminderFrequencies {
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';

  static const values = <String>[daily, weekly, monthly];
}
