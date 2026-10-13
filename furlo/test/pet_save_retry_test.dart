import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first save stores the pet and then fails, like a cloud write that
/// succeeded before a later step (the local photo cache) threw.
class _HalfFailingRepository extends WebPetRepository {
  var failNext = true;

  @override
  Future<void> addPet(Pet pet) async {
    await super.addPet(pet);
    if (failNext) {
      failNext = false;
      throw StateError('photo cache full');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('retrying a half-finished save never duplicates the pet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _HalfFailingRepository();
    final state = FurloState(repository);
    await state.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: AddPetScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Pip');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your pet. Please try again.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final pets = await repository.getPets();
    expect(pets, hasLength(1));
    expect(pets.single.name, 'Pip');
  });

  test('re-adding a known pet id replaces it', () async {
    final repository = WebPetRepository();
    await repository.addPet(Pet(id: 'abc', name: 'Pip', species: 'Dog'));
    await repository.addPet(Pet(id: 'abc', name: 'Pippa', species: 'Dog'));
    expect((await repository.getPets()).single.name, 'Pippa');
  });
}
