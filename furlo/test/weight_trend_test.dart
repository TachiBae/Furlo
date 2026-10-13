import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/weight_tracking.dart';
import 'package:shared_preferences/shared_preferences.dart';

WeightLog _log(int month, int day, double kg) =>
    WeightLog(petId: '1', date: DateTime(2026, month, day), weight: kg);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compares with the newest entry a month or more back', () {
    final trend = weightTrend([
      _log(8, 1, 10.0),
      _log(9, 1, 10.5), // newest entry 30+ days before Oct 10
      _log(9, 20, 10.7),
      _log(10, 10, 10.9),
    ])!;
    expect(trend.change, closeTo(0.4, 1e-9));
    expect(trend.fullMonth, isTrue);
    expect(weightTrendText(trend), '+0.4 kg in the last month');
  });

  test('with less than a month of history it reads "since"', () {
    final trend = weightTrend([_log(10, 1, 4.6), _log(10, 12, 4.35)])!;
    expect(trend.fullMonth, isFalse);
    expect(weightTrendText(trend), '-0.25 kg since Oct 1, 2026');
  });

  test('no change and too few entries', () {
    expect(
      weightTrendText(weightTrend([_log(8, 1, 5), _log(10, 1, 5)])!),
      'No change in the last month',
    );
    expect(weightTrend([_log(10, 1, 5)]), isNull);
  });

  testWidgets('the weight screen shows the trend line', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    await repository.addWeightLog(_log(8, 1, 10.0));
    await repository.addWeightLog(_log(10, 10, 10.4));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: WeightTrackingScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+0.4 kg in the last month'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
  });
}
