part of 'pet_repository.dart';

// Row and map conversions shared by every store.

/// Numeric value of a local id, for the legacy stores that keep integer rows.
int _numericId(String? id) => int.tryParse(id ?? '') ?? 0;

/// Id string, or null when the stored value is empty/absent.
String? _stringId(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

Map<String, Object?> _petToMap(Pet pet) => {
  'id': pet.id,
  'name': pet.name,
  'species': pet.species,
  'breed': pet.breed,
  'birthDate': pet.birthDate?.toIso8601String(),
  'photoPath': pet.photoPath,
};

Pet _petFromMap(Map<String, Object?> row) => Pet(
  id: _stringId(row['id']),
  name: row['name'] as String,
  species: row['species'] as String,
  breed: (row['breed'] as String?)?.isEmpty == true
      ? null
      : row['breed'] as String?,
  birthDate: DateTime.tryParse(row['birthDate'] as String? ?? ''),
  photoPath: (row['photoPath'] as String?)?.isEmpty == true
      ? null
      : row['photoPath'] as String?,
);

Map<String, Object?> _feedingEntryToMap(FeedingEntry entry) => {
  'id': entry.id,
  'pet_id': entry.petId,
  'name': entry.name,
  'scheduled_time': entry.time,
  'frequency': entry.frequency,
  'scheduled_date': entry.scheduledDate?.toIso8601String(),
  'days_of_week': entry.daysOfWeek.join(','),
  'portion_size': entry.portionSize,
  'remind_me': entry.remindMe ? 1 : 0,
  'last_fed_at': entry.lastFedAt?.toIso8601String(),
  'done_today': entry.doneToday ? 1 : 0,
  // Written only when set: the deployed Firestore rules whitelist document
  // keys, so absent-when-unused keeps every other schedule writable even
  // before rules that know these fields are deployed.
  if (entry.secondTime != null) 'second_time': entry.secondTime,
  if (entry.lastSecondFedAt != null)
    'last_second_fed_at': entry.lastSecondFedAt!.toIso8601String(),
};

FeedingEntry _feedingEntryFromMap(Map<String, Object?> row) => FeedingEntry(
  id: _stringId(row['id']),
  petId: row['pet_id']?.toString() ?? '',
  name: row['name']?.toString() ?? '',
  time: row['scheduled_time']?.toString() ?? '08:00',
  frequency: row['frequency']?.toString() ?? 'Daily',
  scheduledDate: DateTime.tryParse(row['scheduled_date']?.toString() ?? ''),
  daysOfWeek: (row['days_of_week']?.toString() ?? '')
      .split(',')
      .where((value) => value.isNotEmpty)
      .map(int.parse)
      .toList(),
  portionSize: (row['portion_size']?.toString().isEmpty ?? true)
      ? null
      : row['portion_size'].toString(),
  remindMe:
      row['remind_me']?.toString() == '1' ||
      row['remind_me']?.toString().toLowerCase() == 'true',
  lastFedAt: DateTime.tryParse(row['last_fed_at']?.toString() ?? ''),
  secondTime: (row['second_time']?.toString().isEmpty ?? true)
      ? null
      : row['second_time'].toString(),
  lastSecondFedAt: DateTime.tryParse(
    row['last_second_fed_at']?.toString() ?? '',
  ),
);

Map<String, Object?> _decodeMap(String value) => Map<String, Object?>.from(
  Uri.splitQueryString(value).map((key, value) => MapEntry(key, value)),
);

/// Decodes stored maps, skipping any whose stored form is damaged.
///
/// This data lives in browser storage, where an interrupted write can leave a
/// truncated value, and `Uri.splitQueryString` throws on the result. One
/// unreadable row must not take the healthy rows with it, so the bad row is
/// dropped and reported rather than allowed to break the whole load.
Iterable<Map<String, Object?>> _decodeMaps(List<String> values) sync* {
  for (final value in values) {
    try {
      yield _decodeMap(value);
    } on Object {
      logAppDiagnostic('Skipped a stored record that could not be read.');
    }
  }
}

/// Decodes and builds stored records, skipping any row that cannot produce a
/// valid record.
///
/// Guards both halves: a value can decode cleanly and still be unusable, for
/// example a row written before a field existed or truncated mid-write. Either
/// way the healthy rows must still load.
Iterable<T> _decodeRecords<T>(
  List<String> values,
  T Function(Map<String, Object?> map) fromMap,
) sync* {
  for (final value in values) {
    try {
      yield fromMap(_decodeMap(value));
    } on Object {
      logAppDiagnostic('Skipped a stored record that could not be read.');
    }
  }
}
