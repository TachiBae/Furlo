import '../models/weight_log.dart';

const double maxWeightKg = 1000;

String? validateWeight(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Weight is required';
  final weight = double.tryParse(input);
  if (weight == null) return 'Enter a valid weight';
  if (weight <= 0) return 'Weight must be greater than 0';
  if (!RegExp(r'^(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$').hasMatch(input)) {
    return 'Enter a number with up to 2 decimal places';
  }
  if (weight >= maxWeightKg) {
    return 'Weight must be below $maxWeightKg $weightUnit';
  }
  return null;
}

/// Returns latest weight minus the previous dated entry, or null if absent.
double? weightChangeSincePrevious(List<WeightLog> logs) {
  final dated = logs.where((log) => log.date != null).toList()
    ..sort((a, b) => b.date!.compareTo(a.date!));
  if (dated.length < 2) return null;
  return dated[0].weight - dated[1].weight;
}

/// Chart order is chronological from oldest to newest.
List<WeightLog> chronologicalWeightLogs(List<WeightLog> logs) {
  final dated = logs.where((log) => log.date != null).toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));
  return dated;
}
