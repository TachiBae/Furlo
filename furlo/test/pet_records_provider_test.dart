import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/providers/health_records_provider.dart';
import 'package:furlo/providers/vaccinations_provider.dart';
import 'package:furlo/providers/weight_tracking_provider.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/widgets/record_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every record load waits until the test releases it.
class _PendingRepository extends WebPetRepository {
  final vaccinationLoads = <String, Completer<List<Vaccination>>>{};

  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) =>
      (vaccinationLoads[petId] = Completer<List<Vaccination>>()).future;

  @override
  Future<List<Never>> getHealthRecordsForPet(String petId) =>
      Completer<List<Never>>().future;

  @override
  Future<List<Never>> getWeightLogsForPet(String petId) =>
      Completer<List<Never>>().future;
}

final _mochi = Pet(id: '1', name: 'Mochi', species: 'Cat');
final _rex = Pet(id: '2', name: 'Rex', species: 'Dog');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a load that finishes after dispose never notifies or throws', () async {
    final repository = _PendingRepository();
    final provider = VaccinationsProvider(
      repository: repository,
      pets: [_mochi],
    );
    var notified = 0;
    provider.addListener(() => notified++);
    provider.dispose();

    repository.vaccinationLoads['1']!.complete([
      Vaccination(petId: '1', vaccineName: 'Rabies'),
    ]);
    await pumpEventQueue();

    expect(notified, 0);
  });

  test('every record provider tolerates dispose before its load', () async {
    final repository = _PendingRepository();
    HealthRecordsProvider(repository: repository, pets: [_mochi]).dispose();
    WeightTrackingProvider(repository: repository, pets: [_mochi]).dispose();
    await pumpEventQueue();
  });

  test('a stale load never replaces the newly selected pet', () async {
    final repository = _PendingRepository();
    final provider = VaccinationsProvider(
      repository: repository,
      pets: [_mochi, _rex],
    );
    unawaited(provider.selectPet(_rex));

    repository.vaccinationLoads['2']!.complete([
      Vaccination(petId: '2', vaccineName: 'Distemper'),
    ]);
    await pumpEventQueue();
    repository.vaccinationLoads['1']!.complete([
      Vaccination(petId: '1', vaccineName: 'Rabies'),
    ]);
    await pumpEventQueue();

    expect(provider.selectedPet, _rex);
    expect(provider.vaccinations.single.vaccineName, 'Distemper');
    expect(provider.loading, isFalse);
  });

  testWidgets('leaving Vaccinations before it loads throws nothing', (
    tester,
  ) async {
    final repository = _PendingRepository();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.forChoice(AppThemeChoice.defaultTheme),
        home: const Scaffold(),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              VaccinationScreen(repository: repository, pets: [_mochi]),
        ),
      ),
    );
    // A spinner never settles, so pump through the route transitions.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Loading shows placeholder cards, labelled for screen readers.
    expect(find.byType(RecordListSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository.vaccinationLoads['1']!.complete([]);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
