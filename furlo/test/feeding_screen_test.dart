import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'feeding schedules can be added, completed, edited, and deleted',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final repository = WebPetRepository();
      await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(name: 'Miso', species: 'Cat'));
      final pets = await repository.getPets();
      final mochi = pets.firstWhere((pet) => pet.name == 'Mochi');
      final miso = pets.firstWhere((pet) => pet.name == 'Miso');
      final state = FurloState(repository);
      await state.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: FeedingScreen(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No feeding schedules yet'), findsOneWidget);
      await tester.tap(find.text('Add Feeding Schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Breakfast');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Monday'));
      await tester.enterText(find.byType(TextFormField).last, '1 cup');
      await tester.tap(find.text('Remind me'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Breakfast'), findsOneWidget);
      final savedSchedule = (await repository.getFeedingSchedules(
        mochi.id!,
      )).single;
      expect(savedSchedule.frequency, 'Weekly');
      expect(savedSchedule.daysOfWeek, [1]);
      expect(savedSchedule.portionSize, '1 cup');
      expect(savedSchedule.remindMe, isTrue);

      await tester.tap(find.text('Mark fed'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(
        (await repository.getFeedingSchedules(mochi.id!)).single.doneToday,
        isTrue,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Morning meal');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Morning meal'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      final petPicker = find.byType(DropdownButtonFormField<int>);
      await tester.tap(petPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Miso').last);
      await tester.pumpAndSettle();
      expect(find.text('No feeding schedules yet'), findsOneWidget);

      await tester.tap(petPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mochi').last);
      await tester.pumpAndSettle();
      expect(find.text('Morning meal'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('No feeding schedules yet'), findsOneWidget);
      expect(await repository.getFeedingSchedules(mochi.id!), isEmpty);
      expect(await repository.getFeedingSchedules(miso.id!), isEmpty);
    },
  );

  testWidgets('feeding schedules can be set to not repeat on one date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    final mochi = pets.single;
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: FeedingScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Feeding Schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Medication meal');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Does not repeat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await repository.getFeedingSchedules(mochi.id!)).single;
    expect(saved.frequency, 'Does not repeat');
    final selectedDate = saved.scheduledDate!;
    expect(saved.isScheduledOn(selectedDate), isTrue);
    expect(
      saved.isScheduledOn(selectedDate.add(const Duration(days: 1))),
      isFalse,
    );
    expect(find.textContaining('Does not repeat'), findsOneWidget);
  });
}
