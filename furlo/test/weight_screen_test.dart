import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/weight/weight_tracking_screen.dart';
import 'package:furlo/widgets/record_components.dart';

void main() {
  Future<(WebPetRepository, Pet)> createRepository(int count) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    final pet = Pet(id: '1', name: 'Mochi', species: 'Dog');
    await repository.addPet(pet);
    for (var index = 0; index < count; index++) {
      await repository.addWeightLog(
        WeightLog(
          petId: '1',
          date: DateTime(2026, 1, 1).add(Duration(days: index)),
          weight: 8 + index / 10,
        ),
      );
    }
    return (repository, pet);
  }

  testWidgets('empty state omits the trend chart', (tester) async {
    final (repository, pet) = await createRepository(0);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackingScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(RecordEmptyState), findsOneWidget);
  });

  testWidgets('single entry displays a point chart', (tester) async {
    final (repository, pet) = await createRepository(1);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackingScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('30 entries render the chart and history list', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (repository, pet) = await createRepository(30);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackingScreen(repository: repository, pets: [pet]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(ListView).last, findsOneWidget);
    expect(tester.takeException(), isNull);
    final tinyTexts = tester.widgetList<Text>(find.byType(Text)).where((text) {
      final size = text.style?.fontSize;
      return size != null && size < 11;
    });
    expect(
      tinyTexts,
      isEmpty,
      reason: 'chart and screen text stays at 11px or larger',
    );
  });
}
