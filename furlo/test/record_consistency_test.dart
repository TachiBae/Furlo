import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/widgets/record_components.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cohesion contracts for the record screens.
///
/// These pin the *shared* components rather than any one screen's markup, so
/// a screen that quietly grows its own card, empty state, or unstyled chip
/// fails here instead of looking subtly different in the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WebPetRepository> pumpFeeding(
    WidgetTester tester, {
    required List<FeedingEntry> schedules,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pet = (await repository.getPets()).single;
    for (final schedule in schedules) {
      await repository.addFeedingSchedule(
        FeedingEntry(
          petId: pet.id!,
          name: schedule.name,
          time: schedule.time,
          frequency: schedule.frequency,
          daysOfWeek: schedule.daysOfWeek,
        ),
      );
    }
    final state = FurloState(repository);
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.defaultTheme,
          home: FeedingScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('an empty record list renders the shared empty state', (
    tester,
  ) async {
    await pumpFeeding(tester, schedules: const []);

    expect(
      find.byType(RecordEmptyState),
      findsOneWidget,
      reason: 'feeding must use the shared empty state, not a local copy',
    );
    expect(find.text('No feeding schedules yet'), findsOneWidget);
    final emptyState = tester.widget<RecordEmptyState>(
      find.byType(RecordEmptyState),
    );
    expect(
      emptyState.actionLabel,
      'Add feeding schedule',
      reason: 'an empty record list must offer its primary action',
    );
    expect(emptyState.onAction, isNotNull);
  });

  testWidgets('a populated record list renders the shared card', (
    tester,
  ) async {
    await pumpFeeding(
      tester,
      schedules: [FeedingEntry(petId: '', name: 'Breakfast', time: '08:00')],
    );

    expect(find.text('Breakfast'), findsOneWidget);
    expect(
      find.byType(RecordCard),
      findsOneWidget,
      reason: 'feeding must use the shared record card, not a local copy',
    );
    expect(find.byType(RecordEmptyState), findsNothing);
  });

  testWidgets('the feeding day chips follow the app palette', (tester) async {
    await pumpFeeding(tester, schedules: const []);

    await tester.tap(find.text('Add feeding schedule'));
    await tester.pumpAndSettle();

    // Frequency is the last of the form's String dropdowns.
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();

    final palette = AppPalette.defaultTheme;
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(
      chips.length,
      7,
      reason: 'the week picker shows one chip per weekday',
    );
    for (final chip in chips) {
      expect(
        chip.selectedColor,
        palette.primary,
        reason: 'an unthemed chip would fall back to framework colours',
      );
      expect(chip.backgroundColor, palette.surface);
      expect(chip.selected, isFalse);
    }

    await tester.tap(find.byTooltip('Monday'));
    await tester.pumpAndSettle();

    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .firstWhere((chip) => chip.selected);
    expect(selected.labelStyle?.color, palette.textOnPrimary);
    expect(selected.side?.color, palette.primary);
  });

  testWidgets('the pet selector and filter tabs share one chip recipe', (
    tester,
  ) async {
    final mochi = Pet(id: 'pet-1', name: 'Mochi', species: 'Dog');
    final miso = Pet(id: 'pet-2', name: 'Miso', species: 'Cat');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.defaultTheme,
        home: Scaffold(
          body: Column(
            children: [
              PetSelectorTabs(
                pets: [mochi, miso],
                selectedPet: mochi,
                onSelected: _ignorePet,
              ),
              RecordFilterTabs(
                options: const [
                  RecordFilterOption('all', 'All'),
                  RecordFilterOption('due', 'Due'),
                ],
                selectedValue: 'all',
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppChoiceChip), findsNWidgets(4));
    final palette = AppPalette.defaultTheme;
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.selectedColor, palette.primary);
      expect(chip.backgroundColor, palette.surface);
    }
  });
}

void _ignorePet(Pet pet) {}
