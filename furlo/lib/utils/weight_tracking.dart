import '../models/weight_log.dart';
import 'formatting.dart';

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

/// Signed change in kg: `+0.4 kg`, `-1.25 kg`, `0.0 kg`.
String formatWeightChange(double change) {
  final twoPlaces = change.toStringAsFixed(2);
  final amount = twoPlaces.endsWith('00')
      ? change.toStringAsFixed(1)
      : twoPlaces.endsWith('0')
      ? twoPlaces.substring(0, twoPlaces.length - 1)
      : twoPlaces;
  return '${change > 0 ? '+' : ''}$amount $weightUnit';
}

/// How the weight moved recently.
///
/// [change] is the latest weight minus a baseline: the newest entry at least
/// 30 days older than the latest one, so the window covers about a month.
/// When every entry is newer than that, the baseline is the oldest entry and
/// [fullMonth] is false (the change is "since" that date).
typedef WeightTrend = ({double change, DateTime since, bool fullMonth});

const _trendWindow = Duration(days: 30);

WeightTrend? weightTrend(List<WeightLog> logs) {
  final dated = chronologicalWeightLogs(logs);
  if (dated.length < 2) return null;
  final latest = dated.last;
  final cutoff = latest.date!.subtract(_trendWindow);
  final older = dated.where((log) => !log.date!.isAfter(cutoff)).toList();
  final baseline = older.isNotEmpty ? older.last : dated.first;
  return (
    change: latest.weight - baseline.weight,
    since: baseline.date!,
    fullMonth: older.isNotEmpty,
  );
}

/// One plain sentence for [trend]: "+0.4 kg in the last month" or
/// "-1.2 kg since Aug 3, 2026".
String weightTrendText(WeightTrend trend) {
  final period = trend.fullMonth
      ? 'in the last month'
      : 'since ${shortDateWithYear(trend.since)}';
  if (trend.change.abs() < 0.005) return 'No change $period';
  return '${formatWeightChange(trend.change)} $period';
}
