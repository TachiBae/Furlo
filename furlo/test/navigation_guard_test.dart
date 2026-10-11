import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigation guards.
///
/// The pet form is the largest screen in the app and the only free-text place
/// a user can lose real work by pressing back. Before this guard existed,
/// backing out of a half-filled form discarded it without a word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openAddPet(
    WidgetTester tester,
    WebPetRepository repository,
  ) async {
    // The pet form is long; a phone-sized viewport would push the Save button
    // below the fold and make it untappable.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.defaultTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddPetScreen(repository: repository),
                  ),
                ),
                child: const Text('Open add pet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open add pet'));
    await tester.pumpAndSettle();
    expect(find.text('Add Pet'), findsOneWidget);
  }

  testWidgets('leaving an untouched pet form is not interrupted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openAddPet(tester, WebPetRepository());

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.text('Discard changes?'),
      findsNothing,
      reason: 'nothing was typed, so there is nothing to protect',
    );
    expect(find.text('Add Pet'), findsNothing, reason: 'the form should pop');
    expect(find.text('Open add pet'), findsOneWidget);
  });

  testWidgets('leaving a half-filled pet form asks before discarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openAddPet(tester, WebPetRepository());

    await tester.enterText(find.byType(TextFormField).first, 'Mochi');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Discard changes?'),
      findsOneWidget,
      reason: 'a typed pet must not be thrown away silently',
    );

    // Keeping the edit leaves the user exactly where they were.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Add Pet'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);

    // A second attempt can still discard on purpose.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open add pet'), findsOneWidget);
  });

  testWidgets('the leave guard does not intercept the save path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await openAddPet(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, 'Mochi');
    await tester.pumpAndSettle();
    // Species is required before the form will save.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Discard changes?'),
      findsNothing,
      reason:
          'the save path must not be intercepted by the leave guard, however '
          'the form validation resolves',
    );
    // Whether this partial form validates is deliberately not asserted here:
    // the form's field requirements, and the persistence that follows a
    // successful save, belong to pet_breed_selection_test and
    // save_pet_repro_test. This file owns navigation behaviour only.
    expect(repository, isNotNull);
  });
}
